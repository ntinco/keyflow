# shared: gen-box/shared/test_workspace_contract.py sha256:51b6bebaab0c (edit it in gen-box, then run tools/contract_sync.py in gen-box)
"""Workspace contract check (gen-box/shared/workspace_contract.py) on this repository and on broken copies of it."""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "ai/repo-map.json").is_file())
SHARED = json.loads((ROOT / "ai/repo-map.json").read_text(encoding="utf-8"))["shared_files"]
_path = ROOT / next(target for target, source in SHARED.items() if source == "shared/workspace_contract.py")
_spec = importlib.util.spec_from_file_location("workspace_contract", _path)
MODULE = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MODULE)
_LOCAL = MODULE.LOCAL.findall((ROOT / ".githooks/pre-commit.conf").read_text(encoding="utf-8"))
FIXTURE_FILES = MODULE.BOOT_FILES + (".githooks/pre-commit.conf", MODULE.SETTINGS, *_LOCAL, *SHARED)


class WorkspaceContractTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.workspace = Path(tmp.name)
        patcher = mock.patch.dict(os.environ, {"WORKSPACE_ROOT": tmp.name})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.root = self.workspace / "repo"
        for rel in FIXTURE_FILES:
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / rel, self.root / rel)

    def make_gen_box(self) -> Path:
        """A gen-box beside the fixture whose sources match this repository's vendored copies."""
        master = self.workspace / "gen-box"
        for target, source in SHARED.items():
            (master / source).parent.mkdir(parents=True, exist_ok=True)
            (master / source).write_text(MODULE.unvendor((ROOT / target).read_text(encoding="utf-8"))[2], encoding="utf-8")
        (master / "ai").mkdir()
        shutil.copy(ROOT / "ai/governance.md", master / "ai/governance.md")
        return master

    def edit(self, path: Path, old: str, new: str) -> None:
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def test_repository_passes(self):
        self.assertEqual(MODULE.problems(ROOT), [])

    def test_copy_passes_against_gen_box(self):
        self.make_gen_box()
        self.assertEqual(MODULE.problems(self.root), [])

    def test_contract_edited_in_place_fails(self):
        self.edit(self.root / "ai/governance.md", "Ask first", "Never ask")
        self.assertEqual(MODULE.problems(self.root),
                         ["workspace contract edited here: edit it in gen-box and run tools/contract_sync.py in gen-box"])

    def test_contract_must_match_gen_box_master(self):
        master = self.make_gen_box() / "ai/governance.md"
        self.edit(master, "Ask first", "Never ask")
        self.assertEqual(MODULE.problems(self.root),
                         ["workspace contract differs from the gen-box master: run tools/contract_sync.py in gen-box"])
        master.write_text("no contract here\n", encoding="utf-8")
        self.assertEqual(MODULE.problems(self.root),
                         [f"gen-box master {master} must hold exactly one workspace contract block"])

    def test_a_gen_box_checkout_without_governance_fails(self):
        master = self.make_gen_box()
        (master / "ai/governance.md").unlink()
        self.assertEqual(MODULE.problems(self.root),
                         [f"gen-box master {master / 'ai/governance.md'} must hold exactly one workspace contract block"])

    def test_vendored_file_edited_in_place_fails(self):
        target, source = next(iter(sorted(SHARED.items())))
        with (self.root / target).open("a", encoding="utf-8") as handle:
            handle.write("# local edit\n")
        self.assertEqual(MODULE.problems(self.root),
                         [f"{target} edited here: edit gen-box/{source} and run tools/contract_sync.py in gen-box"])

    def test_vendored_file_must_match_gen_box(self):
        target, source = next(iter(sorted(SHARED.items())))
        with (self.make_gen_box() / source).open("a", encoding="utf-8") as handle:
            handle.write("# newer in gen-box\n")
        self.assertEqual(MODULE.problems(self.root),
                         [f"{target} differs from gen-box/{source}: run tools/contract_sync.py in gen-box"])

    def test_hook_config_must_set_a_check_command(self):
        conf = self.root / ".githooks/pre-commit.conf"
        for text in ('check=""\n', 'check="true"\ncheck=""\n'):
            conf.write_text(text, encoding="utf-8")
            self.assertEqual(MODULE.problems(self.root),
                             ['.githooks/pre-commit.conf must set check="<health check command>" for the shared hook'])

    def test_every_shared_source_is_required_without_gen_box(self):
        target = next(t for t, s in SHARED.items() if s == "shared/githooks/pre-commit")
        repo_map = self.root / "ai/repo-map.json"
        data = json.loads(repo_map.read_text(encoding="utf-8"))
        del data["shared_files"][target]
        repo_map.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(MODULE.problems(self.root),
                         ["ai/repo-map.json shared_files lacks gen-box/shared/githooks/pre-commit"])

    def test_source_missing_from_gen_box_fails(self):
        target, source = next(iter(sorted(SHARED.items())))
        master = self.make_gen_box()
        (master / source).unlink()
        self.assertEqual(MODULE.problems(self.root),
                         [f"gen-box/{source} is missing from {master}: update that checkout or drop the mapping"])

    def test_vendored_hook_must_stay_executable(self):
        target = next(t for t, s in SHARED.items() if s == "shared/githooks/pre-commit")
        (self.root / target).chmod(0o644)
        self.assertEqual(MODULE.problems(self.root),
                         [f"{target} must be executable: run tools/contract_sync.py in gen-box"])

    def test_mappings_stay_inside_the_repository(self):
        repo_map = self.root / "ai/repo-map.json"
        data = json.loads(repo_map.read_text(encoding="utf-8"))
        data["shared_files"]["../escape.py"] = "shared/workspace_contract.py"
        repo_map.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(MODULE.problems(self.root), [
            "shared_files maps '../escape.py' to 'shared/workspace_contract.py': "
            "use a path inside the repository and a gen-box/shared source"])

    def test_declared_local_hook_must_exist(self):
        with (self.root / ".githooks/pre-commit.conf").open("a", encoding="utf-8") as handle:
            handle.write('local=".githooks/missing.local"\n')
        self.assertEqual(MODULE.problems(self.root), [
            ".githooks/missing.local is declared in .githooks/pre-commit.conf but is not an executable file"])

    def test_the_hook_must_be_vendored_where_git_runs_it(self):
        target = next(t for t, s in SHARED.items() if s == "shared/githooks/pre-commit")
        repo_map = self.root / "ai/repo-map.json"
        data = json.loads(repo_map.read_text(encoding="utf-8"))
        del data["shared_files"][target]
        data["shared_files"]["unused-hook-copy"] = "shared/githooks/pre-commit"
        repo_map.write_text(json.dumps(data), encoding="utf-8")
        shutil.copy(self.root / target, self.root / "unused-hook-copy")
        self.assertEqual(MODULE.problems(self.root),
                         ["shared_files must map gen-box/shared/githooks/pre-commit to .githooks/pre-commit"])

    def test_claude_md_must_only_import_agents(self):
        (self.root / "CLAUDE.md").write_text("@AGENTS.md\nExtra rule.\n", encoding="utf-8")
        self.assertEqual(MODULE.problems(self.root), ["CLAUDE.md must exist and contain only @AGENTS.md"])

    def edit_settings(self, change) -> None:
        path = self.root / MODULE.SETTINGS
        data = json.loads(path.read_text(encoding="utf-8"))
        change(data)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_settings_file_is_required(self):
        (self.root / MODULE.SETTINGS).unlink()
        self.assertEqual(MODULE.problems(self.root), [".claude/settings.json is missing"])

    def test_settings_must_deny_every_secret_path(self):
        self.edit_settings(lambda data: data["permissions"]["deny"].remove("Edit(~/.ssh/**)"))
        self.assertEqual(MODULE.problems(self.root), [".claude/settings.json permissions.deny lacks Edit(~/.ssh/**)"])
        self.edit_settings(lambda data: data.pop("permissions"))
        self.assertEqual(MODULE.problems(self.root),
                         [".claude/settings.json permissions.deny lacks " + ", ".join(MODULE.SECRET_DENY)])

    def test_settings_may_deny_more_paths(self):
        self.edit_settings(lambda data: data["permissions"]["deny"].append("Read(local/**)"))
        self.assertEqual(MODULE.problems(self.root), [])

    def test_settings_must_wire_secret_guard(self):
        expected = [".claude/settings.json hooks.PreToolUse must run secret_guard on Bash with the command "
                    + MODULE.SECRET_GUARD]
        variants = (
            lambda data: data.pop("hooks"),
            lambda data: data["hooks"]["PreToolUse"][0].update(matcher="Edit"),
            # The unguarded command exits 2 without gen-box beside the repository, blocking every Bash call.
            lambda data: data["hooks"]["PreToolUse"][0]["hooks"][0].update(
                command='python3 "$CLAUDE_PROJECT_DIR/../gen-box/tools/secret_guard.py"'),
        )
        original = (self.root / MODULE.SETTINGS).read_text(encoding="utf-8")
        for change in variants:
            (self.root / MODULE.SETTINGS).write_text(original, encoding="utf-8")
            self.edit_settings(change)
            self.assertEqual(MODULE.problems(self.root), expected)

    def test_cold_start_budget(self):
        repo_map = self.root / "ai/repo-map.json"
        data = json.loads(repo_map.read_text(encoding="utf-8"))
        data["cold_start_token_budget"] = 1
        repo_map.write_text(json.dumps(data), encoding="utf-8")
        tokens = MODULE.boot_tokens(self.root)
        self.assertEqual(MODULE.problems(self.root),
                         [f"cold start reads ~{tokens} tokens, over the cold_start_token_budget of 1"])

    def test_vendor_round_trip(self):
        for text in ("#!/bin/sh\necho hi\n", '"""Doc."""\nX = 1\n'):
            copy = MODULE.vendor(text, "shared/x")
            self.assertEqual(MODULE.unvendor(copy), ("shared/x", MODULE.digest(text), text))
        self.assertIsNone(MODULE.unvendor("#!/bin/sh\necho hi\n"))


if __name__ == "__main__":
    unittest.main()
