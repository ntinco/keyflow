#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


RE_INCLUDE = re.compile(r'^\s*#Include\s+"?([^"\r\n]+)"?', re.MULTILINE)
RE_CLASS_HEADER = re.compile(
    r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+extends\s+([A-Za-z_][A-Za-z0-9_]*))?\s*\{",
    re.MULTILINE,
)
RE_SERVICE_CALL = re.compile(r"services\.([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)")
RE_ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:=", re.MULTILINE)
RE_GROUP_ADD = re.compile(r'GroupAdd\("([^"]+)"')
RE_APP_TARGET = re.compile(r'appActivationTargets\.Push\(\["([^"]+)"')

# These patterns are audit-only: reported in notes, never in issues[].
# NORMAN_* env vars are legacy-compatible external contracts and are kept as-is.
# norman_src path fragments are machine-local defaults, not public identifiers.
AUDIT_PATTERNS = (
    ("legacy_env_symbol", re.compile(r"\bNORMAN_[A-Z0-9_]+\b")),
    ("legacy_workspace_name", re.compile(r"norman_src", re.IGNORECASE)),
)

# Files and path prefixes excluded from legacy audit scans.
AUDIT_EXCLUDED_PREFIXES = (
    "ai/",
    "docs/",
    "README.md",
    "AGENTS.md",
    ".axet-code/",
    ".git/",
)

# Unregistered classes in library/automation/ that are known dead code.
KNOWN_DEAD_CLASSES = {"PasteService"}

# Constants that are declared but have no known consumers.
KNOWN_DEAD_CONSTANTS = ("sapQasSnippetsJsonFile", "hotkeyTrackerJsonFile")


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
                if method_name not in results[current_class]["methods"]:
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


def build_service_contracts(
    registry: dict[str, str],
    class_lookup: dict[str, dict[str, object]],
    file_index: dict[str, dict[str, object]],
) -> tuple[list[dict[str, object]], list[dict[str, str]], list[dict[str, str]]]:
    service_contracts = []
    registry_issues: list[dict[str, str]] = []
    service_call_issues: list[dict[str, str]] = []
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
    return service_contracts, registry_issues, service_call_issues


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
        "platforms/windows/library/config/constants-core-base.ahk",
        "platforms/windows/library/config/constants-core-paths.ahk",
        "platforms/windows/library/config/constants-core-apps.ahk",
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
    rules_path = repo_root / "platforms/windows/library/config/constants-core-rules.ahk"
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


def scan_legacy_audit(repo_root: Path) -> list[dict[str, object]]:
    """Audit-only scan: NORMAN_* and norman_src are not issues, just informational."""
    findings = []
    for path in sorted(repo_root.rglob("*")):
        if not path.is_file():
            continue
        rel_path = to_repo_path(path, repo_root)
        if any(rel_path.startswith(prefix) for prefix in AUDIT_EXCLUDED_PREFIXES):
            continue
        if path.suffix.lower() not in {".ahk", ".ini", ".ps1", ".json", ".txt"}:
            continue
        text = read_text(path)
        for issue_type, pattern in AUDIT_PATTERNS:
            for match in pattern.finditer(text):
                findings.append(
                    {
                        "type": issue_type,
                        "file": rel_path,
                        "match": match.group(0),
                    }
                )
    return findings


def build_summary(
    include_missing: list,
    registry_issues: list,
    service_call_issues: list,
    profile_issues: list,
    dead_candidates: dict,
    profile_results: list,
    registry: dict,
    legacy_audit: list,
) -> dict[str, object]:
    issues = include_missing + registry_issues + service_call_issues + profile_issues
    profile_counts = {p["label"]: p.get("item_count", 0) for p in profile_results}
    return {
        "ok": len(issues) == 0,
        "issue_count": len(issues),
        "services": sorted(registry.keys()),
        "profiles": profile_counts,
        "dead_class_candidates": [c["class"] for c in dead_candidates["dead_class_candidates"]],
        "dead_constant_candidates": [c["constant"] for c in dead_candidates["dead_constant_candidates"]],
        "legacy_audit_count": len(legacy_audit),
        "legacy_audit_note": "NORMAN_* and norman_src are legacy-compatible; not treated as issues.",
    }


def run(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    keyflow_entry = repo_root / "platforms/windows/keyflow.ahk"
    bootstrap_file = repo_root / "platforms/windows/library/bootstrap.ahk"
    data_dir = repo_root / "platforms/windows/data"
    bootstrap_text = read_text(bootstrap_file)

    include_graph, include_missing = build_include_graph(keyflow_entry, repo_root)
    file_index, token_counter = parse_file_index(repo_root)
    class_lookup = build_class_lookup(file_index)
    registry = parse_registry(bootstrap_text)
    profiles = parse_hotstring_profiles(bootstrap_text)
    profile_results, profile_issues = validate_profiles(profiles, data_dir, repo_root)
    service_contracts, registry_issues, service_call_issues = build_service_contracts(registry, class_lookup, file_index)
    public_calls = collect_public_service_calls(file_index)
    dead_candidates = detect_dead_candidates(file_index, registry, token_counter)
    unused_assignments = scan_assignment_candidates(repo_root, token_counter)
    unused_groups = scan_group_candidates(repo_root, token_counter)
    legacy_audit = scan_legacy_audit(repo_root)

    summary = build_summary(
        include_missing,
        registry_issues,
        service_call_issues,
        profile_issues,
        dead_candidates,
        profile_results,
        registry,
        legacy_audit,
    )

    full = {
        "summary": summary,
        "issues": {
            "include_missing": include_missing,
            "registry": registry_issues,
            "service_calls": service_call_issues,
            "profiles": profile_issues,
        },
        "dead_candidates": dead_candidates,
        "audits": {
            "unused_assignments": unused_assignments,
            "unused_groups_or_targets": unused_groups,
            "legacy_refs": legacy_audit,
        },
        "contracts": {
            "include_graph": include_graph,
            "service_registry": service_contracts,
            "hotstring_profiles": profile_results,
            "public_service_calls": public_calls,
        },
        "repo": {
            "entrypoint": to_repo_path(keyflow_entry, repo_root),
            "bootstrap": to_repo_path(bootstrap_file, repo_root),
            "tool": "ai/health_check.py",
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
