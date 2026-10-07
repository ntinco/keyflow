# shared: agent-core/shared/workspace_contract.py sha256:45ea50c45e4d (edit it in agent-core, then run tools/contract_sync.py in agent-core)
"""Local workspace contract checks; the master copy is agent-core/shared/workspace_contract.py.

problems(root) lists what breaks the workspace contract in the repository at root, reading nothing outside it: the
contract block missing, duplicated or edited in place, the wiring the contract requires (pending_acceptance,
CLAUDE.md, pre-commit hook settings, the secret deny rules and secret_guard hook in .claude/settings.json) and the
cold-start token budget. Drift against agent-core (the contract master, the vendored files) is not checked here:
`tools/contract_sync.py ROOT --check` in agent-core owns it.
Run directly to print the problems of this repository; exits 1 when there are any. Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

BLOCK = re.compile(r"<!-- workspace-contract sha256:(\S+) -->\n(.*?)<!-- /workspace-contract -->", re.DOTALL)
CHECK = re.compile(r"^check=(?:\"\s*[^\"\s][^\"]*\"|'\s*[^'\s][^']*'|[^\s\"'#]\S*)", re.MULTILINE)
LOCAL = re.compile(r"^local=[\"']?([^\"'\s]+)", re.MULTILINE)
BOOT_FILES = ("AGENTS.md", "CLAUDE.md", "ai/governance.md", "ai/repo-map.json")
SETTINGS = ".claude/settings.json"
# The one provider-specific rule here: a clone without agent-core beside it (CI, a cloud session) must still fail
# when its secret protection is removed, so the expected values cannot live only in agent-core's tooling.
# Every repository denies these secret paths; it may add its own rules on top.
SECRET_DENY = tuple(f"{tool}({pattern})" for pattern in (
    "**/.env", "**/.env.*", "**/secrets.*", "**/*.pem", "**/*.key", "**/*.kdbx", "**/*.pfx", "**/*.p12",
    "**/*.ovpn", "**/*.sapc", "~/.ssh/**") for tool in ("Read", "Edit"))
# Lets the call through when agent-core is not beside the repository (a single-repository clone), since a
# PreToolUse hook that exits 2 blocks every Bash call.
SECRET_GUARD = 'f="$CLAUDE_PROJECT_DIR/../agent-core/tools/secret_guard.py"; [ ! -f "$f" ] || python3 "$f"'
SYNC = "run tools/contract_sync.py in agent-core"


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def last_assignment(conf: str, name: str) -> str:
    lines = [line for line in conf.splitlines() if line.startswith(f"{name}=")]
    return lines[-1] if lines else ""


def boot_tokens(root: Path) -> int:
    """Estimate of the tokens an agent reads at cold start, at about 4 characters per token."""
    return sum(len((root / rel).read_text(encoding="utf-8", errors="replace"))
               for rel in BOOT_FILES if (root / rel).is_file()) // 4


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.is_file() else ""


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def contract_problems(root: Path) -> list[str]:
    blocks = BLOCK.findall(read(root / "ai/governance.md"))
    if len(blocks) != 1:
        return [f"ai/governance.md needs one workspace contract block, found {len(blocks)}"]
    if digest(blocks[0][1]) != blocks[0][0]:
        return [f"workspace contract edited here: edit it in agent-core and {SYNC}"]
    return []


def settings_problems(root: Path) -> list[str]:
    """The secret deny rules and the secret_guard PreToolUse hook that every .claude/settings.json carries."""
    if not (root / SETTINGS).is_file():
        return [f"{SETTINGS} is missing"]
    try:
        settings = json.loads(read(root / SETTINGS))
    except json.JSONDecodeError as exc:
        return [f"{SETTINGS} is not valid JSON: {exc}"]
    if not isinstance(settings, dict):
        return [f"{SETTINGS} must hold a JSON object"]
    permissions = settings.get("permissions")
    deny = permissions.get("deny") if isinstance(permissions, dict) else None
    deny = deny if isinstance(deny, list) else []
    found = []
    if missing := [rule for rule in SECRET_DENY if rule not in deny]:
        found.append(f"{SETTINGS} permissions.deny lacks {', '.join(missing)}")
    hooks = settings.get("hooks")
    entries = hooks.get("PreToolUse") if isinstance(hooks, dict) else None
    wired = any(
        isinstance(entry, dict) and entry.get("matcher") == "Bash" and isinstance(entry.get("hooks"), list)
        and any(isinstance(hook, dict) and hook.get("type") == "command" and hook.get("command") == SECRET_GUARD
                for hook in entry["hooks"])
        for entry in (entries if isinstance(entries, list) else []))
    if not wired:
        found.append(f"{SETTINGS} hooks.PreToolUse must run secret_guard on Bash with the command {SECRET_GUARD}")
    return found


def problems(root: Path) -> list[str]:
    """Everything that breaks the workspace contract in the repository at root; empty when it holds."""
    repo_map = load_json(root / "ai/repo-map.json")
    found = contract_problems(root)
    pending = repo_map.get("pending_acceptance")
    if not isinstance(pending, str) or not pending.strip():
        found.append("ai/repo-map.json must name one pending_acceptance path")
    if read(root / "CLAUDE.md").strip() != "@AGENTS.md":
        found.append("CLAUDE.md must exist and contain only @AGENTS.md")
    found += settings_problems(root)
    conf = read(root / ".githooks/pre-commit.conf")
    # The hook sources the file, so the last assignment of each setting is the one that counts.
    if not CHECK.match(last_assignment(conf, "check")):
        found.append(".githooks/pre-commit.conf must set check=\"<health check command>\" for the shared hook")
    local = LOCAL.match(last_assignment(conf, "local"))
    if local and (not (root / local.group(1)).is_file() or not (root / local.group(1)).stat().st_mode & 0o111):
        found.append(f"{local.group(1)} is declared in .githooks/pre-commit.conf but is not an executable file")
    budget = repo_map.get("cold_start_token_budget")
    if not isinstance(budget, int) or budget <= 0:
        found.append("ai/repo-map.json must set cold_start_token_budget")
    elif (tokens := boot_tokens(root)) > budget:
        found.append(f"cold start reads ~{tokens} tokens, over the cold_start_token_budget of {budget}")
    return found


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    found = problems(root)
    for problem in found:
        print(f"FAIL {problem}")
    print(f"workspace contract: {len(found)} problem(s)")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
