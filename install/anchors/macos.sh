#!/usr/bin/env bash
set -euo pipefail

profile_file="${HOME}/.zshrc"

touch "$profile_file"

if ! grep -q '^export WORKSTATION_DATA_ROOT=' "$profile_file"; then
  echo 'export WORKSTATION_DATA_ROOT="/Volumes/workstation-data"' >> "$profile_file"
fi

if ! grep -q '^export WORKSTATION_BACKUP_ROOT=' "$profile_file"; then
  echo 'export WORKSTATION_BACKUP_ROOT="/Volumes/workstation-backup"' >> "$profile_file"
fi

echo "Workstation anchors written to $profile_file"
echo "Open a new terminal, then validate:"
echo '  echo "$WORKSTATION_DATA_ROOT"'
echo '  echo "$WORKSTATION_BACKUP_ROOT"'
