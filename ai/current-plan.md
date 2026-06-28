# AI-First Catalog Governance Plan

## Intent

Turn the remaining human-only catalog freshness work into an explicit AI-first workflow so another agent can see what is pending, what was reviewed, and what should happen next without reading chat history.

This replaces the prior runtime-simplification plan, which is already complete.

## Success criteria

- A new agent can identify which catalogs still require human review from repo files alone.
- Human review status is tracked as durable repo state, not as transient chat context.
- `health_check.py` validates the catalog-review contract without pretending to validate business content freshness.
- Runtime code stays unchanged unless catalog governance work reveals a real contract issue.

## Workstreams

### 1. Add a machine-readable catalog review contract

- Create a small AI-first artifact for catalog review state, for example under `ai/`.
- Track at least:
  - catalog id
  - source file
  - review status
  - last human verification date
  - optional notes
- Keep the shape minimal and stable.

Definition of done:

- Another agent can tell which catalogs are pending vs verified without opening the chat.

Status:

- Completed in this cycle with `ai/catalog-review.json`.

### 2. Teach the health check about review state

- Extend `ai/health_check.py` to validate that the catalog review artifact:
  - exists
  - references real versioned catalog files
  - uses known status values
  - stays aligned with the active catalog set
- Do not mark content as fresh automatically.
- Only validate the contract and completeness of review metadata.

Definition of done:

- Missing or malformed catalog review state becomes machine-visible.

Status:

- Completed in this cycle through `health_check.py` validation of file existence, active catalog alignment, known status values, and verification-date rules.

### 3. Clarify human-review workflow in the guide layer

- Update `AGENTS.md`, `README.md`, and `ai/repo-map.json` so they explain:
  - where catalog review state lives
  - what a human must verify
  - what an agent may update automatically
- Keep the wording short and present-state only.

Definition of done:

- Human-only tasks are explicit, narrow, and easy to resume.

Status:

- Completed in this cycle by updating `AGENTS.md`, `README.md`, and `ai/repo-map.json` to point to `ai/catalog-review.json`.

### 4. Separate verified catalogs from future technical hotspots

- Once catalog review state exists, keep technical planning separate from human review.
- If catalog work exposes a real runtime or schema issue, open a new technical plan after that fact is verified.
- Do not mix speculative runtime cleanup into this plan.

Definition of done:

- The repo has one clear frontier: catalog governance now, new runtime work only if evidence appears.

Status:

- In effect. The remaining work is human verification, and technical replanning is explicitly conditional on real evidence.

## Ordered execution

1. Create the catalog review artifact.
2. Wire it into `health_check.py`.
3. Update the guide layer to point to it.
4. Regenerate `ai/health-check.summary.json`.
5. Only then ask for or record human verification outcomes.

## Explicit non-goals for this cycle

- Do not change catalog content yet.
- Do not re-open runtime simplification work without new evidence.
- Do not create extra plan files outside `ai/current-plan.md`.
- Do not move human review notes into chat-only state.

## Current active frontier

The next best move is human review: update `ai/catalog-review.json` with verification outcomes, starting with `sap-transaction-catalog` and `autocorrect`. Open a new technical plan only if that review reveals a real contract or runtime issue.
