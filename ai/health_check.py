#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path


RE_INCLUDE = re.compile(r'^\s*#Include\s+"?([^"\r\n]+)"?', re.MULTILINE)
RE_INI_SECTION = re.compile(r"^\s*\[([^\]]+)\]\s*$", re.MULTILINE)
RE_CLASS_HEADER = re.compile(
    r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+extends\s+([A-Za-z_][A-Za-z0-9_]*))?\s*\{",
    re.MULTILINE,
)
RE_SERVICE_CALL = re.compile(r"services\.([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)")
RE_ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:=", re.MULTILINE)
RE_GROUP_ADD = re.compile(r'GroupAdd\("([^"]+)"')
RE_APP_TARGET = re.compile(r'appActivationTargets\.Push\(\["([^"]+)"')
RESERVED_METHOD_NAMES = {
    "if",
    "else",
    "for",
    "while",
    "switch",
    "case",
    "catch",
    "try",
    "return",
    "loop",
}

LEGACY_ENV_PREFIX = "NOR" "MAN_"
LEGACY_WORKSPACE_NAME = "nor" "man_src"
RETIRED_DOCS_SEGMENT = "do" "cs/"

FORBIDDEN_REFERENCE_PATTERNS = (
    ("legacy_env_symbol", re.compile(r"\b" + re.escape(LEGACY_ENV_PREFIX) + r"[A-Z0-9_]+\b")),
    ("legacy_workspace_name", re.compile(re.escape(LEGACY_WORKSPACE_NAME), re.IGNORECASE)),
    ("retired_docs_reference", re.compile(r"(^|[\s`\"'=:(])" + re.escape(RETIRED_DOCS_SEGMENT), re.IGNORECASE | re.MULTILINE)),
)

FORBIDDEN_SCAN_EXCLUDED_PREFIXES = (
    ".git/",
    ".axet-code/",
    "ai/__pycache__/",
)

FORBIDDEN_SCAN_EXACT_PATHS = {
    "ai/health-check.json",
    "ai/health-check.summary.json",
    "ai/health_check.py",
    "platforms/windows/data/local-secrets.ini",
    "platforms/windows/data/local-paths.ini",
    "platforms/windows/data/local-startup.ini",
    "platforms/windows/data/memory-vars.ini",
    "platforms/windows/data/rom.ini",
    "storage.db",
    "platforms/windows/storage.db",
}

# Unregistered classes in library/automation/ that are known dead code.
KNOWN_DEAD_CLASSES = {"PasteService"}

# Constants that are declared but have no known consumers.
# hotkeyTrackerJsonFile: used indirectly by HotkeyTrackerService via the global assigned in constants-core.ahk.
KNOWN_DEAD_CONSTANTS: tuple[str, ...] = ()
CATALOG_REVIEW_FILE = "ai/catalog-review.json"
CATALOG_REVIEW_STATUS_VALUES = {"pending_human_review", "verified"}
GOVERNANCE_FILE = "ai/governance.json"


def to_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.relative_to(repo_root).as_posix()
    except ValueError:
        return path.as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def find_block(text: str, anchor: str) -> str:
    start = text.find(anchor)
    if start == -1:
        return ""
    brace_start = text.find("{", start)
    if brace_start == -1:
        return ""
    depth = 0
    for idx in range(brace_start, len(text)):
        char = text[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start + 1 : idx]
    return ""


def parse_registry(bootstrap_text: str) -> dict[str, str]:
    block = find_block(bootstrap_text, "keyflowServiceRegistry()")
    return dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\(\)", block))


def parse_hotstring_profiles(bootstrap_text: str) -> list[dict[str, str]]:
    block = find_block(bootstrap_text, "keyflowHotstringProfiles()")
    entries = []
    for label, group, mode in re.findall(
        r'\{label:\s*"([^"]+)",\s*group:\s*"([^"]*)",\s*mode:\s*"([^"]+)"\}',
        block,
    ):
        entries.append({"label": label, "group": group, "mode": mode})
    return entries


def parse_ini_sections(text: str) -> list[str]:
    return RE_INI_SECTION.findall(text)


def resolve_include(include_value: str, current_file: Path) -> Path:
    return (current_file.parent / include_value.replace("\\", "/")).resolve()


