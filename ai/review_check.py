#!/usr/bin/env python
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


NO_ACTIVE_FRONTIER = (
    "No active frontier. Next technical plan deferred until a real frontier appears. "
    "Replace ai/current-plan.md when a new technical frontier is identified."
)

REGENERATE_COMMAND = (
    "python ai/health_check.py --pretty "
    "--output ai/health-check.json --output-summary ai/health-check.summary.json"
)

# Fallback phrases used only when governance.json is unavailable or malformed.
_FALLBACK_AGENTS_PHRASES = (
    "This repository is permanently operated as a multi-agent AI-first repo.",
    "This repo is shared by multiple AIs.",
    "Write for the next agent, not for your own memory.",
)

# Fallback current-model phrases used only when governance.json is unavailable or malformed.
_FALLBACK_CURRENT_MODEL_PHRASES = (
    "validate_local_only_contract()",
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
    lowered = plan_text.lower()
    if "status: complete" in lowered or "plan: completed" in lowered:
        return "completed"
    if "deferred" in lowered and "no new technical frontier" in lowered:
        return "deferred"
    return "active"


def is_stale_summary(summary_frontier: str, repo_map_frontier: str, plan_state: str) -> bool:
    """Return True when the mismatch looks like a stale generated artifact rather than
    a real contract disagreement.  The heuristic: the repo-map (authoritative) has an
    active frontier while the summary (generated) still reflects the previous closed
    state, or vice-versa.  Either way the fix is to regenerate, not to edit guides.
    """
    if summary_frontier == repo_map_frontier:
        return False
    # If one side is the known no-frontier sentinel and the other is not, the artifact
    # was simply not regenerated after the frontier changed.
    if summary_frontier == NO_ACTIVE_FRONTIER or repo_map_frontier == NO_ACTIVE_FRONTIER:
        return True
    # Both are non-empty and different — also a staleness signal (frontier text changed).
    if summary_frontier and repo_map_frontier:
        return True
    return False


def build_review(repo_root: Path) -> tuple[dict[str, object], dict[str, object]]:
    summary_path = repo_root / "ai/health-check.summary.json"
    repo_map_path = repo_root / "ai/repo-map.json"
    agents_path = repo_root / "AGENTS.md"
    readme_path = repo_root / "README.md"
    current_plan_path = repo_root / "ai/current-plan.md"
    governance_path = repo_root / "ai/governance.json"
    gitignore_path = repo_root / ".gitignore"

    summary = read_json(summary_path)
    repo_map = read_json(repo_map_path)
    governance = read_json(governance_path)
    agents_text = read_text(agents_path)
    readme_text = read_text(readme_path)
    plan_text = read_text(current_plan_path)
    gitignore_text = read_text(gitignore_path)

    # Load multi-agent contract requirements from governance (single source of truth).
    required_agents_phrases: list[str] = governance.get("required_agents_phrases") or list(_FALLBACK_AGENTS_PHRASES)
    required_current_model_phrases: list[str] = governance.get("required_current_model_phrases") or list(_FALLBACK_CURRENT_MODEL_PHRASES)

    agents_frontier = find_section(agents_text, "Next evolution frontier")
    agents_model = find_section(agents_text, "Current model")
    readme_guide = find_section(readme_text, "AI operating guide")
    plan_state = detect_plan_state(plan_text)
    summary_frontier = summary.get("next_frontier", "")
    repo_map_frontier = repo_map.get("next-frontier", "")
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

    frontier_aligned = summary_frontier == repo_map_frontier
    add_check("frontier-alignment", frontier_aligned, "summary next_frontier matches repo-map next-frontier")
    if not frontier_aligned:
        if is_stale_summary(summary_frontier, repo_map_frontier, plan_state):
            issues.append(
                {
                    "type": "stale_summary",
                    "file": "ai/health-check.summary.json",
                    "message": (
                        "ai/health-check.summary.json is stale relative to ai/repo-map.json. "
                        f"Regenerate with: {REGENERATE_COMMAND}"
                    ),
                }
            )
        else:
            issues.append(
                {
                    "type": "frontier_mismatch",
                    "file": "ai/repo-map.json",
                    "message": "ai/health-check.summary.json and ai/repo-map.json disagree about the next frontier.",
                }
            )

    agents_mentions_plan = "ai/current-plan.md" in agents_frontier
    add_check("agents-plan-reference", agents_mentions_plan, "AGENTS next frontier section references ai/current-plan.md when needed")
    if not agents_mentions_plan and summary_frontier != NO_ACTIVE_FRONTIER:
        issues.append(
            {
                "type": "agents_frontier_missing_plan_reference",
                "file": "AGENTS.md",
                "message": "AGENTS next frontier should point to ai/current-plan.md while a technical frontier is active.",
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

    governance_cycle_outputs = governance.get("required_cycle_outputs", [])
    governance_ok = isinstance(governance_cycle_outputs, list) and "AGENTS.md" in governance_cycle_outputs
    add_check("governance-cycle-outputs", governance_ok, "governance required cycle outputs are present")
    if not governance_ok:
        issues.append(
            {
                "type": "governance_cycle_outputs_invalid",
                "file": "ai/governance.json",
                "message": "governance required_cycle_outputs is not in the expected shape.",
            }
        )

    multi_agent_governance = governance.get("multi_agent_repo") is True
    add_check("governance-multi-agent", multi_agent_governance, "governance declares the repo as multi-agent")
    if not multi_agent_governance:
        issues.append(
            {
                "type": "governance_multi_agent_missing",
                "file": "ai/governance.json",
                "message": "governance.json must declare multi_agent_repo=true.",
            }
        )

    agents_multi_agent_heading = "## Multi-agent rules" in agents_text
    add_check("agents-multi-agent-heading", agents_multi_agent_heading, "AGENTS contains the Multi-agent rules section")
    if not agents_multi_agent_heading:
        issues.append(
            {
                "type": "agents_multi_agent_heading_missing",
                "file": "AGENTS.md",
                "message": "AGENTS.md must preserve the Multi-agent rules section.",
            }
        )

    missing_phrases = [phrase for phrase in required_agents_phrases if phrase not in agents_text]
    add_check("agents-multi-agent-phrases", len(missing_phrases) == 0, "AGENTS preserves mandatory multi-agent contract phrases")
    for phrase in missing_phrases:
        issues.append(
            {
                "type": "agents_multi_agent_phrase_missing",
                "file": "AGENTS.md",
                "message": f"AGENTS.md is missing required multi-agent phrase: {phrase}",
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

    if summary_frontier == NO_ACTIVE_FRONTIER:
        plan_closed = plan_state in {"completed", "deferred"}
        agents_deferred = "deferred" in agents_frontier.lower() or "no new technical frontier" in agents_frontier.lower()
        add_check("closed-cycle-plan-state", plan_closed, f"current plan state is {plan_state}")
        add_check("closed-cycle-agents", agents_deferred, "AGENTS expresses that the next technical plan is deferred")
        if not plan_closed:
            issues.append(
                {
                    "type": "closed_cycle_plan_not_closed",
                    "file": "ai/current-plan.md",
                    "message": "Summary says no active frontier, but ai/current-plan.md still looks active.",
                }
            )
        if not agents_deferred:
            issues.append(
                {
                    "type": "closed_cycle_agents_not_deferred",
                    "file": "AGENTS.md",
                    "message": "Summary says no active frontier, but AGENTS does not clearly defer the next technical plan.",
                }
            )
    else:
        plan_active = plan_state == "active"
        add_check("active-cycle-plan-state", plan_active, f"current plan state is {plan_state}")
        if not plan_active:
            issues.append(
                {
                    "type": "active_frontier_plan_not_active",
                    "file": "ai/current-plan.md",
                    "message": "A technical frontier is active, but ai/current-plan.md does not look active.",
                }
            )

    missing_model_phrases = [phrase for phrase in required_current_model_phrases if phrase not in agents_model]
    add_check(
        "agents-current-model-detail",
        len(missing_model_phrases) == 0,
        "AGENTS current model records all required governance-enforced detail phrases",
    )
    for phrase in missing_model_phrases:
        warnings.append(
            {
                "type": "agents_current_model_missing_detail",
                "file": "AGENTS.md",
                "message": f"AGENTS current model is missing required detail phrase: {phrase}",
            }
        )

    result_summary = {
        "ok": len(issues) == 0,
        "issue_count": len(issues),
        "warning_count": len(warnings),
        "plan_state": plan_state,
        "health_ok": health_ok,
        "frontier": {
            "summary": summary_frontier,
            "repo_map": repo_map_frontier,
        },
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
