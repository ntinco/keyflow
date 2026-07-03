# Windows sync

Purpose: version the sync strategy without hardcoding personal machine paths as architecture.

## Root contract

```text
WORKSTATION_DATA_ROOT   = primary data root
WORKSTATION_BACKUP_ROOT = backup / portable root
```

Current Windows implementation:

```cmd
WORKSTATION_DATA_ROOT=H:
WORKSTATION_BACKUP_ROOT=D:
```

## Files

```text
workstation-data-to-backup.example.ffs_batch = versioned template
*.local.ffs_batch                           = generated/local runnable file, not committed
```

To create a local runnable FreeFileSync batch, copy the example and replace placeholders:

```text
__WORKSTATION_DATA_ROOT__
__WORKSTATION_BACKUP_ROOT__
```

Example local resolution:

```text
__WORKSTATION_DATA_ROOT__   -> H:
__WORKSTATION_BACKUP_ROOT__ -> D:
```

## Validation before sync

```cmd
echo %WORKSTATION_DATA_ROOT%
echo %WORKSTATION_BACKUP_ROOT%
dir %WORKSTATION_DATA_ROOT%\.sync
dir %WORKSTATION_BACKUP_ROOT%\..backup_from_download
```

## Safety

The template uses mirror semantics. Validate both roots before running. Keep local files and machine-specific variants out of git.
