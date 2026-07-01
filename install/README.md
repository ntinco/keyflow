# Workstation install manifests

Purpose: make a new Windows or macOS workstation reproducible without syncing full application binaries.

This folder belongs in `keyflow` because the workstation toolchain is part of the automation runtime contract, but it must stay separate from runtime code under `platforms/`.

## Layout

```text
install/
  windows/
    install.cmd
    install.ps1
    manual.md
  macos/
    install.sh
    Brewfile
```

## Run

Windows, from CMD or PowerShell:

```powershell
.\install\windows\install.ps1
```

Windows, from CMD wrapper:

```cmd
install\windows\install.cmd
```

macOS:

```bash
chmod +x install/macos/install.sh
./install/macos/install.sh
```

## Architecture decision

- Windows uses WinGet as the primary installer.
- macOS uses Homebrew Bundle/Brewfile as the primary installer.
- Claude Code uses the native package route where available.
- Comet, SAP GUI/Logon, corporate VPN, machine certificates, and licensed installers stay manual unless a trusted package source exists.
- Local keys, registration codes, company URLs, host files, VPN installers, and personal paths must not be committed.

## Migration note from the legacy CMD

The original local CMD mixed package installs, manual prompts, corporate onboarding, local USB paths, registry imports, SAP GUI setup, and license/registration steps. That was useful for one machine but too risky as a repo artifact. This version keeps only reproducible package installation and moves human/company-specific work to `windows/manual.md`.

## Validation window

Use the scripts on one fresh Windows machine and one fresh Mac within 48-72h. Success criterion: the core development stack is usable with minimal manual steps:

```text
git
node
python
code
cursor
claude
obsidian
insomnia
keyflow runtime prerequisites
```
