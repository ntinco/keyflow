"""Workspace contract check: shared block unedited, pending-acceptance place, CLAUDE.md pointer, hook."""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ai"))

import health_check as MODULE  # noqa: E402


class WorkspaceContractTests(unittest.TestCase):
    def copy_repo(self, tmp: str) -> Path:
        root = Path(tmp)
        for rel in ("ai/governance.md", "ai/repo-map.json", "CLAUDE.md", ".githooks/pre-commit"):
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / rel, root / rel)
        return root

    def test_repository_passes(self):
        self.assertEqual(MODULE.workspace_contract_problems(ROOT), [])

    def test_contract_edited_in_place_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.copy_repo(tmp)
            governance = root / "ai/governance.md"
            governance.write_text(governance.read_text(encoding="utf-8").replace("Ask first", "Never ask"), encoding="utf-8")
            self.assertEqual(MODULE.workspace_contract_problems(root),
                             ["workspace contract edited here: edit it in gen-box and run tools/contract_sync.py"])

    def test_contract_must_match_gen_box_master(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"WORKSPACE_ROOT": tmp}):
            root = self.copy_repo(str(Path(tmp) / "repo"))
            source = (root / "ai/governance.md").read_text(encoding="utf-8")
            master = Path(tmp) / "gen-box/ai/governance.md"
            master.parent.mkdir(parents=True)
            master.write_text(source, encoding="utf-8")
            self.assertEqual(MODULE.workspace_contract_problems(root), [])
            master.write_text(source.replace("Ask first", "Never ask"), encoding="utf-8")
            self.assertEqual(MODULE.workspace_contract_problems(root),
                             ["workspace contract differs from the gen-box master: run tools/contract_sync.py in gen-box"])
            master.write_text("no contract here\n", encoding="utf-8")
            self.assertEqual(MODULE.workspace_contract_problems(root),
                             [f"gen-box master {master} must hold exactly one workspace contract block"])

    def test_claude_md_must_only_import_agents(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self.copy_repo(tmp)
            (root / "CLAUDE.md").write_text("@AGENTS.md\nExtra rule.\n", encoding="utf-8")
            self.assertEqual(MODULE.workspace_contract_problems(root), ["CLAUDE.md must exist and contain only @AGENTS.md"])


if __name__ == "__main__":
    unittest.main()
