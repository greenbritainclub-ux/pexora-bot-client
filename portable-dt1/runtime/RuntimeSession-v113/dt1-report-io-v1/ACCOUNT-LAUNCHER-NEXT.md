# Local account launcher request — 2026-09-14

Daniel requests the account-selection window previously offered by the official Bot-Client launcher: Jagex-account sign-in, legacy account storage and per-account proxies, but no Discord authentication for the private Pexora workflow.

The current original DT1 route invokes `GameLoadTestOverlayV2.exe --local-connected-test` directly. The earlier official path invoked a preserved `launcher.exe`. This direct-game launch explains why the account front end is absent; it is not a plugin manifest issue.

A bounded source-file inventory of this workspace did not locate a maintainable source project for that official launcher UI. The preserved official launcher binary is not equivalent to source. Do not claim its account UI or Jagex handoff has been restored.

Proposed separate work item: build a Pexora-owned front end that calls the same pinned DT1 launch workflow, with account labels, user-controlled legacy-account entry and proxy settings. Do not launch a second Sandbox or change the working core/plugin set. No Pexora/Discord login service is required for a local account picker.

Jagex accounts must still authenticate normally. A private-client Jagex launch handoff is not verified. Official guidance supports signing into the Jagex Launcher and choosing the official client or RuneLite; that is not proof that this custom native harness accepts the handoff. Resolve the legitimate integration before promising one-click Jagex login. Never ask the user to paste tokens or inspect/copy their existing credential databases.

Existing account data and secrets were not opened, copied, migrated or changed during this inspection. No account UI, proxy routing, authentication or secret persistence was implemented in this pass.

Official reference: https://support.runescape.com/hc/en-gb/articles/33992401505937-Using-RuneLite-via-the-Jagex-Launcher
