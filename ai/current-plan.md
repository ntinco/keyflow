# Governance Single-Source and Reviewer Robustness Plan

Status: active

## Intent

Improve the AI tooling layer so reviewers can trust failures quickly and the multi-agent contract is defined in one place instead of being duplicated across scripts.

## Why this frontier exists

- The repo is operationally healthy, but `ai/review_check.py` can emit misleading failures when `ai/health-check.summary.json` is stale relative to `ai/repo-map.json` or `ai/current-plan.md`.
- The multi-agent contract already exists in `ai/governance.json`, but `ai/health_check.py` and `ai/review_check.py` still duplicate required phrases and sections as hardcoded constants.
- The next gain is better tooling determinism and lower review friction, not runtime refactoring.

## Success criteria

- `ai/review_check.py` distinguishes `summary stale` from real contract failure.
- `ai/governance.json` becomes the single enforced source for required multi-agent sections and phrases.
- `ai/health_check.py` and `ai/review_check.py` load governance requirements instead of maintaining parallel hardcoded lists.
- A reviewer can tell in one command whether the repo is wrong or just needs artifact regeneration.

## Workstreams

### 1. Detect stale generated state explicitly

- Teach `ai/review_check.py` to detect when:
  - `ai/repo-map.json` and `ai/current-plan.md` indicate an active frontier
  - but `ai/health-check.summary.json` still reflects the previous state
- Report that as a dedicated stale-summary issue instead of misclassifying the repo as logically inconsistent.

Definition of done:

- Reviewer output separates stale artifacts from real governance errors.

### 2. Remove duplicated governance truth

- Refactor `ai/health_check.py` and `ai/review_check.py` to read:
  - `required_agents_sections`
  - `required_agents_phrases`
  - any related multi-agent enforcement keys
  from `ai/governance.json`.
- Keep only minimal fallbacks in code if absolutely necessary.

Definition of done:

- Governance changes require editing `ai/governance.json`, not multiple scripts.

### 3. Reconcile guide and prompt language

- Update `AGENTS.md`, `ai/agent-prompts.md`, and `README.md` only if wording needs to reflect the new stale-summary behavior or governance loading model.
- Preserve the current multi-agent contract shape unless the machine-readable source changes it.

Definition of done:

- The guide layer explains the tooling behavior without duplicating policy.

### 4. Regenerate and verify artifacts

- Regenerate `ai/health-check.summary.json` and `ai/health-check.json`.
- Re-run `python ai/health_check.py --pretty --summary`.
- Re-run `python ai/review_check.py --pretty --summary`.

Definition of done:

- Both commands end cleanly and reviewer output is more precise than before.

## Ordered execution

1. Fix stale-summary detection in `ai/review_check.py`.
2. Refactor validators to load governance requirements from `ai/governance.json`.
3. Update guide wording only if needed.
4. Regenerate artifacts and close the cycle.

## Non-goals

- Do not reopen runtime API or AutoHotkey service refactors.
- Do not change local-only file contracts.
- Do not introduce a new docs layer.

## Current active frontier

The next best move is to make reviewer failures more trustworthy and to remove duplicated governance truth from the validators, starting with stale-summary handling in `ai/review_check.py`.
