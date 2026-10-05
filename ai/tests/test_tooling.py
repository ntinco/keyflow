"""Unit tests for AI tooling. Run: python3 -m unittest discover -s ai/tests"""

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

    def test_end_chars_match_autohotkey_defaults(self) -> None:
        self.assertEqual(hotkey_sync.HOTSTRING_END_CHARS, set("-()[]{}':;\"/\\,.?! \t\r\n"))
        self.assertEqual(hotkey_sync.find_hotstring_conflicts([], [_profile([("sp", False), ("sp=", True)])]), [])

    def test_sap_commands_never_fire_immediately(self) -> None:
        profiles = [_profile([("da", True), ("dab", False)], mode="sap-command", context="sap-gui-session")]
        self.assertEqual(hotkey_sync.find_hotstring_conflicts([], profiles), [])


class NetNewsWireSummaryBindingTests(unittest.TestCase):
    BINDING_ID = "netnewswire_summary_current"

    def test_catalog_binding_is_macos_only(self) -> None:
        entries = hotkey_sync.load_db()
        entry = next(item for item in entries if item["id"] == self.BINDING_ID)
        self.assertEqual(
            (entry["type"], entry["key"], entry["context_label"], entry["platform"], entry["portability"],
             entry["label"], bool(entry["active"])),
            ("hotkey", "!#s", "netnewswire", ["macos"], "macos-only", "Summarize current NetNewsWire article", True),
        )
        self.assertFalse(entry["windows_context"])
        self.assertIn(f'id = "{self.BINDING_ID}"', hotkey_sync.generate_macos_bindings(entries))
        for file_key in {str(item["file"]) for item in entries}:
            self.assertNotIn(self.BINDING_ID, hotkey_sync.generate_file(file_key, entries))
        for ahk_file in hotkey_sync.HOTKEYS_DIR.rglob("*.ahk"):
            self.assertNotIn(self.BINDING_ID, ahk_file.read_text(encoding="utf-8"))

    def test_runtime_wires_context_and_action(self) -> None:
        macos_dir = REPO_ROOT / "platforms" / "macos" / "hammerspoon"
        init_text = (macos_dir / "init.lua").read_text(encoding="utf-8")
        self.assertRegex(
            init_text,
            r'\["netnewswire"\] = \{\s*\{bundleID = "com\.ranchero\.NetNewsWire-Evergreen", name = "NetNewsWire"\},\s*\}',
        )
        # Event-tap contexts are named in init.lua; this one must stay on the app-watcher path.
        self.assertNotIn('binding.contextLabel == "netnewswire"', init_text)
        actions_text = (macos_dir / "actions.lua").read_text(encoding="utf-8")
        self.assertIn(f"Actions.{self.BINDING_ID} = function()", actions_text)
        self.assertNotIn("netnewswire-ai-summary", actions_text)


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

    def test_hotstring_backspace_is_rejected(self) -> None:
        before = self.db.read_bytes()
        with self.assertRaises(hotkey_sync.CatalogError) as caught:
            hotkey_sync.set_hotkey("hs_semicolons", "action", 'Send("{BS}ñ")')
        self.assertIn("erases its trigger", str(caught.exception))
        self.assertEqual(self.db.read_bytes(), before)

    def test_macos_only_portability(self) -> None:
        row = ('{"id": "nnw_probe", "file": "global", "type": "hotkey", "key": "!#F9", "action": "x", '
               '"label": "x", "platform": %s, "portability": "%s"}')
        before = self.db.read_bytes()
        for platform, portability in (('["windows", "macos"]', "macos-only"), ('["macos"]', "linux-only")):
            with self.assertRaises(hotkey_sync.CatalogError) as caught:
                hotkey_sync.add_hotkey(row % (platform, portability))
            self.assertIn("nnw_probe", str(caught.exception))
            self.assertEqual(self.db.read_bytes(), before)
        entries, _ = hotkey_sync.add_hotkey(row % ('["macos"]', "macos-only"))
        self.assertEqual(next(e for e in entries if e["id"] == "nnw_probe")["portability"], "macos-only")

    def test_hotkey_requires_id(self) -> None:
        before = self.db.read_bytes()
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.add_hotkey('{"file": "global", "type": "hotkey", "key": "F9", "action": "x", '
                                   '"label": "x", "platform": ["windows"]}')
        with self.assertRaises(hotkey_sync.CatalogError):
            hotkey_sync.set_hotkey("global_alt_d", "active", "yes")
        self.assertEqual(self.db.read_bytes(), before)


class HealthCheckHelperTests(unittest.TestCase):
    def test_hash_matches_between_tools(self) -> None:
        items = [{"trigger": "bd,", "value": "Buen día,", "immediate": True}]
        self.assertEqual(hotkey_sync.catalog_items_sha256(items), "419b85eaa8996b89322d93c0cb372c40e46f2881ce3609dce9f9abfe6c78a3a5")
        self.assertEqual(health_check.catalog_items_sha256(items), hotkey_sync.catalog_items_sha256(items))

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


class AhkRiskLintTests(unittest.TestCase):
    def _types(self, text: str, path: str = "platforms/windows/library/automation/x.ahk") -> list[str]:
        return [str(issue["type"]) for issue in health_check.scan_ahk_risks({path: {"text": text}})]

    def test_unquoted_run_argument(self) -> None:
        self.assertEqual(self._types('utilRunCommand("aimpportable " filename)'), ["ahk_run_unquoted_argument"])
        self.assertEqual(self._types("utilRunCommand('aimpportable \"' filename '\"')"), [])
        self.assertEqual(self._types('; Run("x " path)'), [])

    def test_semicolon_after_space_in_string(self) -> None:
        self.assertEqual(self._types('x := typeAndRead("x ;;")'), ["ahk_semicolon_in_string"])
        self.assertEqual(self._types('x := typeAndRead("x `;;")'), [])
        self.assertEqual(self._types('x := ";;" ; comment with "quote ;"'), [])

    def test_focus_hwnd_used_as_class(self) -> None:
        self.assertEqual(self._types('try focused := ControlGetFocus("A")'), ["ahk_focus_hwnd_as_class"])
        self.assertEqual(self._types('try focused := StrLower(ControlGetClassNN(ControlGetFocus("A")))'), [])

    def test_method_bind_without_this(self) -> None:
        self.assertEqual(self._types('f := this._submit.Bind(value, label)'), ["ahk_method_bind_without_this"])
        self.assertEqual(self._types('f := ObjBindMethod(this, "_submit", value, label)'), [])
        self.assertEqual(self._types('f := this._submit.Bind(this, value)'), [])

    def test_primary_monitor_geometry(self) -> None:
        self.assertEqual(self._types("h := A_ScreenHeight - 40"), ["ahk_single_monitor_geometry"])
        self.assertEqual(self._types("h := A_ScreenHeight", "platforms/windows/library/util.ahk"), [])


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