def build_include_graph(
    entry_file: Path, repo_root: Path
) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    visited: set[Path] = set()
    include_edges: list[dict[str, object]] = []
    missing: list[dict[str, str]] = []

    def walk(file_path: Path) -> None:
        if file_path in visited:
            return
        visited.add(file_path)
        text = read_text(file_path)
        includes = []
        for include_value in RE_INCLUDE.findall(text):
            target = resolve_include(include_value, file_path)
            exists = target.exists()
            includes.append(
                {
                    "include": include_value.replace("\\", "/"),
                    "target": to_repo_path(target, repo_root),
                    "exists": exists,
                }
            )
            if exists:
                walk(target)
            else:
                missing.append(
                    {
                        "from": to_repo_path(file_path, repo_root),
                        "include": include_value.replace("\\", "/"),
                        "target": to_repo_path(target, repo_root),
                    }
                )
        include_edges.append({"file": to_repo_path(file_path, repo_root), "includes": includes})

    walk(entry_file.resolve())
    include_edges.sort(key=lambda item: item["file"])
    missing.sort(key=lambda item: (item["from"], item["include"]))
    return include_edges, missing


def parse_class_methods(text: str) -> dict[str, dict[str, object]]:
    results: dict[str, dict[str, object]] = {}
    lines = text.splitlines()
    current_class = None
    class_depth = 0
    for line in lines:
        class_match = re.match(
            r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+extends\s+([A-Za-z_][A-Za-z0-9_]*))?\s*\{",
            line,
        )
        if class_match and current_class is None:
            current_class = class_match.group(1)
            results[current_class] = {"methods": [], "parent": class_match.group(2) or ""}
            class_depth = line.count("{") - line.count("}")
            continue
        if current_class is not None:
            method_match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*\{\s*$", line)
            if method_match:
                method_name = method_match.group(1)
                if method_name not in RESERVED_METHOD_NAMES and method_name not in results[current_class]["methods"]:
                    results[current_class]["methods"].append(method_name)
            class_depth += line.count("{") - line.count("}")
            if class_depth <= 0:
                current_class = None
                class_depth = 0
    return results


def parse_file_index(repo_root: Path) -> tuple[dict[str, dict[str, object]], Counter[str]]:
    file_index: dict[str, dict[str, object]] = {}
    token_counter: Counter[str] = Counter()
    for path in sorted(repo_root.rglob("*.ahk")):
        text = read_text(path)
        token_counter.update(token.lower() for token in re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", text))
        file_index[to_repo_path(path, repo_root)] = {
            "path": path,
            "text": text,
            "classes": parse_class_methods(text),
            "service_calls": RE_SERVICE_CALL.findall(text),
        }
    return file_index, token_counter


def build_class_lookup(file_index: dict[str, dict[str, object]]) -> dict[str, dict[str, object]]:
    lookup: dict[str, dict[str, object]] = {}
    for repo_path, meta in file_index.items():
        for class_name, class_meta in meta["classes"].items():
            lookup[class_name] = {
                "file": repo_path,
                "methods": class_meta["methods"],
                "parent": class_meta["parent"],
            }
    return lookup


def resolve_declared_methods(class_name: str, class_lookup: dict[str, dict[str, object]]) -> list[str]:
    resolved: list[str] = []
    visited: set[str] = set()
    current = class_name
    while current and current not in visited:
        visited.add(current)
        class_meta = class_lookup.get(current)
        if not class_meta:
            break
        for method_name in class_meta["methods"]:
            if method_name not in resolved:
                resolved.append(method_name)
        current = class_meta.get("parent", "")
    return resolved


def validate_profiles(
    profiles: list[dict[str, str]], data_dir: Path, repo_root: Path
) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    results = []
    issues = []
    for profile in profiles:
        json_path = data_dir / f"{profile['label']}.json"
        entry: dict[str, object] = {
            **profile,
            "file": to_repo_path(json_path, repo_root),
            "exists": json_path.exists(),
        }
        if json_path.exists():
            try:
                payload = json.loads(json_path.read_text(encoding="utf-8-sig"))
                has_items = isinstance(payload, dict) and isinstance(payload.get("items"), list)
                entry["json_valid"] = True
                entry["has_items_array"] = has_items
                entry["item_count"] = len(payload.get("items", [])) if has_items else None
                if not has_items:
                    issues.append(
                        {
                            "type": "profile_catalog_shape",
                            "profile": profile["label"],
                            "file": to_repo_path(json_path, repo_root),
                            "message": "Catalog is valid JSON but does not expose items[].",
                        }
                    )
            except json.JSONDecodeError as exc:
                entry["json_valid"] = False
                entry["error"] = str(exc)
                issues.append(
                    {
                        "type": "profile_catalog_invalid_json",
                        "profile": profile["label"],
                        "file": to_repo_path(json_path, repo_root),
                        "message": str(exc),
                    }
                )
        else:
            issues.append(
                {
                    "type": "profile_catalog_missing",
                    "profile": profile["label"],
                    "file": to_repo_path(json_path, repo_root),
                    "message": "Expected hotstring catalog file is missing.",
                }
            )
        results.append(entry)
    return results, issues


def validate_catalog_review(
    repo_root: Path,
    profiles: list[dict[str, str]],
) -> tuple[dict[str, object], list[dict[str, str]]]:
    review_path = repo_root / CATALOG_REVIEW_FILE
    expected_catalogs = {
        profile["label"]: f"platforms/windows/data/{profile['label']}.json"
        for profile in profiles
    }
    result: dict[str, object] = {
        "file": CATALOG_REVIEW_FILE,
        "exists": review_path.exists(),
        "catalogs": [],
    }
    issues: list[dict[str, str]] = []

    if not review_path.exists():
        issues.append(
            {
                "type": "catalog_review_missing",
                "file": CATALOG_REVIEW_FILE,
                "message": "Catalog review contract is missing.",
            }
        )
        return result, issues

    try:
        payload = json.loads(review_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        issues.append(
            {
                "type": "catalog_review_invalid_json",
                "file": CATALOG_REVIEW_FILE,
                "message": str(exc),
            }
        )
        return result, issues

    catalogs = payload.get("catalogs")
    if not isinstance(catalogs, list):
        issues.append(
            {
                "type": "catalog_review_catalogs_missing",
                "file": CATALOG_REVIEW_FILE,
                "message": "catalog-review.json must expose catalogs[] as a list.",
            }
        )
        return result, issues

    seen_ids: set[str] = set()
    pending_count = 0
    verified_count = 0

    for entry in catalogs:
        if not isinstance(entry, dict):
            issues.append(
                {
                    "type": "catalog_review_entry_invalid",
                    "file": CATALOG_REVIEW_FILE,
                    "message": "Each catalogs[] item must be an object.",
                }
            )
            continue

        catalog_id = entry.get("id", "")
        catalog_file = entry.get("file", "")
        status = entry.get("status", "")
        verified_on = entry.get("last_human_verification", "")
        result["catalogs"].append(entry)

        if not catalog_id or not isinstance(catalog_id, str):
            issues.append(
                {
                    "type": "catalog_review_id_missing",
                    "file": CATALOG_REVIEW_FILE,
                    "message": "Each catalog review entry must define a string id.",
                }
            )
            continue

        if catalog_id in seen_ids:
            issues.append(
                {
                    "type": "catalog_review_duplicate_id",
                    "file": CATALOG_REVIEW_FILE,
                    "message": f"Duplicate catalog review id: {catalog_id}",
                }
            )
        seen_ids.add(catalog_id)

        expected_file = expected_catalogs.get(catalog_id)
        if not expected_file:
            issues.append(
                {
                    "type": "catalog_review_unknown_id",
                    "file": CATALOG_REVIEW_FILE,
                    "message": f"Catalog review entry does not match an active versioned catalog: {catalog_id}",
                }
            )
        elif catalog_file != expected_file:
            issues.append(
                {
                    "type": "catalog_review_file_mismatch",
                    "file": CATALOG_REVIEW_FILE,
                    "message": f"Catalog review entry for {catalog_id} must point to {expected_file}.",
                }
            )

        if status not in CATALOG_REVIEW_STATUS_VALUES:
            issues.append(
                {
                    "type": "catalog_review_status_invalid",
                    "file": CATALOG_REVIEW_FILE,
                    "message": f"Catalog review entry for {catalog_id} uses an unknown status: {status}",
                }
            )
        elif status == "pending_human_review":
            pending_count += 1
        elif status == "verified":
            verified_count += 1

        if status == "verified":
            if not verified_on:
                issues.append(
                    {
                        "type": "catalog_review_verified_date_missing",
                        "file": CATALOG_REVIEW_FILE,
                        "message": f"Verified catalog {catalog_id} must include last_human_verification.",
                    }
                )
            else:
                try:
                    date.fromisoformat(verified_on)
                except ValueError:
                    issues.append(
                        {
                            "type": "catalog_review_verified_date_invalid",
                            "file": CATALOG_REVIEW_FILE,
                            "message": f"Catalog {catalog_id} has an invalid last_human_verification date: {verified_on}",
                        }
                    )
            notes_text = str(entry.get("notes", ""))
            if re.search(r"\bpending\b", notes_text, re.IGNORECASE):
                issues.append(
                    {
                        "type": "catalog_review_note_stale",
                        "file": CATALOG_REVIEW_FILE,
                        "message": f"Verified catalog {catalog_id} still contains stale pending wording in notes.",
                    }
                )

    missing_ids = sorted(set(expected_catalogs) - seen_ids)
    for missing_id in missing_ids:
        issues.append(
            {
                "type": "catalog_review_entry_missing",
                "file": CATALOG_REVIEW_FILE,
                "message": f"Active catalog missing from review contract: {missing_id}",
            }
        )

    result["pending_human_review_count"] = pending_count
    result["verified_count"] = verified_count
    return result, issues


def validate_governance_contract(
    repo_root: Path,
    repo_map: dict[str, object],
) -> tuple[dict[str, object], list[dict[str, str]]]:
    governance_path = repo_root / GOVERNANCE_FILE
    result: dict[str, object] = {
        "file": GOVERNANCE_FILE,
        "exists": governance_path.exists(),
    }
    issues: list[dict[str, str]] = []

    expected_guide_authority = [
        "ai/health-check.summary.json",
        "ai/repo-map.json",
        "AGENTS.md",
        "README.md",
    ]
    expected_required_cycle_outputs = [
        "ai/health-check.summary.json",
        "ai/repo-map.json",
        "AGENTS.md",
    ]
    expected_detailed_plan_path = "ai/current-plan.md"
    expected_human_owned_contracts = [CATALOG_REVIEW_FILE]
    expected_machine_validated_contracts = [
        "ai/repo-map.json",
        CATALOG_REVIEW_FILE,
    ]

    if not governance_path.exists():
        issues.append(
            {
                "type": "governance_missing",
                "file": GOVERNANCE_FILE,
                "message": "Governance contract is missing.",
            }
        )
        return result, issues

    try:
        payload = json.loads(governance_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        issues.append(
            {
                "type": "governance_invalid_json",
                "file": GOVERNANCE_FILE,
                "message": str(exc),
            }
        )
        return result, issues

    result.update(payload)

    if payload.get("guide_authority") != expected_guide_authority:
        issues.append(
            {
                "type": "governance_guide_authority_mismatch",
                "file": GOVERNANCE_FILE,
                "message": "governance.json guide_authority does not match the repo guide contract.",
            }
        )

    if payload.get("required_cycle_outputs") != expected_required_cycle_outputs:
        issues.append(
            {
                "type": "governance_cycle_outputs_mismatch",
                "file": GOVERNANCE_FILE,
                "message": "governance.json required_cycle_outputs do not match the repo workflow contract.",
            }
        )

    if payload.get("detailed_plan_path") != expected_detailed_plan_path:
        issues.append(
            {
                "type": "governance_plan_path_mismatch",
                "file": GOVERNANCE_FILE,
                "message": "governance.json detailed_plan_path must point to ai/current-plan.md.",
            }
        )

    if payload.get("human_owned_contracts") != expected_human_owned_contracts:
        issues.append(
            {
                "type": "governance_human_contracts_mismatch",
                "file": GOVERNANCE_FILE,
                "message": "governance.json human_owned_contracts do not match the current repo contract.",
            }
        )

    if payload.get("machine_validated_contracts") != expected_machine_validated_contracts:
        issues.append(
            {
                "type": "governance_machine_contracts_mismatch",
                "file": GOVERNANCE_FILE,
                "message": "governance.json machine_validated_contracts do not match the current repo contract.",
            }
        )

    for rel_path in expected_guide_authority + expected_human_owned_contracts + [expected_detailed_plan_path]:
        if not (repo_root / rel_path).exists():
            issues.append(
                {
                    "type": "governance_referenced_file_missing",
                    "file": GOVERNANCE_FILE,
                    "message": f"governance.json depends on a missing file: {rel_path}",
                }
            )

    repo_map_read_order = repo_map.get("read-order", []) if isinstance(repo_map, dict) else []
    for required_read_path in ["ai/current-plan.md", "ai/governance.json", "ai/catalog-review.json"]:
        if required_read_path not in repo_map_read_order:
            issues.append(
                {
                    "type": "governance_repo_map_read_order_missing",
                    "file": "ai/repo-map.json",
                    "message": f"repo-map read-order must include {required_read_path}.",
                }
            )

    return result, issues


def validate_repo_map_contracts(
    repo_root: Path,
    repo_map: dict[str, object],
    startup_sections: list[str],
) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    expected_guide_files = {
        "summary": "ai/health-check.summary.json",
        "map": "ai/repo-map.json",
        "rules": "AGENTS.md",
        "architecture": "README.md",
    }
    expected_plan_file = "ai/current-plan.md"

    guide_files = repo_map.get("guide-files")
    if guide_files != expected_guide_files:
        issues.append(
            {
                "type": "repo_map_guide_files_mismatch",
                "file": "ai/repo-map.json",
                "message": "guide-files in repo-map.json do not match the standard multi-agent guide contract.",
            }
        )

    read_order = repo_map.get("read-order", [])
    if not isinstance(read_order, list):
        issues.append(
            {
                "type": "repo_map_read_order_invalid",
                "file": "ai/repo-map.json",
                "message": "read-order must be a list of repo-relative file paths.",
            }
        )
    else:
        for rel_path in read_order:
            if not isinstance(rel_path, str) or not (repo_root / rel_path).exists():
                issues.append(
                    {
                        "type": "repo_map_read_order_missing",
                        "file": "ai/repo-map.json",
                        "message": f"read-order references a missing file: {rel_path}",
                    }
                )

    plan_location = repo_map.get("plan-location", {})
    if not isinstance(plan_location, dict):
        issues.append(
            {
                "type": "repo_map_plan_location_invalid",
                "file": "ai/repo-map.json",
                "message": "plan-location must be an object.",
            }
        )
    else:
        detailed_plan = plan_location.get("detailed", "")
        if detailed_plan != expected_plan_file:
            issues.append(
                {
                    "type": "repo_map_plan_location_mismatch",
                    "file": "ai/repo-map.json",
                    "message": "repo-map detailed plan location must point to ai/current-plan.md.",
                }
            )
        elif not (repo_root / detailed_plan).exists():
            issues.append(
                {
                    "type": "repo_map_plan_missing",
                    "file": "ai/repo-map.json",
                    "message": "repo-map points to ai/current-plan.md but the file does not exist.",
                }
            )

    repo_map_startup_sections = repo_map.get("startup-config-sections", [])
    if repo_map_startup_sections != startup_sections:
        issues.append(
            {
                "type": "repo_map_startup_sections_mismatch",
                "file": "ai/repo-map.json",
                "message": "startup-config-sections in repo-map.json do not match local-startup.example.ini.",
            }
        )

    return issues


def validate_guide_contracts(repo_root: Path, repo_map: dict[str, object]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    agents_text = read_text(repo_root / "AGENTS.md")
    readme_text = read_text(repo_root / "README.md")

    if "ai/current-plan.md" not in agents_text:
        issues.append(
            {
                "type": "agents_plan_reference_missing",
                "file": "AGENTS.md",
                "message": "AGENTS.md must mention ai/current-plan.md when that detailed plan contract is supported.",
            }
        )

    if "guide authority" not in agents_text.lower():
        issues.append(
            {
                "type": "agents_guide_authority_missing",
                "file": "AGENTS.md",
                "message": "AGENTS.md must declare guide authority for multi-agent handoff.",
            }
        )

    if "ai operating guide" not in readme_text.lower() and "read first" not in readme_text.lower():
        issues.append(
            {
                "type": "readme_operating_guide_missing",
                "file": "README.md",
                "message": "README.md must expose a short read-first operating guide section.",
            }
        )

    guide_files = repo_map.get("guide-files", {})
    if isinstance(guide_files, dict):
        for rel_path in guide_files.values():
            if isinstance(rel_path, str) and not (repo_root / rel_path).exists():
                issues.append(
                    {
                        "type": "guide_file_missing",
                        "file": "ai/repo-map.json",
                        "message": f"guide-files references a missing file: {rel_path}",
                    }
                )

    return issues


def build_service_contracts(
    registry: dict[str, str],
    class_lookup: dict[str, dict[str, object]],
    file_index: dict[str, dict[str, object]],
) -> tuple[list[dict[str, object]], list[dict[str, str]], list[dict[str, str]], list[dict[str, object]]]:
    service_contracts = []
    registry_issues: list[dict[str, str]] = []
    service_call_issues: list[dict[str, str]] = []
    public_api_candidates: list[dict[str, object]] = []
    service_calls_by_key: defaultdict[str, set[str]] = defaultdict(set)

    for meta in file_index.values():
        for service_key, method_name in meta["service_calls"]:
            service_calls_by_key[service_key].add(method_name)

    for service_key, class_name in registry.items():
        class_meta = class_lookup.get(class_name)
        referenced_methods = sorted(service_calls_by_key.get(service_key, set()))
        declared_methods = resolve_declared_methods(class_name, class_lookup) if class_meta else []
        service_contracts.append(
            {
                "service": service_key,
                "class": class_name,
                "class_file": class_meta["file"] if class_meta else "",
                "referenced_methods": referenced_methods,
                "declared_methods": declared_methods,
            }
        )
        if not class_meta:
            registry_issues.append(
                {
                    "type": "registry_class_missing",
                    "service": service_key,
                    "class": class_name,
                    "message": "Service registry points to a class that was not found in the repo.",
                }
            )
            continue
        declared = set(declared_methods)
        for method_name in referenced_methods:
            if method_name not in declared:
                service_call_issues.append(
                    {
                        "type": "service_method_missing",
                        "service": service_key,
                        "class": class_name,
                        "method": method_name,
                        "message": "A services.* call points to a method that the registered class does not expose.",
                    }
                )

        public_only_methods = [
            method_name
            for method_name in declared_methods
            if not method_name.startswith("_")
            and method_name not in {"__new"}
            and method_name not in referenced_methods
        ]
        if public_only_methods:
            public_api_candidates.append(
                {
                    "service": service_key,
                    "class": class_name,
                    "methods": public_only_methods,
                    "reason": "Public service methods are exposed but have no services.* callers.",
                }
            )

    for service_key in sorted(service_calls_by_key):
        if service_key not in registry:
            service_call_issues.append(
                {
                    "type": "service_key_missing",
                    "service": service_key,
                    "class": "",
                    "method": "",
                    "message": "A services.* call references a service key not in keyflowServiceRegistry().",
                }
            )

    service_contracts.sort(key=lambda item: item["service"])
    return service_contracts, registry_issues, service_call_issues, public_api_candidates


def collect_public_service_calls(file_index: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    public_calls = []
    for repo_path, meta in sorted(file_index.items()):
        if not meta["service_calls"]:
            continue
        public_calls.append(
            {
                "file": repo_path,
                "calls": sorted({f"{service}.{method}" for service, method in meta["service_calls"]}),
            }
        )
    return public_calls


def detect_dead_candidates(
    file_index: dict[str, dict[str, object]],
    registry: dict[str, str],
    token_counter: Counter[str],
) -> dict[str, list[dict[str, object]]]:
    registered_classes = {name.lower() for name in registry.values()}
    class_candidates = []
    for repo_path, meta in file_index.items():
        if "/library/automation/" not in repo_path:
            continue
        for class_name in meta["classes"]:
            if class_name.lower() in registered_classes:
                continue
            if token_counter[class_name.lower()] <= 1 or class_name in KNOWN_DEAD_CLASSES:
                class_candidates.append(
                    {
                        "file": repo_path,
                        "class": class_name,
                        "reason": "Class is defined but not registered in keyflowServiceRegistry() and has no external callers.",
                    }
                )

    constant_candidates = []
    for constant_name in KNOWN_DEAD_CONSTANTS:
        if token_counter[constant_name.lower()] <= 1:
            constant_candidates.append(
                {
                    "constant": constant_name,
                    "reason": "Constant is declared but not referenced by any service or hotkey.",
                }
            )

    return {
        "dead_class_candidates": sorted(class_candidates, key=lambda item: item["file"]),
        "dead_constant_candidates": constant_candidates,
    }


def scan_assignment_candidates(repo_root: Path, token_counter: Counter[str]) -> list[dict[str, str]]:
    candidates = []
    for rel_path in (
        "platforms/windows/library/config/constants-core.ahk",
        "platforms/windows/library/config/constants-secrets.ahk",
    ):
        path = repo_root / rel_path
        for name in RE_ASSIGN.findall(read_text(path)):
            if token_counter[name.lower()] <= 1:
                candidates.append(
                    {
                        "file": rel_path,
                        "symbol": name,
                        "reason": "Assignment appears to be declared but not referenced elsewhere.",
                    }
                )
    return candidates


def scan_group_candidates(repo_root: Path, token_counter: Counter[str]) -> list[dict[str, str]]:
    rules_path = repo_root / "platforms/windows/library/config/constants-core.ahk"
    text = read_text(rules_path)
    candidates = []
    for group_name in sorted(set(RE_GROUP_ADD.findall(text))):
        if token_counter[group_name.lower()] <= 1:
            candidates.append(
                {
                    "symbol": group_name,
                    "reason": "Window group is defined but not referenced elsewhere.",
                }
            )
    for target_name in sorted(set(RE_APP_TARGET.findall(text))):
        if token_counter[target_name.lower()] <= 1:
            candidates.append(
                {
                    "symbol": target_name,
                    "reason": "Activation target is defined but not referenced elsewhere.",
                }
            )
    return candidates


RE_HOTIF_OPEN = re.compile(r"^\s*#[Hh]ot[Ii]f\b(?!\s*$)", re.MULTILINE)
RE_HOTIF_CLOSE = re.compile(r"^\s*#[Hh]ot[Ii]f\s*$", re.MULTILINE)


def scan_hotkey_counts(hotkeys_dir: Path, repo_root: Path) -> dict[str, int]:
    """Count hotkey definitions per group/file across all hotkey modules."""
    RE_HOTKEY_DEF = re.compile(r"^[^;\s][^:]*::{$", re.MULTILINE)
    counts: dict[str, int] = {}
    for path in sorted(hotkeys_dir.rglob("*.ahk")):
        rel = to_repo_path(path, repo_root)
        text = read_text(path)
        n = len(RE_HOTKEY_DEF.findall(text))
        if n > 0:
            counts[rel] = n
    return counts


def scan_unclosed_hotif(hotkeys_dir: Path, repo_root: Path) -> list[dict[str, object]]:
    """Detect #hotif scope leaks: files that open a conditional #hotif but are
    themselves #Include-d by an aggregator without a trailing bare #hotif.
    In AHK v2 the scope from the last #hotif in a file carries into any
    subsequent code in the same include chain — so aggregator files (those
    that #Include other hotkey files) MUST end with a bare #hotif.
    Leaf hotkey files are exempt: each one is self-contained.
    """
    RE_INCLUDE_LINE = re.compile(r'^\s*#Include', re.MULTILINE)
    issues = []
    for path in sorted(hotkeys_dir.rglob("*.ahk")):
        text = read_text(path)
        opens = len(RE_HOTIF_OPEN.findall(text))
        if opens == 0:
            continue
        closes = len(RE_HOTIF_CLOSE.findall(text))
        is_aggregator = bool(RE_INCLUDE_LINE.search(text))
        if is_aggregator and opens > closes:
            issues.append({
                "file": to_repo_path(path, repo_root),
                "open_count": opens,
                "close_count": closes,
                "message": f"Aggregator file has #hotif opened {opens}x but closed {closes}x — scope leaks into included files.",
            })
    return issues


def scan_forbidden_references(repo_root: Path) -> list[dict[str, object]]:
    findings = []
    for path in sorted(repo_root.rglob("*")):
        if not path.is_file():
            continue
        rel_path = to_repo_path(path, repo_root)
        if rel_path in FORBIDDEN_SCAN_EXACT_PATHS:
            continue
        if any(rel_path.startswith(prefix) for prefix in FORBIDDEN_SCAN_EXCLUDED_PREFIXES):
            continue
        if path.suffix.lower() not in {".ahk", ".ini", ".ps1", ".json", ".txt"}:
            continue
        text = read_text(path)
        for issue_type, pattern in FORBIDDEN_REFERENCE_PATTERNS:
            for match in pattern.finditer(text):
                findings.append(
                    {
                        "type": issue_type,
                        "file": rel_path,
                        "match": match.group(0),
                        "message": "Retired internal reference detected.",
                    }
                )
    return findings


def compute_ai_readiness(
    issues: list,
    dead_candidates: dict,
    forbidden_references: list,
) -> int:
    """AI-first maintenance readiness score (0–100). 100 = fully clean.
    Deductions: -10 per unresolved issue, -5 per dead class candidate,
    -5 per forbidden reference. Cannot go below 0."""
    score = 100
    score -= len(issues) * 10
    score -= len(dead_candidates.get("dead_class_candidates", [])) * 5
    score -= len(forbidden_references) * 5
    return max(0, score)


def build_summary(
    include_missing: list,
    registry_issues: list,
    service_call_issues: list,
    profile_issues: list,
    guide_contract_issues: list,
    catalog_review_issues: list,
    governance_issues: list,
    dead_candidates: dict,
    profile_results: list,
    registry: dict,
    forbidden_references: list,
    hotkey_counts: dict,
    unclosed_hotif: list,
    catalog_review_result: dict[str, object],
    governance_result: dict[str, object],
    next_frontier: str = "",
) -> dict[str, object]:
    issues = include_missing + registry_issues + service_call_issues + profile_issues + guide_contract_issues + catalog_review_issues + governance_issues + unclosed_hotif + forbidden_references
    profile_counts = {p["label"]: p.get("item_count", 0) for p in profile_results}
    ai_readiness = compute_ai_readiness(issues, dead_candidates, forbidden_references)
    return {
        "ok": len(issues) == 0,
        "issue_count": len(issues),
        "ai_readiness": ai_readiness,
        "services": sorted(registry.keys()),
        "profiles": profile_counts,
        "catalog_review": {
            "file": catalog_review_result.get("file", CATALOG_REVIEW_FILE),
            "exists": catalog_review_result.get("exists", False),
            "pending_human_review_count": catalog_review_result.get("pending_human_review_count", 0),
            "verified_count": catalog_review_result.get("verified_count", 0),
        },
        "governance": {
            "file": governance_result.get("file", GOVERNANCE_FILE),
            "exists": governance_result.get("exists", False),
        },
        "hotkey_counts": hotkey_counts,
        "dead_class_candidates": [c["class"] for c in dead_candidates["dead_class_candidates"]],
        "dead_constant_candidates": [c["constant"] for c in dead_candidates["dead_constant_candidates"]],
        "forbidden_reference_count": len(forbidden_references),
        "ai_operating_guide": ["AGENTS.md", "README.md", "ai/repo-map.json", "ai/health-check.summary.json"],
        "next_frontier": next_frontier,
    }


def run(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    keyflow_entry = repo_root / "platforms/windows/keyflow.ahk"
    bootstrap_file = repo_root / "platforms/windows/library/bootstrap.ahk"
    repo_map_file = repo_root / "ai/repo-map.json"
    hotkeys_dir = repo_root / "platforms/windows/hotkeys"
    data_dir = repo_root / "platforms/windows/data"
    bootstrap_text = read_text(bootstrap_file)
    startup_example_text = read_text(data_dir / "local-startup.example.ini")
    startup_sections = parse_ini_sections(startup_example_text)

    next_frontier = ""
    repo_map: dict[str, object] = {}
    if repo_map_file.exists():
        try:
            repo_map = json.loads(repo_map_file.read_text(encoding="utf-8-sig"))
            next_frontier = repo_map.get("next-frontier", "")
        except (json.JSONDecodeError, KeyError):
            pass

    include_graph, include_missing = build_include_graph(keyflow_entry, repo_root)
    file_index, token_counter = parse_file_index(repo_root)
    class_lookup = build_class_lookup(file_index)
    registry = parse_registry(bootstrap_text)
    profiles = parse_hotstring_profiles(bootstrap_text)
    profile_results, profile_issues = validate_profiles(profiles, data_dir, repo_root)
    catalog_review_result, catalog_review_issues = validate_catalog_review(repo_root, profiles)
    governance_result, governance_issues = validate_governance_contract(repo_root, repo_map)
    service_contracts, registry_issues, service_call_issues, public_api_candidates = build_service_contracts(registry, class_lookup, file_index)
    public_calls = collect_public_service_calls(file_index)
    dead_candidates = detect_dead_candidates(file_index, registry, token_counter)
    unused_assignments = scan_assignment_candidates(repo_root, token_counter)
    unused_groups = scan_group_candidates(repo_root, token_counter)
    forbidden_references = scan_forbidden_references(repo_root)
    repo_map_contract_issues = validate_repo_map_contracts(repo_root, repo_map, startup_sections) if repo_map else []
    guide_contract_issues = validate_guide_contracts(repo_root, repo_map) if repo_map else []
    hotkey_counts = scan_hotkey_counts(hotkeys_dir, repo_root)
    unclosed_hotif = scan_unclosed_hotif(hotkeys_dir, repo_root)

    summary = build_summary(
        include_missing,
        registry_issues,
        service_call_issues,
        profile_issues,
        repo_map_contract_issues + guide_contract_issues,
        catalog_review_issues,
        governance_issues,
        dead_candidates,
        profile_results,
        registry,
        forbidden_references,
        hotkey_counts,
        unclosed_hotif,
        catalog_review_result,
        governance_result,
        next_frontier,
    )

    full = {
        "summary": summary,
        "issues": {
            "include_missing": include_missing,
            "registry": registry_issues,
            "service_calls": service_call_issues,
            "profiles": profile_issues,
            "guide_contracts": repo_map_contract_issues + guide_contract_issues,
            "catalog_review": catalog_review_issues,
            "governance": governance_issues,
            "unclosed_hotif": unclosed_hotif,
            "forbidden_references": forbidden_references,
        },
        "dead_candidates": dead_candidates,
        "audits": {
            "unused_assignments": unused_assignments,
            "unused_groups_or_targets": unused_groups,
            "public_service_methods_without_callers": public_api_candidates,
        },
        "contracts": {
            "include_graph": include_graph,
            "service_registry": service_contracts,
            "hotstring_profiles": profile_results,
            "catalog_review": catalog_review_result,
            "governance": governance_result,
            "public_service_calls": public_calls,
        },
        "repo": {
            "entrypoint": to_repo_path(keyflow_entry, repo_root),
            "bootstrap": to_repo_path(bootstrap_file, repo_root),
            "tool": "ai/health_check.py",
            "standalone_scripts": [
                "platforms/windows/hotkeys/layouts/colemak-dh.ahk"
            ],
        },
    }

    return summary, full


def main() -> int:
    parser = argparse.ArgumentParser(description="AI-friendly health check for keyflow.")
    parser.add_argument("--repo-root", default=".", help="Repository root to inspect.")
    parser.add_argument("--output", help="Path for full JSON output.")
    parser.add_argument("--output-summary", help="Path for summary JSON output.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON.")
    parser.add_argument("--summary", action="store_true", help="Print summary only (no full JSON to stdout).")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    indent = 2 if args.pretty else None
    summary, full = run(repo_root)

    if args.output_summary:
        out = Path(args.output_summary)
        if not out.is_absolute():
            out = (repo_root / args.output_summary).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(summary, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")

    if args.output:
        out = Path(args.output)
        if not out.is_absolute():
            out = (repo_root / args.output).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(full, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")

    if args.summary:
        sys.stdout.write(json.dumps(summary, indent=indent, ensure_ascii=False) + "\n")
    else:
        sys.stdout.write(json.dumps(full, indent=indent, ensure_ascii=False) + "\n")

    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
