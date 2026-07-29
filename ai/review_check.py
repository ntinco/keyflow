#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


PLAN_POINTER = "- Active plan and pending actions: `ai/current-plan.md`."


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def read_json(path: Path) -> dict:
    return json.loads(read_text(path))


def find_section(text: str, heading: str) -> str:
    match = re.search(
        rf"^##\s+{re.escape(heading)}\s*$\n(.*?)(?=^##\s+|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    return match.group(1).strip() if match else ""


def detect_plan_state(plan_text: str) -> str:
    match = re.search(r"^Status:\s*(.+?)\s*$", plan_text, re.MULTILINE | re.IGNORECASE)
    if not match:
        return "invalid"
    return {
        "in progress": "active",
        "complete": "complete",
        "deferred": "deferred",
    }.get(match.group(1).lower(), "invalid")


def build_review(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    summary = read_json(repo_root / "ai/health-check.summary.json")
    agents_text = read_text(repo_root / "AGENTS.md")
    readme_text = read_text(repo_root / "README.md")
    plan_text = read_text(repo_root / "ai/current-plan.md")

    issues: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    checks: list[dict[str, object]] = []

    def check(name: str, ok: bool, detail: str, issue_type: str, file: str) -> None:
        checks.append({"name": name, "ok": ok, "detail": detail})
        if not ok:
            issues.append({"type": issue_type, "file": file, "message": detail})

    health_ok = summary.get("ok") is True
    check(
        "health-summary",
        health_ok,
        "health-check summary must be ok",
        "health_summary_not_ok",
        "ai/health-check.summary.json",
    )

    plan_pointer = find_section(agents_text, "Next evolution frontier")
    check(
        "stable-plan-pointer",
        plan_pointer == PLAN_POINTER,
        "AGENTS must point to current-plan.md without duplicating plan state",
        "agents_plan_pointer_invalid",
        "AGENTS.md",
    )

    plan_state = detect_plan_state(plan_text)
    check(
        "plan-state",
        plan_state in {"active", "complete", "deferred"},
        f"current plan state is {plan_state}",
        "plan_state_invalid",
        "ai/current-plan.md",
    )

    if plan_state == "active":
        check(
            "active-plan-actions",
            "## Next actions" in plan_text,
            "active plan must expose next actions",
            "active_plan_actions_missing",
            "ai/current-plan.md",
        )

    for name, text, file in (
        ("agents-review-command", agents_text, "AGENTS.md"),
        ("readme-review-command", find_section(readme_text, "AI operating guide"), "README.md"),
    ):
        ok = "review_check.py" in text
        checks.append({"name": name, "ok": ok, "detail": "review command is discoverable"})
        if not ok:
            warnings.append(
                {
                    "type": "review_command_missing",
                    "file": file,
                    "message": "review_check.py is not discoverable.",
                }
            )

    result = {
        "ok": not issues,
        "issue_count": len(issues),
        "warning_count": len(warnings),
        "plan_state": plan_state,
        "health_ok": health_ok,
        "plan": "ai/current-plan.md",
        "checks": checks,
    }
    return result, {
        "summary": result,
        "issues": issues,
        "warnings": warnings,
        "artifacts": {
            "summary": "ai/health-check.summary.json",
            "agents": "AGENTS.md",
            "current_plan": "ai/current-plan.md",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit cycle closure and plan handoff.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output")
    parser.add_argument("--output-summary")
    parser.add_argument("--pretty", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    summary, full = build_review(repo_root)
    payload = summary if args.summary else full
    rendered = json.dumps(payload, indent=2 if args.pretty else None, ensure_ascii=False)

    for output_path, output_payload in (
        (args.output, full),
        (args.output_summary, summary),
    ):
        if output_path:
            target = Path(output_path)
            if not target.is_absolute():
                target = repo_root / target
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                json.dumps(output_payload, indent=2 if args.pretty else None, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )

    print(rendered)
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
