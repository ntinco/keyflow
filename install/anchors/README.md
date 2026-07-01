# Workstation root anchors

Purpose: define portable root anchors that work across Windows, macOS, and future repo renames.

Use semantic environment variables instead of hardcoding platform-specific roots in reusable scripts.

```text
WORKSTATION_DATA_ROOT   = primary personal/data root
WORKSTATION_BACKUP_ROOT = portable backup/transport root
```

Windows current implementation:

```cmd
WORKSTATION_DATA_ROOT=H:
WORKSTATION_BACKUP_ROOT=D:
```

macOS starting implementation:

```bash
WORKSTATION_DATA_ROOT=/Volumes/workstation-data
WORKSTATION_BACKUP_ROOT=/Volumes/workstation-backup
```

Rules:

```text
- Scripts should prefer WORKSTATION_DATA_ROOT and WORKSTATION_BACKUP_ROOT.
- Windows drive letters remain implementation details, not architecture names.
- Generated/local sync files may resolve to concrete drives and must stay local when machine-specific.
- Versioned examples should use placeholders or environment variable contracts.
```

Validation:

```text
Windows: echo %WORKSTATION_DATA_ROOT% && echo %WORKSTATION_BACKUP_ROOT%
macOS:   echo "$WORKSTATION_DATA_ROOT" && echo "$WORKSTATION_BACKUP_ROOT"
```
