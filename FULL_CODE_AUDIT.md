# Full Code Audit — OT Diary 2.2.1

**Status:** Preliminary code audit; CI validated, not a complete final/production audit  
**Audit baseline:** `feature/ot-diary-v2.2` at `04025cb156fb15b0f1f34ecb4e94a88a420f5345`  
**Working branch:** `fix/ot-diary-v2.2.1-stability`  
**CI-validated source commit:** `993d4ff505c3bdc18fd2ca51eb28e047ebb6eda2`

## Scope inspected

- Main and feature GitHub Actions workflows
- `pubspec.yaml`, Android Gradle, Manifest and app identity
- `DatabaseService`: local cache, pending queue, OT save/reset, profile/photo, import/export
- `ExtraTools`: backup snapshot/restore, OT validation, CSV/PDF
- Notification service
- MainActivity file picker channel and Android home-screen widget
- Home and Settings screen save/input flows
- Existing tests and Firebase client configuration
- Stability CI configuration and generated APK artifacts

## Findings and disposition

| Finding | Severity | Status |
|---|---|---|
| Main build workflow deleted Android/iOS folders and regenerated Android project | Critical | Fixed on stability branch; Run #37 passed |
| Feature CI had write permission, persistent checkout credentials, ZIP auto-apply and automatic source push | High | Fixed on stability branch; Run #37 passed |
| Main workflow self-check matched its own destructive-command pattern and required 2.2.1 on older main | High | Fixed on stability branch |
| Malformed pending queue was silently converted to empty, risking offline operation loss | Critical | Fixed; malformed content preserved and explicit error returned |
| Pending sync could use mutable current UID during async work | High | Source hardened to capture UID and bind queue/photo sync to that UID; device/account-switch tests open |
| OT persistence accepted invalid date/hour values | High | Central `OtEntryValidator` added and used in persistence/import utility; tests added; Run #37 passed |
| Realtime Database Rules were not tracked | High | UID-scoped template and Bengali deployment guide added; live deployment not verified |
| Storage example accepted broad `image/.*` content type | Medium | JPEG/PNG/WebP and 5 MiB template added; live deployment not verified |
| Release build uses debug signing | Critical for production | Open; production signing blocked |
| Test suite does not cover full offline/reboot/multi-account/device behavior | High | Open; CI tests pass but coverage is not comprehensive |
| Notification test and two-minute schedule | Medium | Implemented and compiled; actual delivery/idle behavior needs device verification |
| Backup/restore, widget, UI, PDF, notifications, account-switch flows | High | Further regression audit and physical-device verification open |

## Data compatibility

Existing Firebase paths remain unchanged:

- `users/{uid}/profile`
- `users/{uid}/ot/{yyyy_MM}/{day}`

No Firebase data migration or deletion was performed. No live Firebase Rules were published.

## CI evidence

Run #37 passed Analyze, unit/widget tests, Android embedding verification, Debug APK build/upload and release-mode APK build/upload on commit `993d4ff...`. See `TEST_REPORT.md`.

## Gate

**Production readiness: NO-GO.** Production signing, live Firebase Rules verification and physical-device/regression testing remain required.
