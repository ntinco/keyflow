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
- `ai/current-plan.md`: active frontier, current implementation state, and pending actions

## Repo identity

This repository is permanently operated as a dual-role AI-first repo.

- The two supported roles are architect and executor.
- AI is the primary code maintainer. Humans own intent, explicitly human-owned contracts, and runtime acceptance.
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
9. Update `ai/current-plan.md` when implementation state or pending actions changed. Edit other guide files only when their owned contract changed.
10. In the final handoff, state which actions are still human-only and whether the current plan remains active, complete, or deferred.

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

- Optimize runtime code and guides for AI maintenance: machine-verifiable contracts, explicit ownership and routing, deterministic validation, then minimal code surface.
- Do not add tutorial structure, explanatory wrappers, or comments solely for human readability. Preserve human-facing text only where it supports intent, onboarding, or runtime verification.
- Replace stale status text; do not append history. `Current model` describes invariants of the present state, not a changelog of what changed.
- This applies to `ai/current-plan.md` too: it holds current implementation state and pending actions, never a narrated history of bugs found/fixed (that belongs in git commit messages and one-line code comments, not prose).
- Code comments: only write a comment when the code cannot explain itself — a non-obvious constraint, a rejected alternative, a trap someone would otherwise repeat. Never restate what a function/variable name already says.
- Review each guide owner affected by the change; do not edit unrelated guides merely to keep duplicated status aligned.
- Keep policy in `AGENTS.md`, not in `README.md` or `repo-map.json`.
- Keep routing in `ai/repo-map.json`, not in `README.md`.
- Objective counts (services, hotkeys, profile sizes) live in `ai/health-check.summary.json`; do not duplicate them as prose here — reference the file instead.

Handoff rule:

- Leave the repo so either role can resume safely from code plus guide files only.
- If technical execution is complete, say so explicitly and separate human-only pending work from technical pending work.
- If a next technical frontier is already clear, replace `ai/current-plan.md` in the same cycle.
- If only human-only work remains, keep those actions in `ai/current-plan.md`; use `Status: deferred` only when no execution or verification is currently actionable.
- Never collapse the repo narrative into an unstructured single-role workflow. Preserve explicit architect/executor handoff wording even when the repo is temporarily stable.

## Plan policy

Use one persistent plan location.

- `ai/current-plan.md` is the sole source for frontier, implementation state, and pending actions.
- `AGENTS.md` only points to the plan and must not repeat its status.
- Do not create root-level `plan*.md`, `next.md`, or duplicate plan files.
- Keep `ai/current-plan.md` present with one status: `in progress`, `complete`, or `deferred`.
- When superseded, replace its contents instead of appending history.

## Hard rules

- Never touch local-only files unless the user explicitly asks: `local-secrets.ini`, `local-startup.ini`, `rom.ini`, `storage.db`, `run-result.json`, `run-result-macos.json`, `platforms/shared/data/memory-vars.ini`, `platforms/shared/data/local-paths.ini`.
- Never reintroduce retired env fallbacks, retired workspace names, or references to removed guide paths.
- Never guess machine paths; use `*.example.*` only as shape references.
- Never depend on Git metadata at runtime.
- Never reintroduce a separate paste service without first proving it adds value over the existing launcher flow.
- Never reintroduce a separate credential-provider or session-launch dependency without first proving it adds value over the current manual flow.
- Never reintroduce hotkey usage tracking (service, free functions, or catalog columns) without a new justification.
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
| SAP public facade + GUI/ADT automation | `platforms/windows/library/automation/sap.ahk` |
| Service wiring + hotstring profiles | `platforms/windows/library/bootstrap.ahk` |
| Free utility functions | `platforms/windows/library/util.ahk` |
| Hotkey triggers (Windows) | `platforms/windows/hotkeys/` |
| macOS runtime (Hammerspoon) | `platforms/macos/hammerspoon/` |
| Human-managed hotkey catalog (shared) | `platforms/shared/data/hotkeys.db` |
| Shared local-only SAP comment signature | `platforms/shared/data/memory-vars.ini` |
| Shared local-only machine paths | `platforms/shared/data/local-paths.ini` |
| Hotkey artifact generation and drift check | `ai/hotkey_sync.py` |
| Windows-only versioned catalogs | `platforms/windows/data/*.json` |
| Catalog review state | `ai/catalog-review.json` |
| Governance contract | `ai/governance.json` |
| AI tooling and navigation | `ai/` |

## Current model

- One intentional global: `services` in `platforms/windows/keyflow.ahk`.
- `SapService` owns automation only inside active SAP GUI/NWBC and Eclipse/ADT contexts; no credential-backed session launch, no named session storage.
- `platforms/shared/data/hotkeys.db` is the single human-managed hotkey source for both the Windows AHK runtime and the macOS Hammerspoon runtime. Its `platform` array separates implementation from `portability` intent; generated artifacts (AHK, Markdown, Lua bindings) are checked for drift via `ai/hotkey_sync.py --check` inside `ai/health_check.py`.
- No hotkey usage tracking exists in the runtime; it was removed after serving its purpose during catalog reduction and is not to be reintroduced without a new justification.
- `ai/governance.json` declares AI as the primary code maintainer and bounds the human role to intent, explicitly human-owned contracts, and runtime acceptance.
- `ai/health_check.py` validates the AHK/macOS include chains, macOS binding ownership and non-blocking dispatch, service calls, catalogs, governance, routing, and runtime-local boundaries.
- `ai/review_check.py` is the reviewer-oriented audit for cycle closure, guide alignment, and architect/executor handoff quality; run it after any guide, plan, or governance change.

## Next evolution frontier

- Active plan and pending actions: `ai/current-plan.md`.

## Validation

- Code changes: verify the include chain from `platforms/windows/keyflow.ahk` through `bootstrap.ahk` (Windows) or `platforms/macos/hammerspoon/init.lua` (macOS).
- Service or hotkey changes: inspect the related JSON/DB contract first.
- Guide changes: keep `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health-check.summary.json` aligned.
- Never validate by writing to local secret files or runtime databases.
