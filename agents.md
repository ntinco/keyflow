# AGENTS.md

AutoHotkey v2 Windows automation workspace. Operational repo, optimized for AI maintenance by multiple agents.

## Guide authority

Use this order when files disagree:

1. `ai/health-check.summary.json`
2. `ai/repo-map.json`
3. `AGENTS.md`
4. `README.md`

Roles are fixed:

- `ai/health-check.summary.json`: objective current state
- `ai/repo-map.json`: navigation and ownership map
- `AGENTS.md`: workflow, rules, handoff, plan policy
- `README.md`: architecture and onboarding
- `ai/governance.json`: machine-readable governance contract

## Repo identity

This repository is permanently operated as a multi-agent AI-first repo.

- Do not rewrite the guide layer as if only one AI will touch the repo.
- Do not remove multi-agent language just because the current task looks single-agent.
- If a guide edit weakens handoff clarity for the next agent, treat that as governance drift and fix it in the same cycle.

## Mandatory workflow

1. Read `ai/repo-map.json`.
2. Run `python ai/health_check.py --pretty --summary`.
3. If you are reviewing another agent's execution or closing a major cycle, run `python ai/review_check.py --pretty --summary`.
4. Reconcile any status claim against:
   - `platforms/windows/keyflow.ahk`
   - `platforms/windows/library/bootstrap.ahk`
   - `ai/health-check.summary.json`
5. Edit the smallest responsible file set.
6. Run `python ai/health_check.py --pretty --output ai/health-check.json --output-summary ai/health-check.summary.json`.
7. If runtime wiring changed, smoke-test with `platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001 platforms/windows/keyflow.ahk`.
8. If you changed guides, plan state, or cycle status, rerun `python ai/review_check.py --pretty --summary`.
9. Close the cycle by updating the guide layer if routing, behavior, constraints, or next frontier changed.
10. In the final handoff, state which actions are still human-only and whether a new technical plan should be created now or deferred.

If step 2 or 5 returns `ok: false`, fix the reported issues before doing anything else.

## Multi-agent rules

This repo is shared by multiple AIs. Write for the next agent, not for your own memory.

Claim discipline:

- Do not write narrative claims from memory alone.
- If a global exists, say it exists.
- If a helper exists but is optional, say it is optional.
- If an example config section exists, the guide must acknowledge it.
- If something cannot be verified from the repo, label it as human verification.

Guide discipline:

- Replace stale status text; do not append history.
- If one guide file changes meaningfully, review the others in the same cycle.
- Keep policy in `AGENTS.md`, not in `README.md` or `repo-map.json`.
- Keep routing in `ai/repo-map.json`, not in `README.md`.

Handoff rule:

- Leave the repo so another agent can resume safely from code plus guide files only.
- If technical execution is complete, say so explicitly and separate human-only pending work from technical pending work.
- If a next technical frontier is already clear, replace `ai/current-plan.md` with the new plan in the same cycle.
- If only human-only work remains, do not invent a new technical plan just to fill the file; say that plan creation is deferred until a real technical frontier appears.
- Never collapse the repo narrative into a single-agent workflow. Preserve explicit multi-agent handoff wording even when the repo is temporarily stable.

## Plan policy

Use only one persistent plan location at a time.

- Default: keep the active frontier in `AGENTS.md` under `Next evolution frontier`.
- If a detailed multi-step plan must survive across turns or agents, store it in `ai/current-plan.md`.
- Do not create root-level `plan*.md`, `next.md`, or duplicate plan files.
- When the plan is completed or superseded, fold the outcome back into `AGENTS.md` and delete or fully replace `ai/current-plan.md`.
- A completed plan must leave behind two things: a short human-action list in `AGENTS.md` and a clear decision about whether the next technical plan is ready now or deferred.

## Hard rules

