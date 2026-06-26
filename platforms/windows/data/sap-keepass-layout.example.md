# SAP KeePass Layout

This repo no longer expects `sap-credentials.json`.

The local provider command configured in `keepassProviderCommand` or `NORMAN_KEEPASS_PROVIDER_CMD` should resolve `kp:` references and print the requested value to stdout.

`platforms/windows/tools/keepass/kp-get.ps1` resolves refs with this rule:

- `.../title` -> KeePass field `Title`
- `.../pass` or `.../password` -> KeePass field `Password`
- `.../user` or `.../username` -> KeePass field `UserName`
- `.../url` -> KeePass field `URL`
- `.../notes` -> KeePass field `Notes`
- any other last segment -> custom attribute on the parent entry

## Session model

Each SAP environment is a real KeePass entry.

Example real entry path:

- `company/nttdata/cliente/pluz prd`

Typical fields on that entry:

- `Title` -> `pluz prd`
- `UserName` -> SAP user
- `Password` -> SAP password
- `URL` -> optional launch metadata such as `cmd://... "pluz prd" "300" ""`

Optional custom attributes on the same entry:

- `mandt`
- `sendEnter`
- `sapTcode`
- `languageCode`

If `mandt` is missing, `saplogon.ahk` will try to parse it from the KeePass `URL` field.

## Lookup refs

Use KeePass-backed refs that return a direct entry ref for one environment.

Shortcut lookups:

- `kp:sap-index/session/pluz dev`
- `kp:sap-index/session/pluz qas`
- `kp:sap-index/session/pluz prd`

Example returned value:

- `kp:company/nttdata/cliente/pluz prd`

Example index entry layout:

- Entry path: `sap-index/session`
- Custom attribute: `pluz prd`
- Attribute value: `kp:company/nttdata/cliente/pluz prd`

## Provider behavior

- Required fields should return the value as plain stdout text.
- Optional fields may return empty stdout with exit code `0`.
- Failed lookups should return a non-zero exit code.
- If you use `keepassxc-cli`, opening KeePassXC in the GUI does not by itself guarantee passwordless CLI access. The database still needs a non-interactive auth strategy such as keyfile-only or a password supplied through an environment variable.
