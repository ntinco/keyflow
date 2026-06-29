# Agent prompts

Strong reusable prompts for dual-role work in `keyflow` and similar AI-first repos.

## Short instruction

`Read AGENTS.md and execute ai/current-plan.md. If ai/current-plan.md is deferred or absent, report that and stop.`

## Execute current repo

`Read AGENTS.md first and treat it as the operational contract. This repo is permanently dual-role and AI-first: architect selects or reviews the frontier, executor implements and validates it, and one AI may perform both roles when appropriate. Run python ai/health_check.py --pretty --summary before changes and follow the mandatory workflow in AGENTS.md exactly. Respect ai/governance.json, human-owned contracts, and ai/current-plan.md when a frontier is active. After changes, regenerate the health-check artifacts, run python ai/review_check.py --pretty --summary when reviewing or closing a cycle, and update the guide layer if behavior, routing, governance, or next frontier changed.`

## Review current repo

`Read AGENTS.md first, then run python ai/health_check.py --pretty --summary and python ai/review_check.py --pretty --summary. Review the repo as an architect/executor handoff surface, not only as runtime code. Validate that AGENTS.md, README.md, ai/repo-map.json, ai/governance.json, ai/current-plan.md, and ai/health-check.summary.json all agree on the current model and frontier before proposing or making changes.`

## Architect current repo

`Read AGENTS.md, ai/repo-map.json, ai/governance.json, ai/health-check.summary.json, and ai/current-plan.md. Act as the architect role: choose or refine the next frontier, keep governance and handoff rules truthful, and leave ai/current-plan.md executable by another AI. Do not change runtime code unless the architectural correction requires it.`

## Execute architect plan

`Read AGENTS.md and ai/current-plan.md. Act as the executor role: implement the active plan with the smallest responsible file set, run the required health and review checks, and update the guide layer before handoff. If the plan is complete, mark it complete and defer the next technical plan unless a real new frontier is evident.`

## Bootstrap a new AI-first repo

`Create an AI-first maintenance layer for this repo. I want AGENTS.md for workflow and rules, README.md for architecture and onboarding, and an ai/ layer with repo-map.json, health_check.py, review_check.py, health-check.summary.json, current-plan.md, governance.json, and any minimal machine-readable contracts needed for architect/executor continuity.`

## Rebuild the guide layer

`Rebuild the AI operating guide for this repo. Separate AGENTS.md as operational, README.md as architectural, and ai/ as machine-readable state, governance, navigation, validation, and reviewer tooling. Remove duplicated guidance, preserve explicit architect/executor handoff language, align human-owned contracts, and leave one clear frontier.`

## Open a new technical plan

`Read AGENTS.md, ai/repo-map.json, ai/governance.json, ai/health-check.summary.json, and ai/current-plan.md, then replace ai/current-plan.md only if a real runtime, contract, or workflow hotspot is evident from the repo. Do not invent a plan just to fill the file.`

## Mental model

- `AGENTS.md`: operational contract
- `README.md`: architecture and onboarding
- `ai/`: machine-readable state, governance, review, and continuity
- Architect/executor: optional roles for larger cycles; one AI may perform both when that is clearer

## Rule of thumb

If you want simple execution, say `Read AGENTS.md and execute ai/current-plan.md`.

If you want normal execution, say `continue` or `execute`.

If you want a critique or handoff audit, say `review`.
