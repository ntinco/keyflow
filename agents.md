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
6. Before closing the cycle, update the AI operating guide if behavior, routing, rules, or current evolution status changed.

If step 2 or 4 returns `ok: false`, fix the reported issues before doing anything else.

## Hard rules

- Never touch local-only files unless the user explicitly asks: `local-secrets.ini`, `local-paths.ini`, `local-startup.ini`, `memory-vars.ini`, `rom.ini`, `storage.db`.
- Never reintroduce retired env fallbacks, retired workspace names, or references to removed guide paths.
- Never merge `sap-session.ahk` into `sap.ahk` or vice versa.
- Never guess machine paths; use `*.example.*` only as shape references.
- Never depend on Git metadata at runtime.
- Never reintroduce a separate paste service without first proving it adds value over the existing launcher flow.

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
- SAP session wiring is now business-name-first and KeePass-first.
- Startup scripts are part of the repo, but treated as secondary launchers, not the core runtime.
- Next frontier: keep shrinking dormant public surface and optional UI helpers after every successful rename.

## Validation

- Code changes: verify the include chain from `platforms/windows/keyflow.ahk` through `bootstrap.ahk`.
- Service or hotkey changes: inspect the related JSON or INI contract first.
- Guide changes: keep `AGENTS.md`, `README.md`, `ai/repo-map.json`, and `ai/health-check.summary.json` aligned.
- Never validate by writing to local secret files or runtime databases.
