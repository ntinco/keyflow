# AGENTS.md

AutoHotkey v2 Windows automation workspace. Operational repo, optimized for AI maintenance through two roles: architect and executor.

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

This repository is permanently operated as a dual-role AI-first repo.

- The two supported roles are architect and executor.
- A single AI may perform both roles when the task is small, clear, or already covered by `ai/current-plan.md`.
- If a guide edit weakens handoff clarity between roles, treat that as governance drift and fix it in the same cycle.

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
7. If runtime wiring changed, smoke-test with `platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001 platforms/windows/keyflow.ahk` and record the result with `python ai/run_smoke.py`.
8. If you changed guides, plan state, or cycle status, rerun `python ai/review_check.py --pretty --summary`.
9. Close the cycle by updating the guide layer if routing, behavior, constraints, or next frontier changed.
10. In the final handoff, state which actions are still human-only and whether a new technical plan should be created now or deferred.

If step 2 or 5 returns `ok: false`, fix the reported issues before doing anything else.

## Role rules

Write for the next handoff, not for your own memory.

Agent role model:

- The architect role owns frontier selection, governance alignment, architectural review, and success criteria.
- The executor role owns scoped implementation, validation, generated artifacts, and final handoff.
- Role split is optional. The invariant is that every cycle leaves enough guide and machine-readable state for either role to continue safely.

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

- Leave the repo so either role can resume safely from code plus guide files only.
- If technical execution is complete, say so explicitly and separate human-only pending work from technical pending work.
- If a next technical frontier is already clear, replace `ai/current-plan.md` with the new plan in the same cycle.
- If only human-only work remains, do not invent a new technical plan just to fill the file; say that plan creation is deferred until a real technical frontier appears.
- Never collapse the repo narrative into an unstructured single-role workflow. Preserve explicit architect/executor handoff wording even when the repo is temporarily stable.

## Plan policy

Use only one persistent plan location at a time.

- Default: keep the active frontier in `AGENTS.md` under `Next evolution frontier`.
- If a detailed multi-step plan must survive across turns or agents, store it in `ai/current-plan.md`.
- Do not create root-level `plan*.md`, `next.md`, or duplicate plan files.
- When the plan is completed or superseded, fold the outcome back into `AGENTS.md` and delete or fully replace `ai/current-plan.md`.
- A completed plan must leave behind two things: a short human-action list in `AGENTS.md` and a clear decision about whether the next technical plan is ready now or deferred.

## Hard rules

- Never touch local-only files unless the user explicitly asks: `local-secrets.ini`, `local-paths.ini`, `local-startup.ini`, `memory-vars.ini`, `rom.ini`, `storage.db`, `hotkey-usage.json`, `run-result.json`.
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

Preferred vocabulary: `session` `entry` `provider` `catalog` `window` `workspace` `target` `profile` `group` `context` `command` `run` `action` `path` `secret` `constant` `frontier` `cycle`

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
| Human-managed hotkey catalog | `platforms/windows/data/hotkeys.db` |
| Hotkey artifact generation and drift check | `ai/hotkey_sync.py` |
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
- `LauncherService` and `WindowGroupService` now use clearer intent/state naming; historical internal state fields were removed.
- Catalog counts are stable and the current catalog-review entries are marked `verified`.
- Catalog review contract lives in `ai/catalog-review.json`, and governance rules are now also represented in `ai/governance.json`.
- The runtime-local artifact contract is now fully normalized: `hotkey-usage.json` is consistently classified across `.gitignore`, `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health_check.py`.
- `ai/health_check.py` now enforces runtime-local boundary consistency via `validate_local_only_contract()`.
- `ai/health_check.py` and `ai/review_check.py` now make role-governance drift machine-visible by enforcing required guide sections, phrases, frontier state, and reviewer handoff commands.
- `ai/review_check.py` is the reviewer-oriented audit for cycle closure, guide alignment, and architect/executor handoff quality.
- `ai/review_check.py` now distinguishes stale generated artifacts (`stale_summary` with regeneration command) from real contract failures, eliminating reviewer false positives caused by un-regenerated summaries.
- `ai/health_check.py` owns the enforced baseline for required role sections and phrases; `ai/governance.json` mirrors that baseline as the machine-readable contract and must match it.
- `ai/review_check.py` reads required phrases from `ai/governance.json` for reviewer audits, using fallback constants only if governance is unavailable or malformed.
- `ai/governance.json` now declares `required_current_model_phrases`; `ai/review_check.py` reads this list for reviewer audits, and `ai/health_check.py` validates the governance value against `REQUIRED_CURRENT_MODEL_PHRASES`.
- `ai/prompts/agent-prompts.md` is now included in `ai/repo-map.json` `read-order`, making it visible to agents on first read.
- `ai/run_smoke.py` records runtime smoke execution into `ai/run-result.json` so agents can distinguish "guide layer healthy" from "runtime smoke actually ran without parse errors".
- `hotkeys.db` is the only human-managed hotkey source; generated AHK and hotkey reference files are checked for drift by `ai/hotkey_sync.py --check` through `ai/health_check.py`.
- The Windows runtime now exposes 10 services and 54 hotkeys; generic editor, Office, communication, video, and low-use global routes have been retired.
- `hotkeys.db` separates implementation `platform` from `portability`, so macOS candidates are explicit without pretending AHK actions are cross-platform.
- Temporary hotkey tracking uses context-qualified keys for new events, preventing cross-application usage collisions.

## Next evolution frontier

- The Windows reduction and portability-classification cycle is technically complete; `ai/current-plan.md` records the validated outcome.
- The stable runtime now contains 54 hotkeys, 6 hotstrings, 10 services, and no machine-detected orphaned code.
- Human-only work is normal Windows usage so context-qualified tracking evidence can accumulate.
- No further Windows reduction is currently justified; the macOS implementation plan is deferred until its native stack and first portable-intent slice are selected.

## Validation

- Code changes: verify the include chain from `platforms/windows/keyflow.ahk` through `bootstrap.ahk`.
- Service or hotkey changes: inspect the related JSON or INI contract first.
- Guide changes: keep `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health-check.summary.json` aligned.
- Never validate by writing to local secret files or runtime databases.
