# Merge Readiness — OT Diary 2.2.1

**Decision: NO-GO**

Do not merge this branch to `feature/ot-diary-v2.2`, `feature/modern-ot-diary` or `main` yet.

## Blocking items

- Latest stability CI must pass on the latest commit.
- Critical queue/account-isolation behavior needs automated regression tests.
- Live Firebase Realtime Database and Storage Rules must be reviewed and verified; repository templates are not proof of deployment.
- Production release signing is BLOCKED because the current release configuration uses debug signing.
- Device update, notification, widget, backup/restore and export tests remain outstanding.
- Full audit reports and release changelog must be finalized.

The existing main branch remains unchanged. Merge authorization is required after all gates pass.