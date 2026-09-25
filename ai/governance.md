# Governance

## Identity

keyflow is a human-owned, AI-operated personal automation runtime. AI is the primary maintainer inside the repository boundaries; humans retain intent and runtime acceptance.

## Ownership

Humans own:

- intent and desired behavior;
- the content of human-managed contracts, `platforms/shared/data/hotkeys.db` and `ai/catalog-review.json` (AI may edit them only as described in Change recipes);
- runtime acceptance and observations that require access to the real Windows/macOS environment;
- credentials and other local-only state;
- material irreversible decisions.

AI operates:

- repository routing and implementation;
- refactoring and cross-platform maintenance;
- generated artifacts and drift correction;
- mechanical validation;
- governance maintenance;
- routine architectural evolution inside existing runtime boundaries.

## Evidence discipline

- Runtime evidence outranks documentation claims when behavior must be verified in a real environment.
- Repository evidence outranks prior conversation memory.
- Generated artifacts never outrank their source contracts.
- Do not claim Windows or macOS runtime behavior that was not actually observed when runtime validation is required.
- Do not create narrative status from memory alone.

## Boundaries

- Local-only secrets and state remain local and must not be committed or modified unless explicitly requested.
- Runtime code must not depend on Git metadata.
- Workstation provisioning, maintenance and backup sync (package updates, cache cleanup, env refresh, VPN clients, FreeFileSync/rsync) belong to `keyflow-station`, not here. `platforms/*/tools/` holds only what keyflow runtime or validation uses.
- Do not reintroduce removed services, dependencies, tracking, or features without new evidence that they add value.
- `platforms/shared/data/hotkeys.db` is the single human-managed hotkey source; generated catalogs/bindings are not alternative authorities.
- AI edits `hotkeys.db` only when the human requested that specific change, and only through `ai/hotkey_sync.py` edit commands (never raw SQL): they validate, roll back on failure and regenerate artifacts.
- `ai/catalog-review.json` stores a content hash per catalog; `health_check` flags a catalog whose content changed since review. Run `--mark-reviewed` only after the human confirmed that catalog's current content.
- Provider-specific agent personas or prompt machinery are not repository architecture.

## Code discipline

- Optimize for AI maintenance through explicit ownership, deterministic validation, and minimal code surface.
- Make the smallest complete change that resolves the task.
- Add comments only for non-obvious constraints, rejected alternatives, or traps that code cannot express clearly.
- Do not perform aesthetic refactors without maintenance or runtime value.
- When a source contract changes, update its generated artifacts in the same change.

## Change recipes

Hotstring (autocorrect, snippet, SAP command):

1. `python3 ai/hotkey_sync.py --add-hotstring PROFILE TRIGGER VALUE [--immediate]` (or `--set-hotstring` / `--remove-hotstring`). Trigger conflicts (duplicates, immediate prefixes, ending-character clashes) are rejected.
2. After the human confirms: `python3 ai/hotkey_sync.py --mark-reviewed PROFILE`.

SAP transaction hotkey (portable):

1. `python3 ai/hotkey_sync.py --add-hotkey '{"id": "sap_gui_...", "file": "sap-gui", "type": "hotkey", "key": "!9", "windows_context": "...", "context_label": "sap-gui-session", "action": "sap-tcode:SE16N", "label": "...", "platform": ["windows", "macos"], "portability": "portable-intent"}'`.
2. No runtime code: both platforms dispatch `sap-tcode:` through their SAP adapter.

Other hotkey on both platforms:

1. Add the row with `--add-hotkey`; `action` holds the Windows AHK body, `platform` lists both, `portability` is `portable-intent`, `context_label` is `global` or a label present in `init.lua` `CONTEXT_APPS`.
2. Implement `Actions.<id>` in `platforms/macos/hammerspoon/actions.lua`; `health_check` fails while it is missing.
3. Put reusable Windows logic in a registered service under `platforms/windows/library/automation/`, not inline in `action`.
4. Add pure logic tests to `ai/tests/` when the change has branching logic that can run without the real apps.
5. Record the runtime checks the human must perform in `ai/current-plan.md`.

Special hotstring with computed output (`hs_*`): add the row with `--add-hotkey` (type `hotstring`, options `:*:` for immediate), implement Windows behavior in `action`, and add the id to `SPECIAL_BEHAVIORS` in `hotstrings.lua`.

## Review recipe

Structural validators prove the pieces are wired; they do not prove behavior. Before completing any runtime change, and when the human asks for a review, check each risk below against the diff and record findings with file:line:

