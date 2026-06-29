# Agent prompts

Strong reusable prompts for multi-agent work in `keyflow` and similar AI-first repos.

## Primary execution prompt

`Read AGENTS.md first and treat it as the operational contract. This repo is permanently multi-agent and AI-first, so do not weaken handoff language, remove multi-agent guidance, or rewrite the guide layer as if only one AI will touch it. Run python ai/health_check.py --pretty --summary before changes and follow the mandatory workflow in AGENTS.md exactly. Respect ai/governance.json, human-owned contracts, and ai/current-plan.md when a frontier is active. After changes, regenerate the health-check artifacts, run python ai/review_check.py --pretty --summary when reviewing or closing a cycle, and update the guide layer if behavior, routing, governance, or next frontier changed.`

## Primary review prompt

`Read AGENTS.md first, then run python ai/health_check.py --pretty --summary and python ai/review_check.py --pretty --summary. Review the repo as a multi-agent handoff surface, not only as runtime code. Validate that AGENTS.md, README.md, ai/repo-map.json, ai/governance.json, ai/current-plan.md, and ai/health-check.summary.json all agree on the current model and frontier before proposing or making changes.`

## Bootstrap a new AI-first repo

`Create an AI-first maintenance layer for this repo. I want AGENTS.md for workflow and rules, README.md for architecture and onboarding, and an ai/ layer with repo-map.json, health_check.py, review_check.py, health-check.summary.json, current-plan.md, governance.json, and any minimal machine-readable contracts needed for multi-agent continuity.`

## Rebuild the guide layer

`Rebuild the AI operating guide for this repo. Separate AGENTS.md as operational, README.md as architectural, and ai/ as machine-readable state, governance, navigation, validation, and reviewer tooling. Remove duplicated guidance, preserve explicit multi-agent handoff language, align human-owned contracts, and leave one clear frontier.`

## Open a new technical plan

`Read AGENTS.md, ai/repo-map.json, ai/governance.json, ai/health-check.summary.json, and ai/current-plan.md, then replace ai/current-plan.md only if a real runtime, contract, or workflow hotspot is evident from the repo. Do not invent a plan just to fill the file.`

## Mental model

- `AGENTS.md`: operational contract
- `README.md`: architecture and onboarding
- `ai/`: machine-readable state, governance, review, and continuity

## Rule of thumb

If you want execution, say `continue` or `execute`.

If you want a critique or handoff audit, say `review`.
