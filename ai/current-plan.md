# AI Governance Hardening Plan

## Intent

Strengthen the repo's AI-first governance so multi-agent work depends less on prose memory and more on machine-visible contracts.

This replaces the prior catalog-governance plan, whose human-review contract is already in place and whose catalog entries have now been marked as verified.

## Success criteria

- Repo governance rules are represented by a small machine-readable artifact under `ai/`.
- `health_check.py` validates governance drift, not just runtime drift.
- Human-owned contract files and guide authority stay aligned without requiring chat history.
- If a human-owned contract changes state, the guide layer reflects that state in the same cycle.

## Workstreams

### 1. Add a machine-readable governance contract

- Create one compact artifact under `ai/` that declares:
  - guide authority
  - required cycle outputs
  - detailed plan location
  - human-owned contracts
  - machine-validated contracts
- Keep the file small and boring.

Definition of done:

- Another agent can discover repo governance structure from repo files alone.

Status:

- Completed in this cycle with `ai/governance.json`.

### 2. Validate governance drift automatically

- Extend `ai/health_check.py` so it validates the governance contract against:
  - actual guide files
  - actual plan location
  - actual human-owned contract files
- Detect stale catalog-review wording when a catalog is marked `verified`.

Definition of done:

- Governance drift becomes machine-visible before another agent builds on stale assumptions.

Status:

- Completed in this cycle through `health_check.py` validation of governance contract shape, referenced files, repo-map read order, and stale verified catalog notes.

### 3. Reconcile human review with guide state

- If catalog review is already marked verified, remove stale wording that still says review is pending.
- Keep `AGENTS.md`, `README.md`, and `ai/repo-map.json` aligned with the verified state.

Definition of done:

- Human state and guide state no longer contradict each other.

Status:

- Completed in this cycle by normalizing `ai/catalog-review.json` and aligning the guide layer with verified catalog state.

## Ordered execution

1. Add `ai/governance.json`.
2. Validate it from `health_check.py`.
3. Normalize verified catalog-review notes and guide wording.
4. Regenerate `ai/health-check.summary.json`.

## Explicit non-goals for this cycle

- Do not reopen runtime simplification work without new evidence.
- Do not split the repo into parallel `ai/` and `human/` trees.
- Do not create more persistent plan files.

## Current active frontier

AI governance hardening is complete for this cycle. There is no active technical frontier right now; open the next plan only when a real runtime, contract, or workflow hotspot appears.
