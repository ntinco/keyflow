# Codex Runtime Notes

Use this file as a tactical fast-start only. Repository authority stays in `AGENTS.md`.

## Fast path

1. Read `ai/repo-map.json`.
2. Run `python ai/health_check.py --pretty --output ai/health-check.json`.
3. Edit the smallest responsible file set.
4. If wiring changed, run `platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001 platforms/windows/keyflow.ahk`.

## Operating posture

- Prefer deletion over compatibility layers.
- Do not reintroduce legacy `NORMAN_*` compatibility.
- Keep hotkeys declarative and push reusable behavior into services only when it earns its place.
- Treat `sap-session.ahk` and `sap.ahk` as separate responsibilities.
- Prefer `README.md`, `AGENTS.md`, `ai/repo-map.json`, and `ai/health-check.json` over repo exploration by default.
