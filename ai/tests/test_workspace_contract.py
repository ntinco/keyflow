# shared: gen-box/shared/test_workspace_contract.py sha256:6a7c10c79066 (edit it in gen-box, then run tools/contract_sync.py in gen-box)
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
FIXTURE_FILES = MODULE.BOOT_FILES + (".githooks/pre-commit.conf", *SHARED)


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

    def test_claude_md_must_only_import_agents(self):
        (self.root / "CLAUDE.md").write_text("@AGENTS.md\nExtra rule.\n", encoding="utf-8")
        self.assertEqual(MODULE.problems(self.root), ["CLAUDE.md must exist and contain only @AGENTS.md"])

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