- Never touch local-only files unless the user explicitly asks: `local-secrets.ini`, `local-paths.ini`, `local-startup.ini`, `memory-vars.ini`, `rom.ini`, `storage.db`, `hotkey-usage.json`.
- Never reintroduce retired env fallbacks, retired workspace names, or references to removed guide paths.
- Never merge `sap-session.ahk` into `sap.ahk` or vice versa.
- Never guess machine paths; use `*.example.*` only as shape references.
- Never depend on Git metadata at runtime.
- Never reintroduce a separate paste service without first proving it adds value over the existing launcher flow.
- Never leave dead routes in `ai/repo-map.json`.

## Naming contract

| Scope | Rule |
|---|---|
| Files, classes, services, helpers, groups, targets | English-first |
| New runtime APIs | intent-first, short, explicit |
| External labels | Keep as-is |
| SAP session names | Use business names like `pluz dev`, `pluz qas`, `pluz prd` |

Preferred vocabulary: `session` `entry` `provider` `catalog` `window` `workspace` `target` `profile` `group` `context` `command` `run` `action` `path` `secret` `constant`

Avoid mixing: `session` with old login/logon terms, `window` with desktop/gui synonyms, `run` with open/execute/start unless the distinction is real.

## File boundaries

| Concern | Owner |
|---|---|
| SAP session resolution + KeePass provider | `platforms/windows/library/automation/sap-session.ahk` |
| SAP public facade + GUI/ADT automation | `platforms/windows/library/automation/sap.ahk` |
| Service wiring + hotstring profiles | `platforms/windows/library/bootstrap.ahk` |
| Free utility functions | `platforms/windows/library/util.ahk` |
| Hotkey tracking infrastructure | `platforms/windows/hotkeys/hotkey-tracking.ahk` |
| Hotkey triggers | `platforms/windows/hotkeys/` |
| Startup launchers | `platforms/windows/tools/startup/` |
| Versioned catalogs | `platforms/windows/data/*.json` |
| Catalog review state | `ai/catalog-review.json` |
| Governance contract | `ai/governance.json` |
| AI tooling and navigation | `ai/` |

## Current model

- `ai_readiness` is currently `100/100`.
- One intentional global remains: `services` in `platforms/windows/keyflow.ahk`.
- The guide layer is now leaner by role: policy in `AGENTS.md`, architecture in `README.md`, routing in `ai/repo-map.json`, objective state in `ai/health-check.summary.json`.
- SAP ownership is now explicit by composition: `SapService` delegates session/login concerns to `SapSessionService` instead of inheriting them.
- `DynamicService` now exposes intent-first actions only; the raw action-chain runner is internal.
- `LauncherService` and `WindowGroupService` now use clearer intent/state naming; historical internal state fields were removed.
- Catalog counts are stable and the current catalog-review entries are marked `verified`.
- Catalog review contract lives in `ai/catalog-review.json`, and governance rules are now also represented in `ai/governance.json`.
- The runtime-local artifact contract is now fully normalized: `hotkey-usage.json` is consistently classified across `.gitignore`, `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health_check.py`.
- `ai/health_check.py` now enforces runtime-local boundary consistency via `validate_local_only_contract()`.
- `ai/health_check.py` and `ai/review_check.py` now make multi-agent governance drift machine-visible by enforcing required guide sections, phrases, frontier state, and reviewer handoff commands.
- `ai/review_check.py` is the reviewer-oriented audit for cycle closure, guide alignment, and multi-agent handoff quality.

## Next evolution frontier

- Execute `ai/current-plan.md`: make governance the single source of truth for multi-agent enforcement and remove stale-summary false positives from reviewer flow.
- Start with `ai/review_check.py` summary-staleness handling and duplicated required-phrase constants across validators.

## Validation

- Code changes: verify the include chain from `platforms/windows/keyflow.ahk` through `bootstrap.ahk`.
- Service or hotkey changes: inspect the related JSON or INI contract first.
- Guide changes: keep `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health-check.summary.json` aligned.
- Never validate by writing to local secret files or runtime databases.
