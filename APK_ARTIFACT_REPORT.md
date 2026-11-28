# APK Artifact Report — OT Diary 2.2.1

Source commit: `993d4ff505c3bdc18fd2ca51eb28e047ebb6eda2`  
Workflow: [Run #37 — Stability CI](https://github.com/ilovetajul/ot_diary_flutter/actions/runs/46134168864)

## Debug APK

- Artifact: `OT-Diary-2.2.1-debug-apk`
- Artifact ID: `15259157139`
- APK member: `app-debug.apk`
- APK size: 177,651,468 bytes
- SHA-256: `baf1c31290ba2f4211ed73ca19ea0a6aa2bdf903230e18575627ecd2787e63b0`

## Release-mode APK (debug-signed)

- Artifact: `OT-Diary-2.2.1-release-mode-debug-signed`
- Artifact ID: `15258917995`
- APK member: `app-release.apk`
- APK size: 69,081,457 bytes
- SHA-256: `aa097b9e881caf66e7fcc2ca879c4b2c527cc924047bbcdb095f95c0cacec7f1`

Both artifact ZIPs were downloaded and extracted; each APK is structurally readable as an Android package with `AndroidManifest.xml` and `classes.dex`.

**Important:** The release-mode APK uses the debug signing configuration. It is not a production-signed release. The APK files' signatures/certificate were not independently checked with Android `apksigner`; CI reports the configured signing limitation.

Artifacts expire on 2026-12-12. Download them from the Run #37 page before expiry.
