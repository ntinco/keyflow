# Runtime Execution Observability Plan

Status: active

## Intent

Add a small AI-first observability layer so agents can prove what actually ran in runtime smoke validation, instead of inferring execution only from guide consistency or incidental local artifacts.

## Why this frontier exists

- The current guide layer and validators are healthy, but they mostly validate contracts and handoff quality.
- A real runtime execution can still be ambiguous when `ahk_out.txt` is empty or absent.
- We already observed a useful side effect in `hotkey-usage.json`, but that is indirect and domain-specific, not a deliberate execution record.

## Success criteria

- A runtime smoke run leaves behind a small machine-readable artifact under `ai/`.
- The artifact captures at least:
  - executed command
  - timestamp
  - success/failure outcome
  - basic stdout/stderr or output-file reference
- Agents can review runtime execution status without guessing from unrelated local files.
- The guide layer explains when this artifact is authoritative and when human verification is still required.

## Workstreams

### 1. Define the runtime run artifact

- Create a minimal artifact contract under `ai/` for runtime smoke evidence.
- Keep it compact and operational, not historical transcript storage.

Definition of done:

- There is one clear machine-readable place to inspect the last runtime smoke result.

### 2. Add a small runner or recorder

- Implement a lightweight script that runs or records the AutoHotkey smoke command and writes the artifact.
- Prefer deterministic fields over verbose logging.

Definition of done:

- Another agent can trigger the smoke path and inspect the artifact immediately after.

### 3. Align reviewer and guide tooling

- Update `AGENTS.md`, `ai/repo-map.json`, and reviewer logic only as needed so the artifact becomes part of the normal execution audit path.
- Keep `README.md` minimal unless the runtime artifact affects onboarding.

Definition of done:

- The execution audit path is visible to the next agent without reading this chat.

### 4. Verify the flow

- Run health and review checks again.
- If safe in the current environment, run the runtime recorder once to prove the artifact shape.

Definition of done:

- The repo can distinguish “guide layer is healthy” from “runtime smoke actually ran”.

## Ordered execution

1. Define the artifact contract.
2. Implement the recorder.
3. Wire it into guide/reviewer flow.
4. Regenerate guide artifacts and verify.

## Non-goals

- Do not build full telemetry or long-lived execution history.
- Do not change SAP session behavior.
- Do not convert local-only runtime data into versioned business data.

## Current active frontier

The next best move is to add explicit runtime execution observability, starting with a machine-readable smoke-run artifact under `ai/`.
