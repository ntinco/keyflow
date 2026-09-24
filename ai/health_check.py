#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

RE_INCLUDE = re.compile(r'^\s*#Include\s+"?([^"\r\n]+)"?', re.MULTILINE)
RE_SERVICE_CALL = re.compile(r"services\.([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)")
RE_ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:=", re.MULTILINE)
RE_GROUP_ADD = re.compile(r'GroupAdd\("([^"]+)"')
RE_APP_TARGET = re.compile(r'appActivationTargets\.Push\(\["([^"]+)"')
RE_HOTIF_OPEN = re.compile(r"^\s*#[Hh]ot[Ii]f\b(?!\s*$)", re.MULTILINE)
RE_HOTIF_CLOSE = re.compile(r"^\s*#[Hh]ot[Ii]f\s*$", re.MULTILINE)
RE_LUA_DOFILE = re.compile(r'dofile\(scriptDir\s*\.\.\s*"([^"]+)"\)')

RESERVED_METHOD_NAMES = {
    "if", "else", "for", "while", "switch", "case", "catch", "try", "return", "loop",
}

LEGACY_ENV_PREFIX = "NOR" "MAN_"
LEGACY_WORKSPACE_NAME = "nor" "man_src"
RETIRED_DOCS_SEGMENT = "do" "cs/"
FORBIDDEN_REFERENCE_PATTERNS = (
    ("legacy_env_symbol", re.compile(r"\b" + re.escape(LEGACY_ENV_PREFIX) + r"[A-Z0-9_]+\b")),
    ("legacy_workspace_name", re.compile(re.escape(LEGACY_WORKSPACE_NAME), re.IGNORECASE)),
    ("retired_docs_reference", re.compile(r"(^|[\s`\"'=:(])" + re.escape(RETIRED_DOCS_SEGMENT), re.IGNORECASE | re.MULTILINE)),
)
FORBIDDEN_SCAN_EXCLUDED_PREFIXES = (".git/", ".axet-code/", "ai/__pycache__/")
FORBIDDEN_SCAN_EXACT_PATHS = {
    "ai/health-check.json",
    "ai/health-check.summary.json",
    "ai/health_check.py",
    "ai/run-result.json",
    "ai/run-result-macos.json",
    "platforms/windows/data/local-secrets.ini",
    "platforms/windows/data/local-startup.ini",
    "platforms/shared/data/memory-vars.ini",
    "platforms/shared/data/local-paths.ini",
    "platforms/windows/data/rom.ini",
    "storage.db",
    "platforms/windows/storage.db",
}

KNOWN_DEAD_CLASSES = {"PasteService"}
KNOWN_DEAD_CONSTANTS: tuple[str, ...] = ()
CATALOG_REVIEW_STATUS_VALUES = {"pending_human_review", "verified"}
GOVERNANCE_FILE = "ai/governance.md"
REPO_MAP_FILE = "ai/repo-map.json"
CATALOG_REVIEW_FILE = "ai/catalog-review.json"
HOTKEY_CATALOG_FILE = "platforms/shared/data/hotkeys.db"


def to_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.relative_to(repo_root).as_posix()
    except ValueError:
        return path.as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def nested(mapping: dict[str, object], *keys: str, default: str = "") -> str:
    value: object = mapping
    for key in keys:
        if not isinstance(value, dict):
            return default
        value = value.get(key, {})
    return value if isinstance(value, str) else default


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
    entries: list[dict[str, str]] = []
    for label, group, mode in re.findall(
        r'\{label:\s*"([^"]+)",\s*group:\s*"([^"]*)",\s*mode:\s*"([^"]+)"\}', block
    ):
        entries.append({"label": label, "group": group, "mode": mode})
    return entries


def resolve_include(include_value: str, current_file: Path) -> Path:
    return (current_file.parent / include_value.replace("\\", "/")).resolve()


def build_include_graph(entry_file: Path, repo_root: Path) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    if not entry_file.exists():
        return [], [{
            "type": "entrypoint_missing",
            "file": to_repo_path(entry_file, repo_root),
            "message": "Windows entrypoint is missing.",
        }]

    visited: set[Path] = set()
    include_edges: list[dict[str, object]] = []
    missing: list[dict[str, str]] = []

    def walk(file_path: Path) -> None:
        if file_path in visited:
            return
        visited.add(file_path)
        includes: list[dict[str, object]] = []
        for include_value in RE_INCLUDE.findall(read_text(file_path)):
            target = resolve_include(include_value, file_path)
            exists = target.exists()
            includes.append({
                "include": include_value.replace("\\", "/"),
                "target": to_repo_path(target, repo_root),
                "exists": exists,
            })
            if exists:
                walk(target)
            else:
                missing.append({
                    "type": "include_missing",
                    "from": to_repo_path(file_path, repo_root),
                    "include": include_value.replace("\\", "/"),
                    "target": to_repo_path(target, repo_root),
                    "message": "Included AutoHotkey file is missing.",
                })
        include_edges.append({"file": to_repo_path(file_path, repo_root), "includes": includes})

    walk(entry_file.resolve())
    include_edges.sort(key=lambda item: str(item["file"]))
    missing.sort(key=lambda item: (item.get("from", ""), item.get("include", "")))
    return include_edges, missing


