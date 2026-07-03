# macOS sync

Purpose: provide a starting sync strategy equivalent to Windows while keeping platform roots abstract.

## Root contract

```text
WORKSTATION_DATA_ROOT   = primary data root
WORKSTATION_BACKUP_ROOT = backup / portable root
```

Expected macOS implementation:

```bash
export WORKSTATION_DATA_ROOT="/Volumes/workstation-data"
export WORKSTATION_BACKUP_ROOT="/Volumes/workstation-backup"
```

The initial script uses `rsync` in dry-run mode by default:

```bash
./install/macos/sync/workstation-data-to-backup.sh
```

Remove `--dry-run` only after validating source, target, and exclusions.

## Validation

```bash
echo "$WORKSTATION_DATA_ROOT"
echo "$WORKSTATION_BACKUP_ROOT"
ls "$WORKSTATION_DATA_ROOT/.sync"
ls "$WORKSTATION_BACKUP_ROOT/..backup_from_download"
```
