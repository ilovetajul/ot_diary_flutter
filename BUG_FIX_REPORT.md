# Bug Fix Report — OT Diary 2.2.1

## Implemented and CI-validated

- Removed Android/iOS folder deletion and `flutter create` from the main build workflow.
- Removed ZIP auto-apply/auto-push behavior from feature CI.
- Reduced CI repository permissions and disabled checkout credential persistence.
- Synchronized app version to 2.2.1+4 / Android versionCode 4.
- Changed malformed pending queue handling to preserve raw data and fail explicitly.
- Added account UID capture and path checks for pending sync and photo upload.
- Added database-layer date/hour validation for OT saves and imports.
- Added date-aware finite/range filtering to cached/cloud OT decoding.
- Added centralized OT validator and boundary tests.
- Added Settings controls for immediate and approximately two-minute test notifications.

## Analyzer defect corrected

An intermediate commit duplicated `getProfile()`. Run #32 detected the analyzer error. The duplicate was removed. Run #37 subsequently passed Analyze, unit/widget tests and both APK build/upload paths on commit `993d4ff...`.

## Remaining

- Verify immediate/scheduled notifications on a physical device.
- Expand offline sync, conflict, backup/restore, auth/account-switch and widget tests.
- Verify Firebase Rules in the live project.
- Configure and verify production signing.
- Complete PDF/CSV, holiday/target sync and full device tests.
