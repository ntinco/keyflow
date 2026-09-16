# Governance

## Identity

keyflow is a human-owned, AI-operated personal automation runtime. AI is the primary maintainer inside the repository boundaries; humans retain intent and runtime acceptance.

## Ownership

Humans own:

- intent and desired behavior;
- deliberately human-managed contracts, including `platforms/shared/data/hotkeys.db` and `ai/catalog-review.json`;
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
- Provider-specific agent personas or prompt machinery are not repository architecture.

## Code discipline

- Optimize for AI maintenance through explicit ownership, deterministic validation, and minimal code surface.
- Make the smallest complete change that resolves the task.
- Add comments only for non-obvious constraints, rejected alternatives, or traps that code cannot express clearly.
- Do not perform aesthetic refactors without maintenance or runtime value.
- When a source contract changes, update its generated artifacts in the same change.

## Active work state

`ai/current-plan.md` is optional. Keep it only while a multi-step technical frontier or pending human runtime verification genuinely needs durable continuation state. When that frontier is closed, delete the file; Git is the history.

## Completion

- Run `python ai/health_check.py --pretty`.
- Run `python ai/hotkey_sync.py --check` when catalog/generated ownership is relevant; health validation also performs this drift check.
- Run relevant static/syntax checks and `ai/run_smoke.py` when runtime wiring changes and the environment supports them.
- Never claim a check or runtime behavior that was not executed or observed.
