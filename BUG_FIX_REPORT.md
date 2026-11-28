# Bug Fix Report — OT Diary 2.2.1

## Implemented in the working branch

- Removed Android/iOS folder deletion and `flutter create` from the main build workflow.
- Removed ZIP auto-apply/auto-push behavior from feature CI.
- Reduced CI repository permissions and disabled checkout credential persistence.
- Synchronized version metadata to 2.2.1+4 / Android versionCode 4.
- Changed malformed pending queue handling to preserve the raw queue and fail explicitly.
- Added account UID capture and path checks for pending sync and photo upload.
- Added database-layer date/hour validation for OT saves and imports.
- Added date-aware finite/range filtering to cached/cloud OT decoding.
- Expanded existing validation boundary tests.

## Analyzer defect found and corrected

An intermediate commit accidentally duplicated `getProfile()`. GitHub Actions Run #32 detected it during `flutter analyze`. The duplicate was removed in commit `bd4e80fd4d8cb3eadd88ba53433d561342724bf1`; the latest run must verify that correction.

## Still open

- Complete the full feature regression audit.
- Implement/verify the two-minute scheduled test notification.
- Expand automated offline sync, conflict, backup/restore, auth/account-switch and widget tests.
- Verify Firebase Rules in the live project.
- Configure and verify production signing.
- Complete PDF/CSV, target/holiday sync, and physical-device tests.