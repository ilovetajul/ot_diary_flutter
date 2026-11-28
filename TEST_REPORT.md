# Test Report — OT Diary 2.2.1

**Latest CI status: PASS**  
**Validated source commit:** `993d4ff505c3bdc18fd2ca51eb28e047ebb6eda2`  
**Workflow:** [Run #37 — Stability CI](https://github.com/ilovetajul/ot_diary_flutter/actions/runs/46134168864)

## Run #37 — 2026-11-28

| Step | Result |
|---|---|
| Checkout committed source only | PASS |
| Java 17 / Flutter 3.50.1 setup | PASS |
| Android SDK and NDK setup | PASS |
| Project identity/version verification | PASS |
| Dependency resolution | PASS |
| Launcher icon generation and verification | PASS |
| Flutter Analyze | PASS |
| Unit and widget tests | PASS |
| Android embedding check | PASS |
| Debug APK build and upload | PASS |
| Release-mode APK build and upload | PASS |

Run #37 completed with GitHub Actions conclusion `success`. All listed job steps completed successfully.

## Artifacts

- `OT-Diary-2.2.1-debug-apk` — uploaded, artifact ID `15259157139`, expires 2026-12-12.
- `OT-Diary-2.2.1-release-mode-debug-signed` — uploaded, artifact ID `15258917995`, expires 2026-12-12.

The artifact ZIPs were retrieved and extracted. Each contained one APK; both APK files were confirmed to be ZIP-based Android packages containing `AndroidManifest.xml` and `classes.dex`.

SHA-256:
- Debug APK: `baf1c31290ba2f4211ed73ca19ea0a6aa2bdf903230e18575627ecd2787e63b0`
- Release-mode APK: `aa097b9e881caf66e7fcc2ca879c4b2c527cc924047bbcdb095f95c0cacec7f1`

## Interpretation and limitations

- CI PASS confirms static analysis, automated tests and both APK build tasks passed on this commit.
- Release-mode APK is **debug-signed**, not production-signed. Do not distribute it as a production release.
- APK archive structure was checked; signing certificate identity was not independently verified with `apksigner`.
- No physical Android device test was performed by CI.

## Still outstanding

- Install/update test on the user's Android phone; verify package identity and signing continuity.
- Verify immediate and two-minute scheduled notifications on-device, including notification permission and battery/idle behavior.
- Test offline queue persistence after force-stop/reboot, reconnection, conflict handling and account switching.
- Test backup/restore, PDF/CSV export, widget and profile-photo flows on-device.
- Verify Firebase Rules in Firebase Console/Rules Simulator.
- Configure private production signing and verify the release certificate.
