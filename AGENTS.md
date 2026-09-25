# AGENTS.md

Cold-start contract for keyflow.

1. Read `ai/governance.md`.
2. Read `ai/repo-map.json`.
3. Open only task-relevant runtime/contracts; read `ai/current-plan.md` only when the task touches the active frontier or needs continuation state.
4. Run the relevant validators before completion.
5. Runtime evidence and repository evidence outrank prior conversation memory.
6. Never modify local-only secrets/state unless explicitly requested.
7. Never claim Windows or macOS runtime behavior without actual runtime evidence when runtime validation is required.
8. The `Workspace contract` section at the end of `ai/governance.md` is binding: which repository a task belongs to, what needs the human's approval (push, merge, deletion), and one branch or worktree per task.
