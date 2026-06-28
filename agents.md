# AGENTS.md

AutoHotkey v2 Windows automation workspace. Operational repo, optimized for AI maintenance.

## AI operating guide

This repo is governed by:

1. `ai/health-check.summary.json`
2. `ai/repo-map.json`
3. `AGENTS.md`
4. `README.md`

If those files disagree, the earlier item wins.

## Mandatory workflow

1. Read `ai/repo-map.json`.
2. Run `python ai/health_check.py --pretty --summary`.
3. Edit the smallest responsible file set.
4. Run `python ai/health_check.py --pretty --output ai/health-check.json --output-summary ai/health-check.summary.json`.
5. If runtime wiring changed, smoke-test with `platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001 platforms/windows/keyflow.ahk`.
6. **Close the cycle by updating the AI operating guide** — see *Guide update rule* below.

If step 2 or 4 returns `ok: false`, fix the reported issues before doing anything else.

## Guide update rule

The cycle is not closed until the guide reflects the current state. This is mandatory, not optional.

After every execution cycle that removes, renames, or rewires anything:

| Artifact | What to write |
|---|---|
| `ai/health-check.summary.json` | Regenerate with `health_check.py`. Source of objective truth. |
| `ai/repo-map.json` | Remove entries for deleted paths. Update `current-focus` and `next-frontier`. Never leave dead routes. |
| `AGENTS.md` → *Current evolution status* | **Replace**, do not append. Write what is true now: what completed, what no longer applies, what is next. |
| `README.md` → *Current evolution status* | Same: replace, not append. Remove mentions of completed frontiers. |
| `next.md` | One paragraph: next frontier and current state. Overwrite the previous content. Not a log. |

**Replacement rule:** these sections shrink or stay flat, they do not grow. History that no longer serves the next AI reader belongs in the git log or gets discarded. If a section is growing, the update was done wrong.

## Hard rules

- Never touch local-only files unless the user explicitly asks: `local-secrets.ini`, `local-paths.ini`, `local-startup.ini`, `memory-vars.ini`, `rom.ini`, `storage.db`.
- Never reintroduce retired env fallbacks, retired workspace names, or references to removed guide paths.
- Never merge `sap-session.ahk` into `sap.ahk` or vice versa.
- Never guess machine paths; use `*.example.*` only as shape references.
- Never depend on Git metadata at runtime.
- Never reintroduce a separate paste service without first proving it adds value over the existing launcher flow.
- Never leave dead paths in `repo-map.json` after deleting a file or directory.

## Naming contract

| Scope | Rule |
|---|---|
| Files, classes, services, helpers, groups, targets | English-first |
| New runtime APIs | intent-first, short, explicit |
| External labels | Keep as-is |
| SAP session names | Use business names like `pluz dev`, `pluz qas`, `pluz prd` |

Preferred vocabulary: `session` `entry` `provider` `catalog` `window` `workspace` `target` `profile` `group` `context` `command` `run` `action` `path` `secret` `constant`

Avoid mixing: `session` with old login/logon terms, `window` with desktop/gui synonyms, `run` with open/execute/start unless the distinction is real.

## File boundaries

| Concern | Owner |
|---|---|
| SAP session resolution + KeePass provider | `platforms/windows/library/automation/sap-session.ahk` |
| SAP GUI + ADT automation | `platforms/windows/library/automation/sap.ahk` |
| Service wiring + hotstring profiles | `platforms/windows/library/bootstrap.ahk` |
| Hotkey triggers | `platforms/windows/hotkeys/` |
| Startup launchers | `platforms/windows/tools/startup/` |
| Versioned catalogs | `platforms/windows/data/*.json` |
| AI tooling and navigation | `ai/` |

## Current evolution status

- Runtime entrypoint is stable and health-check driven.
- SAP session wiring is business-name-first and KeePass-first.
- Startup scripts are secondary launchers, not the source of truth for runtime behavior.
- Aggressive simplification is active: deleting dormant UI helpers, collapsing thin aggregator files, removing wrapper classes with no added value, and shrinking the constants surface.
- Next frontier: execute `evolution-plan.md` starting at Frente 1 (dead UI helpers), then Frente 2 (hotkey aggregators).

## Validation

- Code changes: verify the include chain from `platforms/windows/keyflow.ahk` through `bootstrap.ahk`.
- Service or hotkey changes: inspect the related JSON or INI contract first.
- Guide changes: keep `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health-check.summary.json` aligned.
- Never validate by writing to local secret files or runtime databases.
