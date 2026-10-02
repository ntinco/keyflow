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
- Workstation provisioning, maintenance and backup sync (package updates, cache cleanup, env refresh, VPN clients, FreeFileSync/rsync) belong to `workstation-ops`, not here. `platforms/*/tools/` holds only what keyflow runtime or validation uses.
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

- `hotkeys.db` is the only source. Use `python3 ai/hotkey_sync.py` edit commands; they validate changes and regenerate platform artifacts. Never edit generated catalogs directly.
- Hotstrings: use `--add-hotstring`, `--set-hotstring` or `--remove-hotstring`. Resolve any reported trigger conflicts. Mark a catalog reviewed only after its content is human-confirmed.
- SAP tcode hotstrings: use `sap-transaction-catalog` for tcode triggers or `sap-transaction-shortcuts` for aliases. Store the lowercase tcode without `/n`; the adapters add `/n` and preserve case. Other SAP commands and SAP hotkeys retain their existing normalization.
- SAP tcode hotkeys use `sap-tcode:<code>` and need no per-hotkey runtime implementation.
- Other portable hotkeys need a Windows action and a matching `Actions.<id>` in `platforms/macos/hammerspoon/actions.lua`; keep reusable Windows logic in a registered automation service.
- Add pure-logic tests for branching behavior. Record only checks requiring real applications or user observation in `ai/current-plan.md`.
- Computed `hs_*` hotstrings additionally need Windows behavior in the catalog action and an entry in `SPECIAL_BEHAVIORS` in `hotstrings.lua`.

## Review recipe

Structural validators prove wiring, not runtime behavior. For runtime changes and requested reviews, inspect relevant timing and input erasure, dispatch/scope/focus, platform parity, paths/geometry, and failure handling; record findings with file:line. Turn reproducible risks into tests or validators where practical, and keep remaining real-app checks in `ai/current-plan.md`.

## Active work state

`ai/current-plan.md` is optional. Keep it only while a multi-step technical frontier or pending human runtime verification genuinely needs durable continuation state. When that frontier is closed, delete the file; Git is the history.

## Completion

- Run `python3 ai/health_check.py` (short report; `--json` or `--pretty` for the full JSON).
- Run `python3 ai/hotkey_sync.py --check` when catalog/generated ownership is relevant; health validation also performs this drift check.
- Run `python3 -m unittest discover -s ai/tests` when tooling or tested runtime logic changes.
- Run relevant static/syntax checks and `ai/run_smoke.py` when runtime wiring changes and the environment supports them.
- On Windows, `platforms/windows/tools/selftest.ahk` produces runtime evidence for hotstrings and window geometry; extend it when a Windows behavior can be checked without real apps.
- Never claim a check or runtime behavior that was not executed or observed.

<!-- workspace-contract sha256:5d1301a146fd -->
## Workspace contract

Precedence, highest first:

1. The human's explicit instruction in the session. Name the rule it overrides; a lasting change is written into the file that owns the rule.
2. This contract, for anything that crosses repositories: routing, data class, autonomy.
3. The rest of the repository's `ai/governance.md`, for anything inside it.
4. `ai/repo-map.json`: it locates and runs things and sets no rule.
5. Skills and templates, always optional.

When a text and a validator disagree, the failing validator is the current truth: fix the rule or the code, never ignore it.

| Repo | Holds | Data class |
|---|---|---|
| `ntinco-os` | personal operating system: state, plans, time, finance, durable context | private-personal |
| `abap-box` | ABAP/SAP technical memory: knowledge, cheatsheets, skills, SAP utilities | private-technical |
| `abap-craft` | ABAP Craft, the public ABAP articles site | public |
| `gen-box` | generic reusable tools and agent skills | private-technical |
| `keyflow` | hotkeys, hotstrings and daily desktop automation (Windows/macOS) | public |
| `workstation-ops` | workstation operations | private-technical |

Content only moves to a repository of the same or a more private class, with one exception below.
`ntinco-os` alone holds private-personal data; approved adapters carry only what an authorized task needs.
Client or employer confidential data belongs in none of them.

Routing between repositories:

- Generic tool or file converter -> `gen-box`; other repositories run it from `~/gh/gen-box/tools/` and never copy it.
- ABAP/SAP knowledge -> `abap-box`; to `abap-craft` only anonymized and with explicit human approval.
- Hotkey, hotstring or daily desktop automation -> `keyflow`.
- Installation, provisioning or machine maintenance -> `workstation-ops`; Claude Code user config -> `gen-box/claude/`;
  OpenClaw config and usage -> `gen-box/openclaw/`.
- Personal fact, plan, time or finance -> `ntinco-os`.
- When a task belongs to another repository, say so and work there; never build a local substitute.

Architecture:

- Each repository is a bounded context: its declared authorities own truth; agents, UIs and runtimes are adapters,
  never authorities.
- State-changing requests from a bot, container or other untrusted runtime cross a trusted capability boundary that
  revalidates input, provenance and authorization. Untrusted input or model output never grants authority.
- Prefer narrow opt-in capabilities and deterministic tools. Privileged asynchronous work that crosses from an
  untrusted runtime into a trusted one uses `request -> trusted worker -> result`; normal repository edits by local
  agents follow the repository's write routing. Add no global database, event bus, workflow engine or duplicate schema
  without a reproducible failure or repeated friction that justifies it.

Autonomy:

- Without asking: read, edit, run validators and commit on the task branch.
- Ask first: push, open a pull request, or change a repository other than the task's.
- Only on explicit human order: merge or push to `main`; delete tags, stashes, untracked files or remote data;
  rewrite published history (rebase, amend, force push). Standing order: after each completed merge, delete its branch
  locally and remotely if present, remove its worktree, and report blockers.

Parallel work: one branch or worktree per task (`git worktree add ../<repo>-<task> -b <task>`). Never stage, commit,
stash, reset or revert changes you did not make; if the tree holds foreign changes, use a new worktree.

Commands: write `python3` in commands and docs. Validators that need a specific OS or application (AutoHotkey,
Hammerspoon, PowerShell, SAP) go in `ai/repo-map.json` -> `platform_validators` and never run in CI on another platform.
Environments: macOS and Linux (CI, cloud sessions); Windows is out of scope until the human reopens it.
Hooks and validators execute repository code: run them only on branches the human or their agents wrote, and review an
outside contribution in CI or a disposable environment first.
<!-- /workspace-contract -->
