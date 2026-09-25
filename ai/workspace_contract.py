# shared: gen-box/shared/workspace_contract.py sha256:fc17e810795e (edit it in gen-box, then run tools/contract_sync.py in gen-box)
"""Workspace contract checks shared by the six repositories; the master copy is gen-box/shared/workspace_contract.py.

problems(root) lists what breaks the workspace contract in the repository at root: the contract block or a file
vendored from gen-box edited in place or out of date, the wiring the contract requires (pending_acceptance,
CLAUDE.md, pre-commit hook settings) and the cold-start token budget. The gen-box checkout used as the
authority is root itself, WORKSPACE_ROOT/gen-box or the sibling directory; without one only the local checks run.
Run directly to print the problems of this repository; exits 1 when there are any. Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

BLOCK = re.compile(r"<!-- workspace-contract sha256:(\S+) -->\n(.*?)<!-- /workspace-contract -->", re.DOTALL)
CHECK = re.compile(r"^check=(?:\"\s*[^\"\s][^\"]*\"|'\s*[^'\s][^']*'|[^\s\"'#]\S*)", re.MULTILINE)
LOCAL = re.compile(r"^local=[\"']?([^\"'\s]+)", re.MULTILINE)
MARKER = re.compile(r"# shared: gen-box/(\S+) sha256:([0-9a-f]{12})\b[^\n]*\n")
SOURCES = (
    "shared/workspace_contract.py",
    "shared/test_workspace_contract.py",
    "shared/githooks/pre-commit",
)
BOOT_FILES = ("AGENTS.md", "CLAUDE.md", "ai/governance.md", "ai/repo-map.json")
SYNC = "run tools/contract_sync.py in gen-box"


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def vendor(text: str, source: str) -> str:
    """The copy of a gen-box file that other repositories commit: the source plus a marker after any shebang."""
    marker = f"# shared: gen-box/{source} sha256:{digest(text)} (edit it in gen-box, then {SYNC})\n"
    if text.startswith("#!"):
        first, _, rest = text.partition("\n")
        return f"{first}\n{marker}{rest}"
    return marker + text


def unvendor(text: str) -> tuple[str, str, str] | None:
    """(source, recorded digest, source text) of a vendored copy, or None when it carries no marker."""
    start = text.index("\n") + 1 if text.startswith("#!") and "\n" in text else 0
    match = MARKER.match(text, start)
    if not match:
        return None
    return match.group(1), match.group(2), text[:start] + text[match.end():]


def last_assignment(conf: str, name: str) -> str:
    lines = [line for line in conf.splitlines() if line.startswith(f"{name}=")]
    return lines[-1] if lines else ""


def boot_tokens(root: Path) -> int:
    """Estimate of the tokens an agent reads at cold start, at about 4 characters per token."""
    return sum(len((root / rel).read_text(encoding="utf-8", errors="replace"))
               for rel in BOOT_FILES if (root / rel).is_file()) // 4


def gen_box(root: Path) -> Path | None:
    if (root / SOURCES[0]).is_file():
        return root
    candidate = Path(os.environ.get("WORKSPACE_ROOT") or root.resolve().parent) / "gen-box"
    # An existing checkout is the authority even when broken, so its missing files are reported, not skipped.
    return candidate if candidate.is_dir() else None


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.is_file() else ""


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def contract_problems(root: Path, master: Path | None) -> list[str]:
    blocks = BLOCK.findall(read(root / "ai/governance.md"))
    if len(blocks) != 1:
        return [f"ai/governance.md needs one workspace contract block, found {len(blocks)}"]
    if digest(blocks[0][1]) != blocks[0][0]:
        return [f"workspace contract edited here: edit it in gen-box and {SYNC}"]
    if master is None or master == root:
        return []
    source = master / "ai/governance.md"
    master_blocks = BLOCK.findall(read(source))
    if len(master_blocks) != 1:
        return [f"gen-box master {source} must hold exactly one workspace contract block"]
    if master_blocks[0] != blocks[0]:
        return [f"workspace contract differs from the gen-box master: {SYNC}"]
    return []


def vendored_problems(root: Path, shared: dict, master: Path | None) -> list[str]:
    problems: list[str] = []
    for target, source in sorted(shared.items()):
        path = root / target
        if source not in SOURCES or Path(target).is_absolute() or ".." in Path(target).parts:
            problems.append(f"shared_files maps {target!r} to {source!r}: use a path inside the repository and a gen-box/shared source")
            continue
        if not path.is_file():
            problems.append(f"{target} is missing: {SYNC}")
            continue
        parsed = unvendor(read(path))
        if parsed is None or parsed[0] != source:
            problems.append(f"{target} is not a vendored copy of gen-box/{source}: {SYNC}")
        elif digest(parsed[2]) != parsed[1]:
            problems.append(f"{target} edited here: edit gen-box/{source} and {SYNC}")
        elif parsed[2].startswith("#!") and not path.stat().st_mode & 0o111:
            problems.append(f"{target} must be executable: {SYNC}")
        elif master is not None and not (master / source).is_file():
            problems.append(f"gen-box/{source} is missing from {master}: update that checkout or drop the mapping")
        elif master is not None and read(master / source) != parsed[2]:
            problems.append(f"{target} differs from gen-box/{source}: {SYNC}")
    missing = sorted(set(SOURCES) - set(shared.values()))
    problems += [f"ai/repo-map.json shared_files lacks gen-box/{source}" for source in missing]
    # Where a copy lives matters: git runs .githooks/pre-commit, unittest discovers test_*.py, and the
    # health check imports the module beside it.
    targets = {source: {t for t, s in shared.items() if s == source} for source in SOURCES}
    if targets["shared/githooks/pre-commit"] and ".githooks/pre-commit" not in targets["shared/githooks/pre-commit"]:
        problems.append("shared_files must map gen-box/shared/githooks/pre-commit to .githooks/pre-commit")
    if targets["shared/test_workspace_contract.py"] and not any(
            Path(t).name.startswith("test_") for t in targets["shared/test_workspace_contract.py"]):
        problems.append("shared_files must map gen-box/shared/test_workspace_contract.py to a test_*.py file")
    own = Path(__file__).resolve()
    if own.is_relative_to(root.resolve()) and own.relative_to(root.resolve()).as_posix() not in targets[SOURCES[0]]:
        problems.append(f"shared_files must map gen-box/{SOURCES[0]} to {own.relative_to(root.resolve()).as_posix()}, "
                        "the copy the health check imports")
    return problems


def problems(root: Path) -> list[str]:
    """Everything that breaks the workspace contract in the repository at root; empty when it holds."""
    master = gen_box(root)
    repo_map = load_json(root / "ai/repo-map.json")
    found = contract_problems(root, master)
    pending = repo_map.get("pending_acceptance")
    if not isinstance(pending, str) or not pending.strip():
        found.append("ai/repo-map.json must name one pending_acceptance path")
    if read(root / "CLAUDE.md").strip() != "@AGENTS.md":
        found.append("CLAUDE.md must exist and contain only @AGENTS.md")
    conf = read(root / ".githooks/pre-commit.conf")
    # The hook sources the file, so the last assignment of each setting is the one that counts.
    if not CHECK.match(last_assignment(conf, "check")):
        found.append(".githooks/pre-commit.conf must set check=\"<health check command>\" for the shared hook")
    local = LOCAL.match(last_assignment(conf, "local"))
    if local and (not (root / local.group(1)).is_file() or not (root / local.group(1)).stat().st_mode & 0o111):
        found.append(f"{local.group(1)} is declared in .githooks/pre-commit.conf but is not an executable file")
    shared = repo_map.get("shared_files")
    if not isinstance(shared, dict) or not shared:
        found.append("ai/repo-map.json must map shared_files (vendored path -> gen-box source)")
    else:
        found += vendored_problems(root, shared, master)
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
