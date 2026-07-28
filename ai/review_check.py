#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# Fallback phrases used only when governance.json is unavailable or malformed.
_FALLBACK_ROLE_PHRASES = (
    "This repository is permanently operated as a dual-role AI-first repo.",
    "The two supported roles are architect and executor.",
    "Write for the next handoff, not for your own memory.",
    "AI is the primary code maintainer.",
)

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def read_json(path: Path) -> dict:
    return json.loads(read_text(path))


def find_section(text: str, heading: str) -> str:
    pattern = re.compile(
        rf"^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def detect_plan_state(plan_text: str) -> str:
    match = re.search(r"^Status:\s*(.+?)\s*$", plan_text, re.MULTILINE | re.IGNORECASE)
    if not match:
        return "invalid"
    status = match.group(1).lower()
    return {
        "in progress": "active",
        "complete": "complete",
        "deferred": "deferred",
    }.get(status, "invalid")


def build_review(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    summary_path = repo_root / "ai/health-check.summary.json"
    agents_path = repo_root / "AGENTS.md"
    readme_path = repo_root / "README.md"
    current_plan_path = repo_root / "ai/current-plan.md"
    governance_path = repo_root / "ai/governance.json"
    gitignore_path = repo_root / ".gitignore"

    summary = read_json(summary_path)
    governance = read_json(governance_path)
    agents_text = read_text(agents_path)
    readme_text = read_text(readme_path)
    plan_text = read_text(current_plan_path)
    gitignore_text = read_text(gitignore_path)

    # Load role contract requirements from governance.
    required_role_phrases: list[str] = governance.get("required_role_phrases") or list(_FALLBACK_ROLE_PHRASES)
    agents_frontier = find_section(agents_text, "Next evolution frontier")
    readme_guide = find_section(readme_text, "AI operating guide")
    plan_state = detect_plan_state(plan_text)
    pycache_dir = repo_root / "ai/__pycache__"

    issues: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    checks: list[dict[str, object]] = []

    def add_check(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "ok": ok, "detail": detail})

    health_ok = bool(summary.get("ok"))
    add_check("health-summary-ok", health_ok, f"health-check summary ok={health_ok}")
    if not health_ok:
        issues.append(
            {
                "type": "health_summary_not_ok",
                "file": "ai/health-check.summary.json",
                "message": "Review cannot trust the handoff because health-check summary is not ok.",
            }
        )

    agents_mentions_plan = "ai/current-plan.md" in agents_frontier
    add_check("agents-plan-reference", agents_mentions_plan, "AGENTS next frontier section points to current-plan.md")
    if not agents_mentions_plan:
        issues.append(
            {
                "type": "agents_frontier_missing_plan_reference",
                "file": "AGENTS.md",
                "message": "AGENTS next frontier must point to ai/current-plan.md without duplicating plan state.",
            }
        )

    readme_mentions_review = "review_check.py" in readme_guide
    add_check("readme-review-command", readme_mentions_review, "README AI operating guide exposes review_check.py")
    if not readme_mentions_review:
        warnings.append(
            {
                "type": "readme_review_command_missing",
                "file": "README.md",
                "message": "README AI operating guide does not expose the reviewer command.",
            }
        )

    agents_mentions_review = "review_check.py" in agents_text
    add_check("agents-review-command", agents_mentions_review, "AGENTS includes review_check.py in the workflow")
    if not agents_mentions_review:
        warnings.append(
            {
                "type": "agents_review_command_missing",
                "file": "AGENTS.md",
                "message": "AGENTS does not mention the reviewer command.",
            }
        )

    cycle_outputs = governance.get("cycle_outputs", {})
    always_outputs = cycle_outputs.get("always", []) if isinstance(cycle_outputs, dict) else []
    governance_ok = always_outputs == ["ai/health-check.json", "ai/health-check.summary.json"]
    add_check("governance-cycle-outputs", governance_ok, "only generated health artifacts are mandatory every cycle")
    if not governance_ok:
        issues.append(
            {
                "type": "governance_cycle_outputs_invalid",
                "file": "ai/governance.json",
                "message": "governance cycle_outputs must keep policy and routing files conditional.",
            }
        )

    dual_role_governance = governance.get("dual_role_repo") is True
    add_check("governance-dual-role", dual_role_governance, "governance declares the repo as dual-role")
    if not dual_role_governance:
        issues.append(
            {
                "type": "governance_dual_role_missing",
                "file": "ai/governance.json",
                "message": "governance.json must declare dual_role_repo=true.",
            }
        )

    maintenance_model = governance.get("maintenance_model", {})
    maintenance_model_ok = (
        isinstance(maintenance_model, dict)
        and maintenance_model.get("primary_code_maintainer") == "ai"
        and maintenance_model.get("code_audience") == "ai-maintenance-first"
        and maintenance_model.get("human_role")
        == ["intent", "human-owned contracts", "runtime acceptance"]
    )
    add_check(
        "governance-ai-maintenance",
        maintenance_model_ok,
        "governance declares AI-first code maintenance and the human acceptance boundary",
    )
    if not maintenance_model_ok:
        issues.append(
            {
                "type": "governance_maintenance_model_invalid",
                "file": "ai/governance.json",
                "message": "governance maintenance_model is not in the expected AI-first shape.",
            }
        )

    agents_role_heading = "## Role rules" in agents_text
    add_check("agents-role-heading", agents_role_heading, "AGENTS contains the Role rules section")
    if not agents_role_heading:
        issues.append(
            {
                "type": "agents_role_heading_missing",
                "file": "AGENTS.md",
                "message": "AGENTS.md must preserve the Role rules section.",
            }
        )

    missing_phrases = [phrase for phrase in required_role_phrases if phrase not in agents_text]
    add_check("agents-role-phrases", len(missing_phrases) == 0, "AGENTS preserves mandatory role contract phrases")
    for phrase in missing_phrases:
        issues.append(
            {
                "type": "agents_role_phrase_missing",
                "file": "AGENTS.md",
                "message": f"AGENTS.md is missing required role phrase: {phrase}",
            }
        )

    pycache_ignored = "__pycache__/" in gitignore_text or "ai/__pycache__/" in gitignore_text
    add_check("pycache-ignored", pycache_ignored, "Python cache artifacts are ignored")
    if not pycache_ignored:
        warnings.append(
            {
                "type": "pycache_not_ignored",
                "file": ".gitignore",
                "message": "Python cache artifacts are not ignored.",
            }
        )

    pycache_present = pycache_dir.exists()
    add_check("pycache-present", not pycache_present, "No ai/__pycache__ runtime noise remains in the working tree")
    if pycache_present:
        warnings.append(
            {
                "type": "pycache_present",
                "file": "ai/__pycache__",
                "message": "Generated Python cache artifacts are still present locally. Safe to delete.",
            }
        )

    valid_plan_state = plan_state in {"active", "complete", "deferred"}
    add_check("plan-state", valid_plan_state, f"current plan state is {plan_state}")
    if not valid_plan_state:
        issues.append(
            {
                "type": "plan_state_invalid",
                "file": "ai/current-plan.md",
                "message": "Current plan must declare Status: in progress, complete, or deferred.",
            }
        )

    run_smoke_present = (repo_root / "ai/run_smoke.py").exists()
    add_check("run-smoke-tooling-present", run_smoke_present, "ai/run_smoke.py exists — runtime smoke recorder is available")
    if not run_smoke_present:
        warnings.append(
            {
                "type": "run_smoke_tooling_missing",
                "file": "ai/run_smoke.py",
                "message": "ai/run_smoke.py is missing. Agents cannot record runtime smoke execution results.",
            }
        )

    result_summary = {
        "ok": len(issues) == 0,
        "issue_count": len(issues),
        "warning_count": len(warnings),
        "plan_state": plan_state,
        "health_ok": health_ok,
        "plan": "ai/current-plan.md",
        "reviewer_commands": {
            "health": "python ai/health_check.py --pretty --summary",
            "review": "python ai/review_check.py --pretty --summary",
        },
        "checks": checks,
    }

    full = {
        "summary": result_summary,
        "issues": issues,
        "warnings": warnings,
        "artifacts": {
            "summary": "ai/health-check.summary.json",
            "repo_map": "ai/repo-map.json",
            "agents": "AGENTS.md",
            "readme": "README.md",
            "current_plan": "ai/current-plan.md",
            "governance": "ai/governance.json",
        },
    }
    return result_summary, full


def main() -> int:
    parser = argparse.ArgumentParser(description="Reviewer-oriented cycle audit for keyflow.")
    parser.add_argument("--repo-root", default=".", help="Repository root to inspect.")
    parser.add_argument("--output", help="Path for full JSON output.")
    parser.add_argument("--output-summary", help="Path for summary JSON output.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON.")
    parser.add_argument("--summary", action="store_true", help="Print summary only.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    indent = 2 if args.pretty else None
    summary, full = build_review(repo_root)

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
