#!/usr/bin/env bash
set -euo pipefail

: "${WORKSTATION_DATA_ROOT:?Set WORKSTATION_DATA_ROOT first. See install/anchors/README.md}"
: "${WORKSTATION_BACKUP_ROOT:?Set WORKSTATION_BACKUP_ROOT first. See install/anchors/README.md}"

src="${WORKSTATION_DATA_ROOT}/.sync/"
dst="${WORKSTATION_BACKUP_ROOT}/..backup_from_download/.sync/"

if [[ ! -d "$src" ]]; then
  echo "Source does not exist: $src" >&2
  exit 1
fi

mkdir -p "$dst"

echo "Sync source: $src"
echo "Sync target: $dst"
echo "Dry run first. Review output before removing --dry-run."

rsync -av --delete --dry-run \
  --exclude='.git/' \
  --exclude='node_modules/' \
  --exclude='.agents/' \
  --exclude='.codex/' \
  "$src" "$dst"
