# Agent prompts

Canonical prompt scaffold for dual-role work in `keyflow` and similar AI-first repos. Preserve this file as the reusable operating model; do not replace it with only a short instruction.

## 1. Short instruction

`Read AGENTS.md and execute ai/current-plan.md. If ai/current-plan.md is deferred or absent, report that and stop.`

## 2. Planner role

Use [planner-prompt.md](planner-prompt.md) when a new technical frontier should be identified or a new plan should be written.

## 3. Architect role

Use [architect-prompt.md](architect-prompt.md) for frontier review and governance alignment work.

## 4. Executor role

Use [executor-prompt.md](executor-prompt.md) for implementation and validation work.

## Bootstrap a new AI-first repo

`Create the AI operating layer for a new repo: AGENTS.md for workflow and rules, README.md for architecture and onboarding, and an ai/ layer with repo-map.json, health_check.py, review_check.py, health-check.summary.json, current-plan.md, governance.json, and the minimal machine-readable contracts needed for architect/executor continuity.`

## Rebuild the guide layer

`Rebuild the operating guide so AGENTS.md is operational, README.md is architectural, and ai/ holds machine-readable state, governance, navigation, validation, and reviewer tooling. Preserve explicit architect/executor handoff language and leave one clear frontier.`

## Mental model

- `AGENTS.md`: operational contract
- `README.md`: architecture and onboarding
- `ai/`: machine-readable state, governance, review, and continuity
- Architect/executor: optional roles; one AI may perform both when that is clearer
- AI maintains code; humans own intent, explicitly human-owned contracts, and runtime acceptance

## Rule of thumb

If you want simple execution, say `Read AGENTS.md and execute ai/current-plan.md`.
If you want normal execution, say `continue` or `execute`.
If you want a critique or handoff audit, say `review`.

## Review current repo

`Run python ai/health_check.py --pretty --summary and python ai/review_check.py --pretty --summary, then compare AGENTS.md, README.md, ai/repo-map.json, ai/governance.json, ai/current-plan.md, and ai/health-check.summary.json before proposing changes.`
