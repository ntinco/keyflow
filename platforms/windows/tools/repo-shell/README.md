# repo-shell

PowerShell helper for jumping across local GitHub repositories from any terminal session.

The tool is installed from `keyflow`, but it manages any local Git repository under the configured repo root.

## User variable

The repo root is stored in the Windows user environment variable:

```powershell
KEYFLOW_REPO_ROOT
```

Recommended value:

```powershell
$HOME\.sync\GitHub\ntinco
```

The tool also supports a one-level owner layout, so this also works:

```powershell
$HOME\.sync\GitHub
```

with repos under:

```text
GitHub/
  ntinco/
    keyflow/
    personal-os/
```

## Install

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\platforms\windows\tools\repo-shell\install-repo-shell.ps1
```

Custom repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\platforms\windows\tools\repo-shell\install-repo-shell.ps1 -RepoRoot "$HOME\.sync\GitHub\ntinco"
```

The installer:

1. creates or updates the user variable `KEYFLOW_REPO_ROOT`
2. adds a guarded loader block to the current PowerShell profile
3. loads the commands into the current terminal session

## Commands

List known repos:

```powershell
repo
```

Jump to a repo by exact or partial name:

```powershell
repo keyflow
repo station
repo personal
repo craft
```

Open a repo in VS Code:

```powershell
code-repo keyflow
```

Show Git status for all repos:

```powershell
repo-status
```

Fetch all repos:

```powershell
repo-fetch
```

Show current repo root:

```powershell
repo-root
```

Change repo root later:

```powershell
Set-KeyflowRepoRoot "$HOME\.sync\GitHub\ntinco"
```

Create the repo root if it does not exist:

```powershell
Set-KeyflowRepoRoot "$HOME\.sync\GitHub\ntinco" -Create
```

## Boundary

This tool does not run the AutoHotkey runtime. It only improves terminal navigation across local repositories.
