# Original DT1 launcher status-file repair — 2026-09-14

Run `connected-v4-20260914-155735-745` successfully registered Mike and the four V70 plugins, then failed while `Save-State` opened the mapped state JSON: Windows sharing violation. The supervisor's existing error cleanup restored the game network restriction and terminated its harness. Consequently the normal Delve V48 hook never ran. The fresh guest diagnostic at 16:03:53Z found no remaining osclient. This was not a Delve bytecode or registration failure.

`launch-dt1-v70-net-v100` is a separate orchestration revision of V99. It preserves the complete V99 directory and reuses the identical original core, overlay harness, V39 list helper, V70 batch binaries and plugin JARs. The new state writer acquires a sharing-compatible handle before altering data and retries only bounded Windows sharing/lock violations; permanent failures still surface. The startup observer tolerates a transient partial JSON snapshot.

All five state-I/O fixtures passed both on the host and inside the current Sandbox against its mapped `C:\CanaryLogs` volume. Evidence: `Output\dt1-state-io-v100-test.json`. They cover round-trip, shorter overwrite with a concurrent shared reader, recovery from a transient incompatible reader, bounded permanent-lock failure without truncation, and size-bound preservation.

Normal `Open-Pexora-DT1.cmd` now validates V100 in addition to the unchanged runtime/plugin pins. Guest `Resume-FirstIsolatedDt1.ps1` stages only the new launcher directory into the existing Sandbox and uses it before the V48 Delve extension. A new actual launch still must pass its own complete readiness and Delve reports. Fixtures are not proof of a live plugin test.

Recovery does not close or replace the Sandbox. Do not attach to the exited run or rewrite its failed reports as successful.
