# Merge Readiness — OT Diary 2.2.1

**Decision: NO-GO for production merge/release**

## Latest verified status

- Working branch: `fix/ot-diary-v2.2.1-stability`
- CI-validated source commit: `993d4ff505c3bdc18fd2ca51eb28e047ebb6eda2`
- Run #37: PASS — Analyze, unit/widget tests, Android embedding, Debug APK and release-mode APK build/upload.
- APK artifacts were uploaded and inspected; the release-mode APK is debug-signed.

## Remaining blocking items

- Production signing must be configured with a private keystore and verified certificate.
- Firebase Realtime Database and Storage Rules must be reviewed, published and tested; repository templates are not live deployment.
- Physical-device tests are required for update/install, notification scheduling, offline queue/reboot, account switching, backup/restore, widget and export.
- Add automated regression coverage for critical queue/account-isolation paths.
- Complete final code/security audit after device tests.

The existing `main` branch and base feature branches remain unchanged. Do not merge until the blockers pass and the user explicitly authorizes merge.