def parse_class_methods(text: str) -> dict[str, dict[str, object]]:
    results: dict[str, dict[str, object]] = {}
    current_class: str | None = None
    class_depth = 0
    for line in text.splitlines():
        class_match = re.match(
            r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+extends\s+([A-Za-z_][A-Za-z0-9_]*))?\s*\{", line
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
                methods = results[current_class]["methods"]
                if method_name not in RESERVED_METHOD_NAMES and method_name not in methods:
                    methods.append(method_name)
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
        classes = meta.get("classes", {})
        if not isinstance(classes, dict):
            continue
        for class_name, class_meta in classes.items():
            if isinstance(class_meta, dict):
                lookup[class_name] = {
                    "file": repo_path,
                    "methods": class_meta.get("methods", []),
                    "parent": class_meta.get("parent", ""),
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
        for method_name in class_meta.get("methods", []):
            if isinstance(method_name, str) and method_name not in resolved:
                resolved.append(method_name)
        parent = class_meta.get("parent", "")
        current = parent if isinstance(parent, str) else ""
    return resolved


def validate_profiles(profiles: list[dict[str, str]], data_dir: Path, repo_root: Path) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    results: list[dict[str, object]] = []
    issues: list[dict[str, str]] = []
    for profile in profiles:
        json_path = data_dir / f"{profile['label']}.json"
        entry: dict[str, object] = {**profile, "file": to_repo_path(json_path, repo_root), "exists": json_path.exists()}
        if json_path.exists():
            try:
                payload = json.loads(json_path.read_text(encoding="utf-8-sig"))
                has_items = isinstance(payload, dict) and isinstance(payload.get("items"), list)
                entry["json_valid"] = True
                entry["has_items_array"] = has_items
                entry["item_count"] = len(payload.get("items", [])) if has_items else None
                if not has_items:
                    issues.append({
                        "type": "profile_catalog_shape",
                        "file": to_repo_path(json_path, repo_root),
                        "message": "Catalog is valid JSON but does not expose items[].",
                    })
            except json.JSONDecodeError as exc:
                entry["json_valid"] = False
                entry["error"] = str(exc)
                issues.append({
                    "type": "profile_catalog_invalid_json",
                    "file": to_repo_path(json_path, repo_root),
                    "message": str(exc),
                })
        else:
            issues.append({
                "type": "profile_catalog_missing",
                "file": to_repo_path(json_path, repo_root),
                "message": "Expected hotstring catalog file is missing.",
            })
        results.append(entry)
    return results, issues


def validate_catalog_review(repo_root: Path, review_rel: str, profiles: list[dict[str, str]]) -> tuple[dict[str, object], list[dict[str, str]]]:
    review_path = repo_root / review_rel
    expected_catalogs = {profile["label"]: f"platforms/windows/data/{profile['label']}.json" for profile in profiles}
    result: dict[str, object] = {"file": review_rel, "exists": review_path.exists(), "catalogs": []}
    issues: list[dict[str, str]] = []

    if not review_path.exists():
        return result, [{"type": "catalog_review_missing", "file": review_rel, "message": "Catalog review contract is missing."}]
    try:
        payload = json.loads(review_path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        return result, [{"type": "catalog_review_invalid_json", "file": review_rel, "message": str(exc)}]

    catalogs = payload.get("catalogs")
    if not isinstance(catalogs, list):
        return result, [{"type": "catalog_review_catalogs_missing", "file": review_rel, "message": "catalog-review.json must expose catalogs[] as a list."}]

    seen_ids: set[str] = set()
    pending_count = 0
    verified_count = 0
    for entry in catalogs:
        if not isinstance(entry, dict):
            issues.append({"type": "catalog_review_entry_invalid", "file": review_rel, "message": "Each catalogs[] item must be an object."})
            continue
        catalog_id = entry.get("id", "")
        catalog_file = entry.get("file", "")
        status = entry.get("status", "")
        verified_on = entry.get("last_human_verification", "")
        result["catalogs"].append(entry)
        if not isinstance(catalog_id, str) or not catalog_id:
            issues.append({"type": "catalog_review_id_missing", "file": review_rel, "message": "Each catalog review entry must define a string id."})
            continue
        if catalog_id in seen_ids:
            issues.append({"type": "catalog_review_duplicate_id", "file": review_rel, "message": f"Duplicate catalog review id: {catalog_id}"})
        seen_ids.add(catalog_id)
        expected_file = expected_catalogs.get(catalog_id)
        if not expected_file:
            issues.append({"type": "catalog_review_unknown_id", "file": review_rel, "message": f"Catalog review entry does not match an active catalog: {catalog_id}"})
        elif catalog_file != expected_file:
            issues.append({"type": "catalog_review_file_mismatch", "file": review_rel, "message": f"Catalog review entry for {catalog_id} must point to {expected_file}."})
        if status not in CATALOG_REVIEW_STATUS_VALUES:
            issues.append({"type": "catalog_review_status_invalid", "file": review_rel, "message": f"Unknown catalog review status for {catalog_id}: {status}"})
        elif status == "pending_human_review":
            pending_count += 1
        else:
            verified_count += 1
            if not verified_on:
                issues.append({"type": "catalog_review_verified_date_missing", "file": review_rel, "message": f"Verified catalog {catalog_id} must include last_human_verification."})
            else:
                try:
                    date.fromisoformat(str(verified_on))
                except ValueError:
                    issues.append({"type": "catalog_review_verified_date_invalid", "file": review_rel, "message": f"Catalog {catalog_id} has invalid verification date: {verified_on}"})
    for missing_id in sorted(set(expected_catalogs) - seen_ids):
        issues.append({"type": "catalog_review_entry_missing", "file": review_rel, "message": f"Active catalog missing from review contract: {missing_id}"})
    result["pending_human_review_count"] = pending_count
    result["verified_count"] = verified_count
    return result, issues


def load_repo_map(repo_root: Path) -> tuple[dict[str, object], list[dict[str, str]]]:
    path = repo_root / REPO_MAP_FILE
    if not path.exists():
        return {}, [{"type": "repo_map_missing", "file": REPO_MAP_FILE, "message": "Routing map is missing."}]
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        return {}, [{"type": "repo_map_invalid_json", "file": REPO_MAP_FILE, "message": str(exc)}]
    if not isinstance(payload, dict):
        return {}, [{"type": "repo_map_invalid", "file": REPO_MAP_FILE, "message": "repo-map.json must be an object."}]
    return payload, []


def validate_repo_map(repo_root: Path, repo_map: dict[str, object]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    expected_keys = {"schema_version", "purpose", "routing", "ownership", "local_only", "validators"}
    if set(repo_map) != expected_keys:
        issues.append({
            "type": "repo_map_top_level_shape",
            "file": REPO_MAP_FILE,
            "message": f"repo-map.json keys must be {sorted(expected_keys)}.",
        })
    if repo_map.get("schema_version") != "1.0":
        issues.append({"type": "repo_map_schema_version", "file": REPO_MAP_FILE, "message": "schema_version must be 1.0."})
    if not isinstance(repo_map.get("purpose"), str) or not str(repo_map.get("purpose", "")).strip():
        issues.append({"type": "repo_map_purpose", "file": REPO_MAP_FILE, "message": "purpose must be a non-empty string."})

    route_specs = [
        ("governance",),
        ("windows", "entrypoint"), ("windows", "bootstrap"), ("windows", "services"), ("windows", "hotkeys"), ("windows", "catalogs"),
        ("macos", "entrypoint"), ("macos", "actions"), ("macos", "hotstrings"), ("macos", "generated"),
        ("shared", "hotkeys"), ("shared", "catalog_review"),
        ("validation", "health"), ("validation", "hotkey_sync"), ("validation", "smoke"),
    ]
    routing = repo_map.get("routing")
    if not isinstance(routing, dict):
        issues.append({"type": "repo_map_routing", "file": REPO_MAP_FILE, "message": "routing must be an object."})
    else:
        for keys in route_specs:
            rel = nested(routing, *keys)
            if not rel:
                issues.append({"type": "repo_map_route_missing", "file": REPO_MAP_FILE, "message": f"Missing route: {'.'.join(keys)}"})
            elif not (repo_root / rel).exists():
                issues.append({"type": "repo_map_dead_route", "file": REPO_MAP_FILE, "message": f"Route {'.'.join(keys)} points to missing path: {rel}"})
        active_work = nested(routing, "conditional", "active_work")
        if active_work and (repo_root / active_work).exists() and not (repo_root / active_work).is_file():
            issues.append({"type": "repo_map_active_work_invalid", "file": REPO_MAP_FILE, "message": "conditional.active_work must point to a file when present."})

    ownership = repo_map.get("ownership")
    if not isinstance(ownership, dict):
        issues.append({"type": "repo_map_ownership", "file": REPO_MAP_FILE, "message": "ownership must be an object."})
    else:
        for key in ("human_owned", "generated_versioned", "generated_local"):
            if not isinstance(ownership.get(key), list):
                issues.append({"type": "repo_map_ownership_list", "file": REPO_MAP_FILE, "message": f"ownership.{key} must be a list."})
        for rel in ownership.get("human_owned", []) if isinstance(ownership.get("human_owned"), list) else []:
            if not isinstance(rel, str) or not (repo_root / rel).exists():
                issues.append({"type": "repo_map_human_owned_missing", "file": REPO_MAP_FILE, "message": f"Human-owned path is missing: {rel}"})
        for rel in ownership.get("generated_versioned", []) if isinstance(ownership.get("generated_versioned"), list) else []:
            if not isinstance(rel, str):
                continue
            if "*" in rel:
                if not list(repo_root.glob(rel)):
                    issues.append({"type": "repo_map_generated_route_missing", "file": REPO_MAP_FILE, "message": f"Generated path pattern matches nothing: {rel}"})
            elif not (repo_root / rel).exists():
                issues.append({"type": "repo_map_generated_route_missing", "file": REPO_MAP_FILE, "message": f"Generated path is missing: {rel}"})

    local_only = repo_map.get("local_only")
    if not isinstance(local_only, list):
        issues.append({"type": "repo_map_local_only", "file": REPO_MAP_FILE, "message": "local_only must be a list."})
    else:
        generated_local = ownership.get("generated_local", []) if isinstance(ownership, dict) else []
        if isinstance(generated_local, list):
            missing_local = sorted(set(generated_local) - set(local_only))
            if missing_local:
                issues.append({"type": "repo_map_generated_local_gap", "file": REPO_MAP_FILE, "message": f"generated_local paths must also be local_only: {missing_local}"})

    validators = repo_map.get("validators")
    if not isinstance(validators, list) or not validators or any(not isinstance(value, str) or not value.strip() for value in validators):
        issues.append({"type": "repo_map_validators", "file": REPO_MAP_FILE, "message": "validators must be a non-empty list of commands."})
    return issues


def validate_control_plane(repo_root: Path, repo_map: dict[str, object]) -> tuple[dict[str, object], list[dict[str, str]]]:
    issues: list[dict[str, str]] = []
    # Compare real directory entries: Path.exists() is case-insensitive on macOS/Windows.
    root_names = {entry.name for entry in repo_root.iterdir()}
    if "AGENTS.md" not in root_names:
        issues.append({"type": "agents_missing", "file": "AGENTS.md", "message": "AGENTS.md cold-start contract is missing."})
    if "agents.md" in root_names:
        issues.append({"type": "agents_wrong_case", "file": "agents.md", "message": "Lowercase agents.md must not coexist with AGENTS.md."})
    if not (repo_root / "README.md").is_file():
        issues.append({"type": "readme_missing", "file": "README.md", "message": "README.md is missing."})
    governance_rel = nested(repo_map.get("routing", {}) if isinstance(repo_map.get("routing"), dict) else {}, "governance", default=GOVERNANCE_FILE)
    governance_path = repo_root / governance_rel
    if not governance_path.is_file():
        issues.append({"type": "governance_missing", "file": governance_rel, "message": "Durable governance file is missing."})
    if (repo_root / "ai/governance.json").exists():
        issues.append({"type": "duplicate_governance", "file": "ai/governance.json", "message": "Legacy governance JSON duplicates policy authority."})
    return {"file": governance_rel, "exists": governance_path.exists()}, issues


def git_path_ignored(repo_root: Path, rel: str, gitignore_text: str) -> bool:
    if (repo_root / ".git").exists():
        result = subprocess.run(
            ["git", "check-ignore", "-q", "--no-index", rel],
            cwd=repo_root,
            capture_output=True,
            check=False,
        )
        return result.returncode == 0
    basename = Path(rel).name
    return rel in gitignore_text or basename in gitignore_text


def git_path_tracked(repo_root: Path, rel: str) -> bool:
    if not (repo_root / ".git").exists():
        return False
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", rel],
        cwd=repo_root,
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def validate_local_only_contract(repo_root: Path, repo_map: dict[str, object]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    local_only = repo_map.get("local_only", [])
    if not isinstance(local_only, list):
        return issues
    gitignore_path = repo_root / ".gitignore"
    gitignore_text = read_text(gitignore_path) if gitignore_path.exists() else ""
    for rel in local_only:
        if not isinstance(rel, str):
            continue
        if not git_path_ignored(repo_root, rel, gitignore_text):
            issues.append({"type": "local_only_gitignore_gap", "file": ".gitignore", "message": f"Local-only path is not ignored: {rel}"})
        if git_path_tracked(repo_root, rel):
            issues.append({"type": "local_only_tracked", "file": rel, "message": "Local-only/generated path must not be tracked."})
    return issues


def build_service_contracts(registry: dict[str, str], class_lookup: dict[str, dict[str, object]], file_index: dict[str, dict[str, object]]) -> tuple[list[dict[str, object]], list[dict[str, str]], list[dict[str, str]], list[dict[str, object]]]:
    service_contracts: list[dict[str, object]] = []
    registry_issues: list[dict[str, str]] = []
    service_call_issues: list[dict[str, str]] = []
    public_api_candidates: list[dict[str, object]] = []
    service_calls_by_key: defaultdict[str, set[str]] = defaultdict(set)
    for meta in file_index.values():
        for service_key, method_name in meta.get("service_calls", []):
            service_calls_by_key[service_key].add(method_name)
    for service_key, class_name in registry.items():
        class_meta = class_lookup.get(class_name)
        referenced_methods = sorted(service_calls_by_key.get(service_key, set()))
        declared_methods = resolve_declared_methods(class_name, class_lookup) if class_meta else []
        service_contracts.append({
            "service": service_key,
            "class": class_name,
            "class_file": class_meta["file"] if class_meta else "",
            "referenced_methods": referenced_methods,
            "declared_methods": declared_methods,
        })
        if not class_meta:
            registry_issues.append({"type": "registry_class_missing", "file": "platforms/windows/library/bootstrap.ahk", "message": f"Service {service_key} points to missing class {class_name}."})
            continue
        declared = set(declared_methods)
        for method_name in referenced_methods:
            if method_name not in declared:
                service_call_issues.append({"type": "service_method_missing", "file": str(class_meta["file"]), "message": f"services.{service_key}.{method_name} has no declared method on {class_name}."})
        public_only_methods = [method for method in declared_methods if not method.startswith("_") and method != "__new" and method not in referenced_methods]
        if public_only_methods:
            public_api_candidates.append({"service": service_key, "class": class_name, "methods": public_only_methods, "reason": "Public service methods have no services.* callers."})
    for service_key in sorted(service_calls_by_key):
        if service_key not in registry:
            service_call_issues.append({"type": "service_key_missing", "file": "platforms/windows", "message": f"services.{service_key} is called but not registered."})
    service_contracts.sort(key=lambda item: str(item["service"]))
    return service_contracts, registry_issues, service_call_issues, public_api_candidates


def collect_public_service_calls(file_index: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    public_calls: list[dict[str, object]] = []
    for repo_path, meta in sorted(file_index.items()):
        calls = meta.get("service_calls", [])
        if calls:
            public_calls.append({"file": repo_path, "calls": sorted({f"{service}.{method}" for service, method in calls})})
    return public_calls


def detect_dead_candidates(file_index: dict[str, dict[str, object]], registry: dict[str, str], token_counter: Counter[str]) -> dict[str, list[dict[str, object]]]:
    registered_classes = {name.lower() for name in registry.values()}
    class_candidates: list[dict[str, object]] = []
    for repo_path, meta in file_index.items():
        if "/library/automation/" not in repo_path:
            continue
        classes = meta.get("classes", {})
        if not isinstance(classes, dict):
            continue
        for class_name in classes:
            if class_name.lower() in registered_classes:
                continue
            if token_counter[class_name.lower()] <= 1 or class_name in KNOWN_DEAD_CLASSES:
                class_candidates.append({"file": repo_path, "class": class_name, "reason": "Class is defined but not registered and has no external callers."})
    constant_candidates = [
        {"constant": name, "reason": "Constant is declared but not referenced."}
        for name in KNOWN_DEAD_CONSTANTS if token_counter[name.lower()] <= 1
    ]
    return {
        "dead_class_candidates": sorted(class_candidates, key=lambda item: str(item["file"])),
        "dead_constant_candidates": constant_candidates,
    }


def scan_assignment_candidates(repo_root: Path, token_counter: Counter[str]) -> list[dict[str, str]]:
    path = repo_root / "platforms/windows/library/config/constants-core.ahk"
    if not path.exists():
        return []
    return [
        {"file": to_repo_path(path, repo_root), "symbol": name, "reason": "Assignment appears to be declared but not referenced elsewhere."}
        for name in RE_ASSIGN.findall(read_text(path)) if token_counter[name.lower()] <= 1
    ]


def scan_group_candidates(repo_root: Path, token_counter: Counter[str]) -> list[dict[str, str]]:
    path = repo_root / "platforms/windows/library/config/constants-core.ahk"
    if not path.exists():
        return []
    text = read_text(path)
    candidates: list[dict[str, str]] = []
    for group_name in sorted(set(RE_GROUP_ADD.findall(text))):
        if token_counter[group_name.lower()] <= 1:
            candidates.append({"symbol": group_name, "reason": "Window group is defined but not referenced elsewhere."})
    for target_name in sorted(set(RE_APP_TARGET.findall(text))):
        if token_counter[target_name.lower()] <= 1:
            candidates.append({"symbol": target_name, "reason": "Activation target is defined but not referenced elsewhere."})
    return candidates


def scan_hotkey_counts(hotkeys_dir: Path, repo_root: Path) -> dict[str, int]:
    hotkey_def = re.compile(r"^[^;\s][^:]*::{$", re.MULTILINE)
    counts: dict[str, int] = {}
    if not hotkeys_dir.exists():
        return counts
    for path in sorted(hotkeys_dir.rglob("*.ahk")):
        count = len(hotkey_def.findall(read_text(path)))
        if count:
            counts[to_repo_path(path, repo_root)] = count
    return counts


def scan_unclosed_hotif(hotkeys_dir: Path, repo_root: Path) -> list[dict[str, object]]:
    include_line = re.compile(r"^\s*#Include", re.MULTILINE)
    issues: list[dict[str, object]] = []
    if not hotkeys_dir.exists():
        return issues
    for path in sorted(hotkeys_dir.rglob("*.ahk")):
        text = read_text(path)
        opens = len(RE_HOTIF_OPEN.findall(text))
        if not opens or not include_line.search(text):
            continue
        closes = len(RE_HOTIF_CLOSE.findall(text))
        if opens > closes:
            issues.append({
                "type": "unclosed_hotif",
                "file": to_repo_path(path, repo_root),
                "message": f"Aggregator has #HotIf opened {opens}x but closed {closes}x.",
            })
    return issues


def scan_forbidden_references(repo_root: Path) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for path in sorted(repo_root.rglob("*")):
        if not path.is_file():
            continue
        rel_path = to_repo_path(path, repo_root)
        if rel_path in FORBIDDEN_SCAN_EXACT_PATHS or any(rel_path.startswith(prefix) for prefix in FORBIDDEN_SCAN_EXCLUDED_PREFIXES):
            continue
        if path.suffix.lower() not in {".ahk", ".ini", ".ps1", ".json", ".txt"}:
            continue
        text = read_text(path)
        for issue_type, pattern in FORBIDDEN_REFERENCE_PATTERNS:
            for match in pattern.finditer(text):
                findings.append({"type": issue_type, "file": rel_path, "match": match.group(0), "message": "Retired internal reference detected."})
    return findings


def validate_macos_runtime(repo_root: Path, macos_entry_rel: str) -> list[dict[str, object]]:
    init_file = repo_root / macos_entry_rel
    if not init_file.exists():
        return [{"type": "macos_entrypoint_missing", "file": macos_entry_rel, "message": "Hammerspoon entrypoint is missing."}]
    macos_dir = init_file.parent
    issues: list[dict[str, object]] = []
    text = read_text(init_file)
    required_runtime_ownership = {
        'package.loaded["keyflow.runtime"] = Runtime': "Hammerspoon runtime must retain owned objects across garbage collection.",
        "Runtime.appWatcher = hs.application.watcher.new": "Application watcher must have an explicit runtime owner.",
        "Runtime.keyWatcher = hs.eventtap.new": "Keyboard watcher must have an explicit runtime owner.",
        "Runtime.consoleToolbar = consoleToolbar": "Console toolbar must have an explicit runtime owner.",
        "consoleToolbar:allowedItems()": "Console toolbar definition must be idempotent across reloads.",
        'hs.settings.get("keyflow.consoleClearInstalled")': "Console toolbar installation must persist idempotency state.",
    }
    for contract, message in required_runtime_ownership.items():
        if contract not in text:
            issues.append({"type": "macos_runtime_ownership_missing", "file": macos_entry_rel, "contract": contract, "message": message})
    for include_value in RE_LUA_DOFILE.findall(text):
        target = (macos_dir / include_value).resolve()
        if not target.exists():
            issues.append({"type": "macos_include_missing", "file": macos_entry_rel, "include": include_value, "target": to_repo_path(target, repo_root), "message": "init.lua references a missing dofile target."})

    actions_file = macos_dir / "actions.lua"
    hotstrings_file = macos_dir / "hotstrings.lua"
    bindings_file = macos_dir / "generated/bindings.lua"
    profile_file = macos_dir / "generated/hotstring_profiles.lua"
    if not all(path.exists() for path in (actions_file, hotstrings_file, bindings_file, profile_file)):
        return issues
    actions_text = read_text(actions_file)
    hotstrings_text = read_text(hotstrings_file)
    bindings_text = read_text(bindings_file)
    profile_text = read_text(profile_file)
    action_ids = set(re.findall(r"(?:function\s+Actions\.|Actions\.)([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|\()", actions_text))
    hotstring_ids = set(re.findall(r"^\s*(hs_[A-Za-z0-9_]+)\s*=", hotstrings_text, re.MULTILINE))
    context_labels = set(re.findall(r'^\s*\["([^"]+)"\]\s*=', text, re.MULTILINE))
    if 'dofile(scriptDir .. "generated/hotstring_profiles.lua")' not in text:
        issues.append({"type": "macos_hotstring_profiles_not_loaded", "file": macos_entry_rel, "message": "Hammerspoon must load the generated hotstring profile catalog."})
    if "buildTriggers(bindings, profiles)" not in hotstrings_text:
        issues.append({"type": "macos_hotstring_profiles_not_consumed", "file": to_repo_path(hotstrings_file, repo_root), "message": "Hotstring watcher must consume generated profile data."})
    if "Actions.runSapTcode = runTcode" not in actions_text:
        issues.append({"type": "macos_hotstring_sap_adapter_missing", "file": to_repo_path(actions_file, repo_root), "message": "Hammerspoon must expose the SAP command adapter."})
    if "return {" not in profile_text:
        issues.append({"type": "macos_hotstring_profiles_invalid", "file": to_repo_path(profile_file, repo_root), "message": "Generated macOS hotstring profile catalog must return a Lua table."})

    bindings = re.findall(r'\{id\s*=\s*"([^"]+)",\s*type\s*=\s*"([^"]+)",.*?contextLabel\s*=\s*"([^"]*)",\s*tcode\s*=\s*"([^"]*)"', bindings_text)
    bound_hotkey_ids = {binding_id for binding_id, binding_type, _, _ in bindings if binding_type == "hotkey"}
    prefixes = ("eclipse_", "global_", "launcher_", "sap_gui_", "snipaste_")
    for action_id in sorted(action_ids):
        if action_id.startswith(prefixes) and action_id not in bound_hotkey_ids:
            issues.append({"type": "macos_action_without_binding", "file": to_repo_path(actions_file, repo_root), "action": action_id, "message": "Hammerspoon action has no generated hotkey binding."})

    runtime_contracts = {
        'hs.eventtap.keyStroke({"cmd", "alt"}, "o")': "SAP command dispatch must focus the native command field.",
        "Hotstrings.reset()": "Application changes must reset the hotstring buffer.",
        "iina-cli": "Alt+P must dispatch selected media through IINA's CLI.",
        "local iinaTask": "Alt+P must retain the asynchronous IINA task through completion.",
        'attributeValue("AXSelectedChildren")': "Finder paths must come from selected Accessibility elements.",
        "Actions.snipasteIsActive": "Snipaste overlay dispatch must be scoped to Snipaste.",
        'enter = "return"': "AHK Enter bindings must map to the macOS Return keycode.",
    }
    combined = text + "\n" + actions_text + "\n" + hotstrings_text
    for contract, message in runtime_contracts.items():
        if contract not in combined:
            issues.append({"type": "macos_runtime_contract_missing", "file": to_repo_path(macos_dir, repo_root), "contract": contract, "message": message})

    for binding_id, binding_type, context_label, tcode in bindings:
        if binding_type == "hotkey" and not tcode and binding_id not in action_ids:
            issues.append({"type": "macos_action_missing", "file": to_repo_path(actions_file, repo_root), "binding": binding_id, "message": "Generated macOS hotkey has no registered action."})
        if binding_type == "hotkey" and tcode and "Actions.runSapTcode(binding.tcode)" not in text:
            issues.append({"type": "macos_sap_tcode_adapter_missing", "file": macos_entry_rel, "binding": binding_id, "message": "Generated SAP binding requires the shared macOS SAP adapter."})
        if binding_type == "hotkey" and context_label != "global" and context_label not in context_labels:
            issues.append({"type": "macos_context_missing", "file": macos_entry_rel, "binding": binding_id, "context": context_label, "message": "Generated macOS hotkey references an unknown application context."})
        if binding_type == "hotstring" and binding_id not in hotstring_ids:
            issues.append({"type": "macos_hotstring_missing", "file": to_repo_path(hotstrings_file, repo_root), "binding": binding_id, "message": "Generated macOS hotstring has no registered trigger."})
    for runtime_file in (init_file, actions_file, hotstrings_file):
        if "hs.timer.usleep" in read_text(runtime_file):
            issues.append({"type": "macos_blocking_sleep", "file": to_repo_path(runtime_file, repo_root), "message": "Hammerspoon runtime must not block its main event thread with hs.timer.usleep."})
    return issues


def validate_hotkey_catalog(repo_root: Path, tool_rel: str, source_rel: str) -> list[dict[str, object]]:
    tool = repo_root / tool_rel
    if not tool.exists():
        return [{"type": "hotkey_sync_missing", "file": tool_rel, "message": "Hotkey sync validator is missing."}]
    result = subprocess.run(
        [sys.executable, str(tool), "--check"], cwd=repo_root, capture_output=True, text=True,
        encoding="utf-8", errors="replace", check=False,
    )
    if result.returncode == 0:
        return []
    detail = (result.stdout + result.stderr).strip()
    return [{"type": "hotkey_catalog_drift", "file": source_rel, "message": detail or "Hotkey catalog validation failed.", "fix": f"{sys.executable} {tool_rel} --sync"}]


def build_summary(issues: list[dict[str, object]], registry: dict[str, str], profile_results: list[dict[str, object]], catalog_review: dict[str, object], hotkey_counts: dict[str, int], dead_candidates: dict[str, list[dict[str, object]]], forbidden_references: list[dict[str, object]], current_plan_present: bool) -> dict[str, object]:
    return {
        "ok": not issues,
        "issue_count": len(issues),
        "services": sorted(registry),
        "profiles": {str(item["label"]): item.get("item_count", 0) for item in profile_results},
        "catalog_review": {
            "file": catalog_review.get("file", CATALOG_REVIEW_FILE),
            "exists": catalog_review.get("exists", False),
            "pending_human_review_count": catalog_review.get("pending_human_review_count", 0),
            "verified_count": catalog_review.get("verified_count", 0),
        },
        "hotkey_counts": hotkey_counts,
        "dead_class_candidates": [item["class"] for item in dead_candidates["dead_class_candidates"]],
        "dead_constant_candidates": [item["constant"] for item in dead_candidates["dead_constant_candidates"]],
        "forbidden_reference_count": len(forbidden_references),
        "current_plan_present": current_plan_present,
    }


def run(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    repo_map, repo_map_load_issues = load_repo_map(repo_root)
    repo_map_issues = validate_repo_map(repo_root, repo_map) if repo_map else []
    control_plane_result, control_plane_issues = validate_control_plane(repo_root, repo_map)
    local_only_issues = validate_local_only_contract(repo_root, repo_map) if repo_map else []

    routing = repo_map.get("routing", {}) if isinstance(repo_map.get("routing"), dict) else {}
    windows_entry_rel = nested(routing, "windows", "entrypoint", default="platforms/windows/keyflow.ahk")
    bootstrap_rel = nested(routing, "windows", "bootstrap", default="platforms/windows/library/bootstrap.ahk")
    hotkeys_rel = nested(routing, "windows", "hotkeys", default="platforms/windows/hotkeys/")
    data_rel = nested(routing, "windows", "catalogs", default="platforms/windows/data/")
    macos_entry_rel = nested(routing, "macos", "entrypoint", default="platforms/macos/hammerspoon/init.lua")
    hotkey_source_rel = nested(routing, "shared", "hotkeys", default=HOTKEY_CATALOG_FILE)
    catalog_review_rel = nested(routing, "shared", "catalog_review", default=CATALOG_REVIEW_FILE)
    hotkey_sync_rel = nested(routing, "validation", "hotkey_sync", default="ai/hotkey_sync.py")
    active_work_rel = nested(routing, "conditional", "active_work", default="ai/current-plan.md")

    keyflow_entry = repo_root / windows_entry_rel
    bootstrap_file = repo_root / bootstrap_rel
    hotkeys_dir = repo_root / hotkeys_rel
    data_dir = repo_root / data_rel
    bootstrap_text = read_text(bootstrap_file) if bootstrap_file.exists() else ""

    include_graph, include_missing = build_include_graph(keyflow_entry, repo_root)
    file_index, token_counter = parse_file_index(repo_root)
    class_lookup = build_class_lookup(file_index)
    registry = parse_registry(bootstrap_text)
    profiles = parse_hotstring_profiles(bootstrap_text)
    profile_results, profile_issues = validate_profiles(profiles, data_dir, repo_root)
    catalog_review_result, catalog_review_issues = validate_catalog_review(repo_root, catalog_review_rel, profiles)
    service_contracts, registry_issues, service_call_issues, public_api_candidates = build_service_contracts(registry, class_lookup, file_index)
    service_call_issues.extend({
        "type": "public_service_method_without_caller",
        "file": str(candidate["service"]),
        "message": f"{candidate['class']} exposes uncalled methods: {candidate['methods']}",
    } for candidate in public_api_candidates)
    public_calls = collect_public_service_calls(file_index)
    dead_candidates = detect_dead_candidates(file_index, registry, token_counter)
    unused_assignments = scan_assignment_candidates(repo_root, token_counter)
    unused_groups = scan_group_candidates(repo_root, token_counter)
    forbidden_references = scan_forbidden_references(repo_root)
    hotkey_counts = scan_hotkey_counts(hotkeys_dir, repo_root)
    unclosed_hotif = scan_unclosed_hotif(hotkeys_dir, repo_root)
    hotkey_catalog_issues = validate_hotkey_catalog(repo_root, hotkey_sync_rel, hotkey_source_rel)
    macos_runtime_issues = validate_macos_runtime(repo_root, macos_entry_rel)

    issues: list[dict[str, object]] = []
    for group in (
        repo_map_load_issues, repo_map_issues, control_plane_issues, local_only_issues,
        include_missing, registry_issues, service_call_issues, profile_issues,
        catalog_review_issues, hotkey_catalog_issues, macos_runtime_issues,
        unclosed_hotif, forbidden_references,
    ):
        issues.extend(group)

    summary = build_summary(
        issues, registry, profile_results, catalog_review_result, hotkey_counts,
        dead_candidates, forbidden_references, (repo_root / active_work_rel).is_file(),
    )
    full = {
        "summary": summary,
        "issues": issues,
        "audits": {
            "unused_assignments": unused_assignments,
            "unused_groups_or_targets": unused_groups,
            "public_service_methods_without_callers": public_api_candidates,
        },
        "contracts": {
            "repo_map": repo_map,
            "governance": control_plane_result,
            "include_graph": include_graph,
            "service_registry": service_contracts,
            "hotstring_profiles": profile_results,
            "catalog_review": catalog_review_result,
            "public_service_calls": public_calls,
        },
        "repo": {
            "entrypoint": windows_entry_rel,
            "bootstrap": bootstrap_rel,
            "tool": "ai/health_check.py",
        },
    }
    return summary, full


def main() -> int:
    parser = argparse.ArgumentParser(description="Mechanical health check for keyflow.")
    parser.add_argument("--repo-root", default=".", help="Repository root to inspect.")
    parser.add_argument("--output", help="Path for full JSON output.")
    parser.add_argument("--output-summary", help="Path for summary JSON output.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON.")
    parser.add_argument("--summary", action="store_true", help="Print summary only.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    indent = 2 if args.pretty else None
    summary, full = run(repo_root)
    if args.output_summary:
        out = Path(args.output_summary)
        if not out.is_absolute():
            out = (repo_root / out).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(summary, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.output:
        out = Path(args.output)
        if not out.is_absolute():
            out = (repo_root / out).resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(full, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")
    payload = summary if args.summary else full
    sys.stdout.write(json.dumps(payload, indent=indent, ensure_ascii=False) + "\n")
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
