#!/usr/bin/env python
"""Runtime smoke recorder for keyflow.

Runs the AutoHotkey entry point with a short timeout and writes a machine-readable
result to ai/run-result.json so agents can distinguish "guide layer healthy" from
"runtime smoke actually ran without parse errors".

Usage:
    python ai/run_smoke.py
    python ai/run_smoke.py --repo-root .
    python ai/run_smoke.py --timeout 5 --pretty

Outcome values in the artifact:
    launched      — Process started and did not exit within timeout.
                    Expected behaviour for a daemon (no immediate parse errors).
    error         — Process exited with nonzero exit code within timeout.
                    Indicates a parse or startup failure.
    exited_clean  — Process exited with code 0 within timeout.
                    Unexpected but not a failure.
    not_run       — AHK executable or entry point not found; smoke was skipped.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

OUTPUT_FILE = "ai/run-result.json"
MACOS_OUTPUT_FILE = "ai/run-result-macos.json"
DEFAULT_TIMEOUT = 4  # seconds — enough to catch immediate parse errors


def run_smoke_macos(repo_root: Path) -> dict[str, object]:
    """Syntax-check the Hammerspoon Lua files via `luac -p` (parse-only, no
    execution). Does not require the Hammerspoon app to be running, unlike
    `hs -c`, which blocks waiting for the app's IPC socket."""
    hammerspoon_dir = repo_root / "platforms/macos/hammerspoon"
    init_file = hammerspoon_dir / "init.lua"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if not init_file.exists():
        return {
            "tool": "ai/run_smoke.py",
            "platform": "macos",
            "command": "luac -p <hammerspoon lua files>",
            "timestamp_utc": timestamp,
            "outcome": "not_run",
            "exit_code": None,
            "stderr_lines": [],
            "notes": f"macOS entry point not found at {init_file.as_posix()}. Smoke skipped.",
        }

    lua_files = sorted(hammerspoon_dir.rglob("*.lua"))
    stderr_lines: list[str] = []
    exit_code = 0
    for lua_file in lua_files:
        proc = subprocess.run(
            ["luac", "-p", str(lua_file)],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            exit_code = proc.returncode
            stderr_lines.extend(line for line in proc.stderr.splitlines() if line.strip())

    if not lua_files:
        outcome = "not_run"
        notes = "No .lua files found under platforms/macos/hammerspoon."
    elif exit_code == 0:
        outcome = "exited_clean"
        notes = f"luac -p syntax check passed for {len(lua_files)} Lua file(s)."
    else:
        outcome = "error"
        notes = "luac -p reported a syntax error — see stderr_lines."

    return {
        "tool": "ai/run_smoke.py",
        "platform": "macos",
        "command": f"luac -p {' '.join(str(f.relative_to(repo_root)) for f in lua_files)}",
        "timestamp_utc": timestamp,
        "outcome": outcome,
        "exit_code": exit_code if exit_code != 0 else 0,
        "stderr_lines": stderr_lines,
        "notes": notes,
    }


def run_smoke(repo_root: Path, timeout: int) -> dict[str, object]:
    ahk_exe = repo_root / "platforms/windows/tools/exe/AutoHotkey64.exe"
    entry = repo_root / "platforms/windows/keyflow.ahk"

    command = f"{ahk_exe.as_posix()} /ErrorStdOut=CP65001 {entry.as_posix()}"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    if not ahk_exe.exists():
        return {
            "tool": "ai/run_smoke.py",
            "command": command,
            "timestamp_utc": timestamp,
            "outcome": "not_run",
            "exit_code": None,
            "stderr_lines": [],
            "notes": f"AHK executable not found at {ahk_exe.as_posix()}. Smoke skipped.",
        }

    if not entry.exists():
        return {
            "tool": "ai/run_smoke.py",
            "command": command,
            "timestamp_utc": timestamp,
            "outcome": "not_run",
            "exit_code": None,
            "stderr_lines": [],
            "notes": f"Entry point not found at {entry.as_posix()}. Smoke skipped.",
        }

    proc = subprocess.Popen(
        [str(ahk_exe), "/ErrorStdOut=CP65001", str(entry)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=str(repo_root),
    )

    try:
        stdout_bytes, stderr_bytes = proc.communicate(timeout=timeout)
        exit_code = proc.returncode
        stderr_lines = [
            line for line in stderr_bytes.decode("utf-8", errors="replace").splitlines() if line.strip()
        ]
        if exit_code == 0:
            outcome = "exited_clean"
            notes = "Process exited with code 0 within timeout."
        else:
            outcome = "error"
            notes = f"Process exited with code {exit_code} within timeout — parse or startup failure."
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        exit_code = None
        stderr_lines = []
        outcome = "launched"
        notes = (
            f"Process launched and did not exit within {timeout}s timeout — "
            "no immediate parse errors detected. Manual verification required for full runtime behaviour."
        )

    return {
        "tool": "ai/run_smoke.py",
        "command": command,
        "timestamp_utc": timestamp,
        "outcome": outcome,
        "exit_code": exit_code,
        "stderr_lines": stderr_lines,
        "notes": notes,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Runtime smoke recorder for keyflow.")
    parser.add_argument("--repo-root", default=".", help="Repository root.")
    parser.add_argument(
        "--platform",
        choices=["windows", "macos"],
        default="windows",
        help="Which runtime to smoke-test (default: windows).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Seconds to wait before treating process as launched (default: {DEFAULT_TIMEOUT}). Windows only.",
    )
    parser.add_argument("--output", default=None, help="Path for the run-result artifact.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    indent = 2 if args.pretty else None

    if args.platform == "macos":
        result = run_smoke_macos(repo_root)
        output_default = MACOS_OUTPUT_FILE
    else:
        result = run_smoke(repo_root, args.timeout)
        output_default = OUTPUT_FILE

    output_path_str = args.output or output_default
    out_path = Path(output_path_str)
    if not out_path.is_absolute():
        out_path = (repo_root / output_path_str).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")

    sys.stdout.write(json.dumps(result, indent=indent, ensure_ascii=False) + "\n")

    return 0 if result["outcome"] in {"launched", "exited_clean"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
