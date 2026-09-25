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

1. `python ai/hotkey_sync.py --add-hotstring PROFILE TRIGGER VALUE [--immediate]` (or `--set-hotstring` / `--remove-hotstring`). Trigger conflicts (duplicates, immediate prefixes, ending-character clashes) are rejected.
2. After the human confirms: `python ai/hotkey_sync.py --mark-reviewed PROFILE`.

SAP transaction hotkey (portable):

1. `python ai/hotkey_sync.py --add-hotkey '{"id": "sap_gui_...", "file": "sap-gui", "type": "hotkey", "key": "!9", "windows_context": "...", "context_label": "sap-gui-session", "action": "sap-tcode:SE16N", "label": "...", "platform": ["windows", "macos"], "portability": "portable-intent"}'`.
2. No runtime code: both platforms dispatch `sap-tcode:` through their SAP adapter.

Other hotkey on both platforms:

1. Add the row with `--add-hotkey`; `action` holds the Windows AHK body, `platform` lists both, `portability` is `portable-intent`, `context_label` is `global` or a label present in `init.lua` `CONTEXT_APPS`.
2. Implement `Actions.<id>` in `platforms/macos/hammerspoon/actions.lua`; `health_check` fails while it is missing.
3. Put reusable Windows logic in a registered service under `platforms/windows/library/automation/`, not inline in `action`.
4. Add pure logic tests to `ai/tests/` when the change has branching logic that can run without the real apps.
5. Record the runtime checks the human must perform in `ai/current-plan.md`.

Special hotstring with computed output (`hs_*`): add the row with `--add-hotkey` (type `hotstring`, options `:*:` for immediate), implement Windows behavior in `action`, and add the id to `SPECIAL_BEHAVIORS` in `hotstrings.lua`.

## Active work state

`ai/current-plan.md` is optional. Keep it only while a multi-step technical frontier or pending human runtime verification genuinely needs durable continuation state. When that frontier is closed, delete the file; Git is the history.

## Completion

- Run `python ai/health_check.py --pretty`.
- Run `python ai/hotkey_sync.py --check` when catalog/generated ownership is relevant; health validation also performs this drift check.
- Run `python -m unittest discover -s ai/tests` when tooling or tested runtime logic changes.
- Run relevant static/syntax checks and `ai/run_smoke.py` when runtime wiring changes and the environment supports them.
- Never claim a check or runtime behavior that was not executed or observed.
