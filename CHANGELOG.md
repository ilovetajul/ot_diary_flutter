## 2.2.1 — Stability (CI validated; device testing pending)

- Updated app version to 2.2.1 (versionCode 4).
- Hardened offline pending queue handling so malformed queue data is preserved for recovery instead of silently replaced with an empty queue.
- Added persistence-layer validation for OT date and hour values.
- Bound pending sync and profile-photo operations to the UID captured at operation start.
- Reworked GitHub Actions to use committed source, read-only repository permissions, and non-persistent checkout credentials.
- Added Firebase Realtime Database and Storage security-rule templates plus Bengali manual deployment instructions.
- Added immediate and approximately two-minute test notification actions in Settings.
- Run #37 passed Flutter Analyze, unit/widget tests, Android embedding checks, Debug APK build/upload and release-mode APK build/upload.
- APK artifacts were uploaded; release-mode APK is debug-signed.
- Physical-device tests, live Firebase Rules verification and production signing remain pending.