1. Overlap and timing: two triggers within a delay/timer window (clipboard restore, SAP run tokens, `hs.timer` callbacks); state a late callback reads.
2. Input erasure: who erases the trigger (AHK auto-erase unless `b0`; macOS `visibleCount`), and that nothing erases it twice; character vs byte counts.
3. Dispatch and scope: a key or hotstring must fire only in its context, and an inactive match must not swallow or hide another binding.
4. Focus and target: the action types into the intended field/window (SAP command field, Snipaste return target), including after an app switch.
5. Paths and quoting: spaces, non-ASCII and empty selections in paths passed to shells or apps.
6. Screen geometry: secondary monitors, taskbar/work area, maximized windows.
7. Platform parity: the same intent has the same steps on Windows and macOS, or the difference is recorded as a deferred gap.
8. Failure path: missing app, empty clipboard, timeout; the user's clipboard and text are left intact.

Turn every confirmed finding into a mechanical guard when feasible: a pure-logic test in `ai/tests/`, a `health_check` rule, or a `hotkey_sync` validation. Otherwise add the manual check to `ai/current-plan.md`.

## Active work state

`ai/current-plan.md` is optional. Keep it only while a multi-step technical frontier or pending human runtime verification genuinely needs durable continuation state. When that frontier is closed, delete the file; Git is the history.

## Completion

- Run `python3 ai/health_check.py` (short report; `--json` or `--pretty` for the full JSON).
- Run `python3 ai/hotkey_sync.py --check` when catalog/generated ownership is relevant; health validation also performs this drift check.
- Run `python3 -m unittest discover -s ai/tests` when tooling or tested runtime logic changes.
- Run relevant static/syntax checks and `ai/run_smoke.py` when runtime wiring changes and the environment supports them.
- On Windows, `platforms/windows/tools/selftest.ahk` produces runtime evidence for hotstrings and window geometry; extend it when a Windows behavior can be checked without real apps.
- Never claim a check or runtime behavior that was not executed or observed.

<!-- workspace-contract sha256:379df4eaa154 -->
## Workspace contract

Identical in the six repositories under `~/gh/`. The master copy is the one in
`gen-box/ai/governance.md`: edit only that one, then run `python3 tools/contract_sync.py ~/gh` from `gen-box`.
Two of the repositories are public, so this section never holds private detail.

| Repo | Holds | Data class |
|---|---|---|
| `ntinco-os` | personal operating system: state, plans, time, finance, durable context | private-personal |
| `abap-box` | ABAP/SAP technical memory: knowledge, cheatsheets, skills, SAP utilities | private-technical |
| `abap-craft` | ABAP Craft, the public ABAP articles site | public |
| `gen-box` | generic reusable tools and agent skills | private-technical |
| `keyflow` | hotkeys, hotstrings and daily desktop automation (Windows/macOS) | public |
| `keyflow-station` | workstation installation, maintenance and backup sync | private-technical |

Content only moves to a repository of the same or a more private class, with one exception below.
Private-personal content never leaves `ntinco-os`. Client or employer confidential data belongs in none of them.

Routing between repositories:

- Generic tool or file converter -> `gen-box`; other repositories run it from `~/gh/gen-box/tools/` and never copy it.
- ABAP/SAP knowledge -> `abap-box`; to `abap-craft` only anonymized and with explicit human approval.
- Hotkey, hotstring or daily desktop automation -> `keyflow`.
- Installation, provisioning or machine maintenance -> `keyflow-station`.
- Personal fact, plan, time or finance -> `ntinco-os`.
- When a task belongs to another repository, say so and work there; never build a local substitute.

Autonomy:

- Without asking: read, edit, run validators and commit on the task branch.
- Ask first: push, open a pull request, or change a repository other than the task's.
- Only on explicit human order: merge or push to `main`; delete branches, tags, stashes, untracked files or remote data;
  rewrite published history (rebase, amend, force push).

Parallel work: one branch or worktree per task (`git worktree add ../<repo>-<task> -b <task>`). Never stage, commit,
stash, reset or revert changes you did not make; if the tree holds foreign changes, use a new worktree.

Pending acceptance: what waits for the human (runtime checks, claims to confirm) lives in one place per repository,
declared in `ai/repo-map.json` -> `pending_acceptance`; that file may be absent while nothing is pending.

Commands: write `python3` in commands and docs. Validators that need a specific OS or application (AutoHotkey,
Hammerspoon, PowerShell, SAP) go in `ai/repo-map.json` -> `platform_validators` and never run in CI on another platform.
Enable the versioned hooks once per clone with `git config core.hooksPath .githooks`; the pre-commit hook runs the
health check. `CLAUDE.md` only imports `AGENTS.md`; it is never a second authority.
<!-- /workspace-contract -->
