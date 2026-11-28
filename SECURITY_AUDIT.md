# Security Audit — OT Diary 2.2.1

**Status:** Preliminary; live Firebase configuration is not accessible/verified from this repository workflow.

## High severity

1. **Production signing is blocked.** `android/app/build.gradle` currently uses `signingConfigs.debug` for the release build. Do not distribute this artifact as a production release or overwrite an installed app using a mismatched certificate.
2. **Realtime Database Rules are not tracked.** The app stores data below `users/{uid}`. A UID-matching rule template is provided in `database.rules.json`. It must be reviewed and published in the Firebase Console.
3. **Account isolation must be confirmed against live rules and multi-account tests.** Source-side queue/sync UID binding was hardened, but live rules and device-level account-switch behavior remain unverified.

## Medium severity

- The prior Storage example accepted any `image/.*` content type. The new `storage.rules` template restricts profile uploads to JPEG, PNG or WebP and less than 5 MiB, with authenticated UID ownership.
- Firebase client configuration contains client API keys. These are not server credentials; restrict them with appropriate API settings and rely on Firebase Authentication and Security Rules for data access.
- Offline pending queue parsing now preserves malformed persisted content and reports an error rather than clearing it.

## Permissions and secrets

- Updated CI uses `permissions: contents: read`.
- Checkout uses `persist-credentials: false`.
- No keystore or private signing credential was added to the repository.
- No live Firebase Rules deployment was performed.

## Required before production

- Verify database and storage rules in Firebase Console.
- Run rules simulator checks for unauthenticated and cross-UID access.
- Verify existing APK signing certificate and configure private release signing.
- Complete account-switch, offline queue, restore and device regression tests.

**Security gate: NO-GO until the above is verified.**