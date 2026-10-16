# Governance

keyflow is a human-owned, AI-operated personal automation runtime.

## Ownership

Humans own intent and desired behavior; runtime acceptance and any observation that needs the real Windows/macOS environment; credentials and local-only state; material irreversible decisions; and the content of `platforms/shared/data/hotkeys.db` and `ai/catalog-review.json`.

AI maintains the rest inside existing runtime boundaries: routing, implementation, generated artifacts, validation and this governance.

## Invariants

- `hotkeys.db` is the single human-managed hotkey and hotstring source. Generated artifacts are never an authority: do not edit them by hand, and regenerate them in the same change as their source contract.
- Edit `hotkeys.db` only for the specific change the human requested, and only through `ai/hotkey_sync.py` edit commands, never raw SQL.
- Run `--mark-reviewed` (`ai/catalog-review.json`) only after the human confirmed that catalog's current content.
- Local-only secrets and state (repo-map `local_only`) are never committed, and never modified unless explicitly requested.
- Runtime evidence outranks documentation; repository evidence outranks conversation memory. Structural validators prove wiring, not runtime behavior: never claim a check that was not executed or Windows/macOS behavior that was not observed.
- Workstation provisioning, maintenance and backup sync belong to `workstation-ops`; `platforms/*/tools/` holds only what keyflow runtime or validation uses.
- Provider-specific agent personas or prompt machinery are not repository architecture.
- Runtime code must not depend on Git metadata.
- Do not reintroduce removed services, dependencies, tracking or features without new evidence that they add value.
- Make the smallest complete change; no aesthetic refactors; comment only non-obvious constraints, rejected alternatives or traps.

## Procedures

- Before a catalog change (hotkey, hotstring, SAP tcode, computed `hs_*`) or a runtime change or review (Windows, macOS, timing/focus/input erasure), follow its repo-map `routing.procedures` entry.
- `ai/current-plan.md` exists only while a multi-step frontier or pending human runtime verification needs continuation state. Record there the checks that need real applications or human observation; delete it when the frontier closes.

## Completion

Run the repo-map `validators`, plus the `platform_validators` of each platform whose runtime wiring changed where the environment supports them. Report a validator that could not run as not run.
