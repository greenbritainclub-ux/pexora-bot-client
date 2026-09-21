# Pexora Bot Client — portable DT1 Sandbox bundle

This repository contains the curated, distribution-authorized DT1 Windows Sandbox bundle. It is based on the preserved first-isolated DT1 route:

- software-rendered Windows Sandbox, 8 GB guest memory;
- `RuntimeSession-v113` compatibility family;
- five stopped base plugins plus the Delve v44/v55 stopped-registration extension;
- clean portable profile with no account credentials, cookies, sessions, TOTP data, browser state, logs, or user directories.

## Use

Run `Launch-Portable-DT1.ps1` from a Windows host with Windows Sandbox enabled. The launcher generates a WSB file with paths relative to this checkout. The guest requires normal OSRS network access. Sign in manually; no account or OAuth state is included.

The first launch is deliberately stopped-by-default. Review the client configuration before starting a plugin.

## Distribution boundary

The repository includes authorized client/runtime/plugin artifacts needed by the DT1 route. It does not include the original sandbox's diagnostics, raw captures, archives, memory dumps, account launcher state, DPAPI vaults, browser profiles, credentials, or unrelated DreamBot analysis.

The bundle is portable across compatible Windows hosts, but it still requires Windows Sandbox, hardware/OS compatibility, and network access. It is not a host-native client.

## Verification

`release-manifest.json` records the source route, selected artifacts, and SHA-256 pins. A fresh no-start/readiness run is required after transfer; historical PIDs and reports are not reused.
