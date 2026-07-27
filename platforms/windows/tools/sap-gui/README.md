# SAP GUI launcher

Purpose: keep the optional SAP GUI command-line adapter separate from the main runtime.

Rules:

```text
- This folder may contain command-line execution adapters for SAP GUI / NWBC.
- Credentials must not be stored in repository files.
- Any adapter that receives credentials must be treated as a local execution bridge.
```

Current model:

```text
external local caller -> sap-gui-cli.bat -> SAP GUI / NWBC
```

Do not add company hosts, SAP connection files, certificates, passwords, or customer-specific system metadata here.
