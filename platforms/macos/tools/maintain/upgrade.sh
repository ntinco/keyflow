#!/usr/bin/env bash
set -euo pipefail

echo "keyflow macOS maintenance"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Run install/macos/install.sh first." >&2
  exit 1
fi

echo "==> brew update"
brew update

echo "==> brew upgrade"
brew upgrade

echo "==> brew cleanup"
brew cleanup

echo "==> versions"
command -v git >/dev/null 2>&1 && git --version || true
command -v node >/dev/null 2>&1 && node --version || true
command -v npm >/dev/null 2>&1 && npm --version || true
command -v python3 >/dev/null 2>&1 && python3 --version || true
command -v code >/dev/null 2>&1 && code --version | head -n 1 || true
command -v cursor >/dev/null 2>&1 && cursor --version | head -n 1 || true
command -v claude >/dev/null 2>&1 && claude --version || true

echo "Done."
