"""Unit tests for AI tooling. Run: python -m unittest discover -s ai/tests"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

AI_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_DIR.parent
sys.path.insert(0, str(AI_DIR))

import health_check  # noqa: E402
import hotkey_sync  # noqa: E402


def _hotstring(trigger: str, options: str = "::", context: str = "") -> dict[str, object]:
    return {"id": f"hs_{trigger}", "type": "hotstring", "trigger": trigger, "options": options,
            "context_label": context, "active": True}


def _profile(entries: list[tuple[str, bool]], mode: str = "replace", context: str = "global") -> dict[str, object]:
    return {"id": f"profile-{mode}-{context}", "mode": mode, "context_label": context, "active": True,
            "entries": [{"trigger": trigger, "value": "x", "immediate": immediate} for trigger, immediate in entries]}


class HotstringConflictTests(unittest.TestCase):
    def test_current_catalog_has_no_conflicts(self) -> None:
        entries = hotkey_sync.load_db()
        profiles = hotkey_sync.load_hotstring_profiles()
        self.assertEqual(hotkey_sync.find_hotstring_conflicts(entries, profiles), [])

    def test_immediate_prefix_shadows_longer_trigger(self) -> None:
        issues = hotkey_sync.find_hotstring_conflicts([], [_profile([("swel", True), ("swels", False)])])
        self.assertEqual(len(issues), 1)
        self.assertIn("fires before", issues[0])

    def test_ending_character_competes_with_trigger(self) -> None:
        issues = hotkey_sync.find_hotstring_conflicts([_hotstring("sp")], [_profile([("sp,", True)])])
        self.assertEqual(len(issues), 1)
        self.assertIn("competes", issues[0])

    def test_duplicate_is_case_insensitive(self) -> None:
        issues = hotkey_sync.find_hotstring_conflicts([], [_profile([("Teh", False), ("teh", False)])])
        self.assertIn("duplicate", issues[0])

    def test_non_ending_prefix_is_allowed(self) -> None:
        self.assertEqual(hotkey_sync.find_hotstring_conflicts([], [_profile([("da", False), ("datos", False)])]), [])

    def test_disjoint_contexts_do_not_conflict(self) -> None:
        profiles = [_profile([("da", True)], context="sap-gui-session"), _profile([("dab", False)], context="other")]
        self.assertEqual(hotkey_sync.find_hotstring_conflicts([], profiles), [])

    def test_global_overlaps_every_context(self) -> None:
        profiles = [_profile([("da", True)]), _profile([("dab", False)], mode="sap-command", context="sap-gui-session")]
        self.assertEqual(len(hotkey_sync.find_hotstring_conflicts([], profiles)), 1)

    def test_sap_commands_never_fire_immediately(self) -> None:
        profiles = [_profile([("da", True), ("dab", False)], mode="sap-command", context="sap-gui-session")]
        self.assertEqual(hotkey_sync.find_hotstring_conflicts([], profiles), [])


class CatalogEditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "hotkeys.db"
        shutil.copyfile(hotkey_sync.DB_PATH, self.db)
        self.original_db_path = hotkey_sync.DB_PATH
        hotkey_sync.DB_PATH = self.db

    def tearDown(self) -> None:
        hotkey_sync.DB_PATH = self.original_db_path
        self.tmp.cleanup()

    def _triggers(self, profile_id: str) -> dict[str, dict[str, object]]:
        profiles = hotkey_sync.load_hotstring_profiles()
        profile = next(item for item in profiles if item["id"] == profile_id)
        return {str(entry["trigger"]): entry for entry in profile["entries"]}

    def test_add_set_remove_hotstring(self) -> None:
        hotkey_sync.add_hotstring("quick-snippets", "zzq,", "Prueba", True)
        self.assertTrue(self._triggers("quick-snippets")["zzq,"]["immediate"])
        hotkey_sync.set_hotstring("quick-snippets", "zzq,", "Otra", False)
        entry = self._triggers("quick-snippets")["zzq,"]
        self.assertEqual((entry["value"], entry["immediate"]), ("Otra", False))
        hotkey_sync.remove_hotstring("quick-snippets", "zzq,")
        self.assertNotIn("zzq,", self._triggers("quick-snippets"))

    def test_conflicting_edit_rolls_back(self) -> None:
        before = self.db.read_bytes()
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.add_hotstring("quick-snippets", "bd", "Buen", True)
        self.assertEqual(self.db.read_bytes(), before)

    def test_unknown_targets_are_rejected(self) -> None:
        before = self.db.read_bytes()
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.remove_hotstring("quick-snippets", "no-such-trigger")
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.add_hotstring("no-such-profile", "x", "y", False)
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.set_hotkey("no_such_id", "label", "x")
        self.assertEqual(self.db.read_bytes(), before)

    def test_invalid_hotkey_rolls_back(self) -> None:
        before = self.db.read_bytes()
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.add_hotkey('{"id": "bad", "file": "global", "type": "hotkey", "key": "F9", '
                                   '"action": "x", "label": "x", "platform": ["linux"]}')
        self.assertEqual(self.db.read_bytes(), before)


class HealthCheckHelperTests(unittest.TestCase):
    def test_hash_matches_between_tools(self) -> None:
        items = [{"trigger": "bd,", "value": "Buen día,", "immediate": True}]
        self.assertEqual(hotkey_sync.catalog_items_sha256(items), health_check.catalog_items_sha256(items))

    def test_lua_comments_cannot_satisfy_contracts(self) -> None:
        code = 'local a = "--keep" -- iina-cli\n--[[ block\nstill ]] local b = 1'
        stripped = health_check.strip_lua_comments(code)
        self.assertIn('"--keep"', stripped)
        self.assertNotIn("iina-cli", stripped)
        self.assertNotIn("block", stripped)
        self.assertIn("local b = 1", stripped)

    def test_unused_ahk_function_is_reported(self) -> None:
        text = "used() {\n}\nunused() {\n}\ncaller() {\n  used()\n}\n"
        tokens = Counter(token.lower() for token in health_check.re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", text))
        issues = health_check.scan_unused_ahk_functions({"x.ahk": {"text": text}}, tokens)
        self.assertEqual(sorted(str(issue["symbol"]) for issue in issues), ["caller", "unused"])


class MacosLogicTests(unittest.TestCase):
    def test_lua_pure_logic(self) -> None:
        lua = shutil.which("lua")
        if not lua:
            self.skipTest("lua interpreter not available")
        result = subprocess.run([lua, str(AI_DIR / "tests" / "macos_logic_test.lua")],
                                cwd=REPO_ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
