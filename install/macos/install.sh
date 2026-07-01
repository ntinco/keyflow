#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '\n==> %s\n' "$1"
}

install_homebrew_if_needed() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  log "install Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_list() {
  local mode="$1"
  local file="$2"
  [[ -f "$file" ]] || return

  while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    [[ "$item" == \#* ]] && continue
    log "brew install $mode $item"
    if [[ "$mode" == "--cask" ]]; then
      brew install --cask "$item" || true
    else
      brew install "$item" || true
    fi
  done < "$file"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is intended for macOS." >&2
  exit 1
fi

install_homebrew_if_needed

log "brew update"
brew update

install_list "formula" "$script_dir/brew-formulae.txt"
install_list "--cask" "$script_dir/brew-casks-core.txt"

cat <<'MSG'

Manual follow-up:
- Comet: https://www.perplexity.ai/comet
- Logi Options+: https://www.logitech.com/software/options.html
- SAP GUI / SAP Logon: install through company/SAP channel.
- VMware Fusion: use Broadcom/VMware official portal if needed.
- keyflow mac runtime: evaluate Hammerspoon and Karabiner-Elements manually before adding them to automation.
MSG
