"""Unit tests for AI tooling. Run: python3 -m unittest discover -s ai/tests"""

from __future__ import annotations

import copy
import fnmatch
import json
import shlex
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
import run_smoke  # noqa: E402


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


class ControlPlaneTests(unittest.TestCase):
    """The always-loaded kernel stays small only while what left it remains reachable from the repo-map."""

    def setUp(self) -> None:
        self.repo_map = json.loads((AI_DIR / "repo-map.json").read_text(encoding="utf-8"))
        self.procedures = self.repo_map["routing"]["procedures"]

    def _issue_types(self, repo_map: dict[str, object]) -> list[str]:
        return [str(issue["type"]) for issue in health_check.validate_repo_map(REPO_ROOT, repo_map)]

    def test_repo_map_is_valid(self) -> None:
        self.assertEqual(self._issue_types(self.repo_map), [])
        self.assertEqual(set(self.procedures), set(health_check.PROCEDURE_ROUTES))

    def test_missing_or_dead_procedure_route_is_reported(self) -> None:
        for key in health_check.PROCEDURE_ROUTES:
            for value in (None, "python3 ai/no_such_tool.py --help", "NO-SUCH.md", "README.md#no-such-heading"):
                broken = copy.deepcopy(self.repo_map)
                if value is None:
                    del broken["routing"]["procedures"][key]
                else:
                    broken["routing"]["procedures"][key] = value
                self.assertEqual(self._issue_types(broken), ["repo_map_procedure_route"], (key, value))

    def test_kernel_points_at_the_procedure_routes(self) -> None:
        governance = (AI_DIR / "governance.md").read_text(encoding="utf-8").split("<!-- workspace-contract")[0]
        agents = (REPO_ROOT / "AGENTS.md").read_text(encoding="utf-8")
        for text in (governance, agents):
            self.assertIn("`routing.procedures`", text)
        # Boundaries that no procedure may carry away from the cold start.
        for anchor in ("`ai/hotkey_sync.py` edit commands, never raw SQL", "never an authority", "`--mark-reviewed`",
                       "`local_only`", "not observed", "`workstation-ops`", "personas", "`ai/current-plan.md`"):
            self.assertIn(anchor, governance)

    def test_catalog_change_recipes_are_in_the_routed_help(self) -> None:
        command = shlex.split(self.procedures["catalog_change"])
        self.assertEqual(command[0], "python3")
        result = subprocess.run([sys.executable, *command[1:]], cwd=REPO_ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        for recipe in ("--add-hotstring", "--set-hotstring", "--remove-hotstring", "--add-hotkey", "--mark-reviewed",
                       "trigger conflict", "sap-transaction-catalog", "sap-transaction-shortcuts", "without /n",
                       "sap-tcode:<code>", "Actions.<id>", "registered automation service", "SPECIAL_BEHAVIORS"):
            self.assertIn(recipe, result.stdout)

    def test_runtime_review_procedure_is_in_the_routed_section(self) -> None:
        rel, _, anchor = self.procedures["runtime_change_or_review"].partition("#")
        sections = (REPO_ROOT / rel).read_text(encoding="utf-8").split("\n## ")
        section = next(item for item in sections if item.splitlines()[0].lower().replace(" ", "-") == anchor)
        for step in ("timing and input erasure", "dispatch/scope/focus", "platform parity", "paths/geometry",
                     "failure handling", "`file:line`", "pure-logic tests", "`ai/current-plan.md`",
                     "selftest.ahk", "run_smoke.py --platform windows", "run_smoke.py --platform macos",
                     "macos_logic_test.lua"):
            self.assertIn(step, section)

    def test_platform_validators_exist(self) -> None:
        for commands in self.repo_map["platform_validators"].values():
            for command in commands:
                script = next(part for part in command.split() if "/" in part)
                self.assertTrue((REPO_ROOT / script).is_file(), command)

    def test_generated_local_outputs_are_held_to_the_local_only_contract(self) -> None:
        ownership = self.repo_map["ownership"]
        self.assertEqual(set(health_check.local_paths(self.repo_map)),
                         set(self.repo_map["local_only"]) | set(ownership["generated_local"]))
        self.assertFalse(set(self.repo_map["local_only"]) & set(ownership["generated_local"]))
        self.assertEqual(health_check.validate_local_only_contract(REPO_ROOT, self.repo_map), [])
        for key in ("local_only", "generated_local"):
            leaking = copy.deepcopy(self.repo_map)
            target = leaking if key == "local_only" else leaking["ownership"]
            target[key] = [*target[key], "README.md"]
            types = [issue["type"] for issue in health_check.validate_local_only_contract(REPO_ROOT, leaking)]
            self.assertEqual(types, ["local_only_gitignore_gap", "local_only_tracked"], key)

    def test_generated_outputs_are_never_human_owned(self) -> None:
        ownership = self.repo_map["ownership"]
        generated = [*ownership["generated_versioned"], *ownership["generated_local"]]
        for source in ownership["human_owned"]:
            self.assertFalse(any(fnmatch.fnmatch(source, path) or (path.endswith("/") and source.startswith(path))
                                 for path in generated), source)


class DisplayKeyTests(unittest.TestCase):
    def test_hotstring_displays_trigger(self) -> None:
        entry = {"type": "hotstring", "trigger": "hello"}
        self.assertEqual(hotkey_sync._display_key(entry), "hello")

    def test_hotstring_with_complex_trigger(self) -> None:
        entry = {"type": "hotstring", "trigger": "bd,"}
        self.assertEqual(hotkey_sync._display_key(entry), "bd,")

    def test_modifiers_in_canonical_order(self) -> None:
        entry = {"type": "hotkey", "key": "^!x"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+Alt+X")

    def test_modifiers_processed_regardless_of_input_order(self) -> None:
        entry = {"type": "hotkey", "key": "!^x"}
        self.assertEqual(hotkey_sync._display_key(entry), "Alt+Ctrl+X")

    def test_multiple_modifiers_all_displayed(self) -> None:
        entry = {"type": "hotkey", "key": "#^!+a"}
        self.assertEqual(hotkey_sync._display_key(entry), "Win+Ctrl+Alt+Shift+A")

    def test_tilde_prefix_dropped(self) -> None:
        entry = {"type": "hotkey", "key": "~^x"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+X")

    def test_dollar_prefix_dropped(self) -> None:
        entry = {"type": "hotkey", "key": "$^x"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+X")

    def test_star_prefix_dropped(self) -> None:
        entry = {"type": "hotkey", "key": "*^x"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+X")

    def test_named_key_xbutton1(self) -> None:
        entry = {"type": "hotkey", "key": "xbutton1"}
        self.assertEqual(hotkey_sync._display_key(entry), "MouseBack")

    def test_named_key_xbutton1_with_modifier(self) -> None:
        entry = {"type": "hotkey", "key": "^xbutton1"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+MouseBack")

    def test_named_key_pgdn(self) -> None:
        entry = {"type": "hotkey", "key": "pgdn"}
        self.assertEqual(hotkey_sync._display_key(entry), "PageDown")

    def test_named_key_pgdn_case_insensitive(self) -> None:
        entry = {"type": "hotkey", "key": "PGDN"}
        self.assertEqual(hotkey_sync._display_key(entry), "PageDown")

    def test_function_key(self) -> None:
        entry = {"type": "hotkey", "key": "F9"}
        self.assertEqual(hotkey_sync._display_key(entry), "F9")

    def test_function_key_lowercase(self) -> None:
        entry = {"type": "hotkey", "key": "f1"}
        self.assertEqual(hotkey_sync._display_key(entry), "F1")

    def test_function_key_with_modifier(self) -> None:
        entry = {"type": "hotkey", "key": "^F12"}
        self.assertEqual(hotkey_sync._display_key(entry), "Ctrl+F12")

    def test_single_letter_uppercase(self) -> None:
        entry = {"type": "hotkey", "key": "A"}
        self.assertEqual(hotkey_sync._display_key(entry), "A")

    def test_single_letter_lowercase_uppercased(self) -> None:
        entry = {"type": "hotkey", "key": "z"}
        self.assertEqual(hotkey_sync._display_key(entry), "Z")

    def test_unknown_key_displayed_as_written(self) -> None:
        entry = {"type": "hotkey", "key": "customkey"}
        self.assertEqual(hotkey_sync._display_key(entry), "customkey")

    def test_unknown_key_with_modifier(self) -> None:
        entry = {"type": "hotkey", "key": "!customkey"}
        self.assertEqual(hotkey_sync._display_key(entry), "Alt+customkey")


class MacosLogicTests(unittest.TestCase):
    def test_lua_pure_logic(self) -> None:
        lua = shutil.which("lua")
        if not lua:
            self.skipTest("lua interpreter not available")
        result = subprocess.run([lua, str(AI_DIR / "tests" / "macos_logic_test.lua")],
                                cwd=REPO_ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)


class RunSmokeSkipTests(unittest.TestCase):
    def test_missing_ahk_executable_is_not_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = run_smoke.run_smoke(Path(tmp), 1)
        self.assertEqual(result["outcome"], "not_run")
        self.assertIn("AHK executable not found", str(result["notes"]))

    def test_missing_entry_script_is_not_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            exe = root / "platforms/windows/tools/exe/AutoHotkey64.exe"
            exe.parent.mkdir(parents=True)
            exe.write_bytes(b"")
            result = run_smoke.run_smoke(root, 1)
        self.assertEqual(result["outcome"], "not_run")
        self.assertIn("Entry point not found", str(result["notes"]))

    def test_macos_missing_init_lua_is_not_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = run_smoke.run_smoke_macos(Path(tmp))
        self.assertEqual(result["outcome"], "not_run")
        self.assertIn("macOS entry point not found", str(result["notes"]))


class StringEscapingTests(unittest.TestCase):
    def test_ahk_str_escapes_backtick(self) -> None:
        self.assertEqual(hotkey_sync._ahk_str("`"), "``")

    def test_ahk_str_escapes_double_quote(self) -> None:
        self.assertEqual(hotkey_sync._ahk_str('"'), '`"')

    def test_ahk_str_escapes_both_backtick_and_double_quote(self) -> None:
        self.assertEqual(hotkey_sync._ahk_str('"`"'), '`"```"')

    def test_ahk_str_returns_unchanged_when_nothing_to_escape(self) -> None:
        self.assertEqual(hotkey_sync._ahk_str("hello"), "hello")

    def test_lua_str_escapes_backslash(self) -> None:
        self.assertEqual(hotkey_sync._lua_str("\\"), "\\\\")

    def test_lua_str_escapes_double_quote(self) -> None:
        self.assertEqual(hotkey_sync._lua_str('"'), '\\"')

    def test_lua_str_escapes_both_backslash_and_double_quote(self) -> None:
        self.assertEqual(hotkey_sync._lua_str('\\"'), '\\\\\\"')

    def test_lua_str_returns_unchanged_when_nothing_to_escape(self) -> None:
        self.assertEqual(hotkey_sync._lua_str("hello"), "hello")


class StaleGeneratedFilesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.hotkeys_dir = Path(self.tmp.name)
        self.original_hotkeys_dir = hotkey_sync.HOTKEYS_DIR
        hotkey_sync.HOTKEYS_DIR = self.hotkeys_dir

    def tearDown(self) -> None:
        hotkey_sync.HOTKEYS_DIR = self.original_hotkeys_dir
        self.tmp.cleanup()

    def test_generated_file_not_in_expected_set_is_reported(self) -> None:
        stale_file = self.hotkeys_dir / "stale.ahk"
        stale_file.write_text(f"{hotkey_sync.GENERATED_MARKER}\nSome content\n")
        stale = hotkey_sync.stale_generated_files(set())
        self.assertEqual(len(stale), 1)
        self.assertEqual(stale[0], stale_file)

    def test_generated_file_in_expected_set_is_not_reported(self) -> None:
        expected_file = self.hotkeys_dir / "expected.ahk"
        expected_file.write_text(f"{hotkey_sync.GENERATED_MARKER}\nContent\n")
        stale = hotkey_sync.stale_generated_files({expected_file})
        self.assertEqual(stale, [])

    def test_file_without_generated_marker_is_not_reported(self) -> None:
        manual_file = self.hotkeys_dir / "manual.ahk"
        manual_file.write_text("; This is a manual file\nSome content\n")
        stale = hotkey_sync.stale_generated_files(set())
        self.assertEqual(stale, [])

    def test_empty_file_is_not_reported_and_does_not_raise(self) -> None:
        empty_file = self.hotkeys_dir / "empty.ahk"
        empty_file.write_text("")
        stale = hotkey_sync.stale_generated_files(set())
        self.assertEqual(stale, [])

    def test_mixed_files_filters_correctly(self) -> None:
        generated_stale = self.hotkeys_dir / "stale_generated.ahk"
        generated_stale.write_text(f"{hotkey_sync.GENERATED_MARKER}\nContent\n")

        generated_expected = self.hotkeys_dir / "expected_generated.ahk"
        generated_expected.write_text(f"{hotkey_sync.GENERATED_MARKER}\nContent\n")

        manual = self.hotkeys_dir / "manual.ahk"
        manual.write_text("; Manual file\n")

        stale = hotkey_sync.stale_generated_files({generated_expected})
        self.assertEqual(len(stale), 1)
        self.assertEqual(stale[0], generated_stale)

    def test_nested_directories_are_checked(self) -> None:
        subdir = self.hotkeys_dir / "subdir"
        subdir.mkdir()
        nested_stale = subdir / "nested.ahk"
        nested_stale.write_text(f"{hotkey_sync.GENERATED_MARKER}\nContent\n")
        stale = hotkey_sync.stale_generated_files(set())
        self.assertEqual(len(stale), 1)
        self.assertEqual(stale[0], nested_stale)


if __name__ == "__main__":
    unittest.main()
