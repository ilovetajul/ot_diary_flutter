# Security Audit — OT Diary 2.2.1

**Status:** Preliminary source/configuration review; live Firebase configuration not verified  
**CI-validated source commit:** `993d4ff505c3bdc18fd2ca51eb28e047ebb6eda2`

## High severity

1. **Production signing is blocked.** `android/app/build.gradle` uses `signingConfigs.debug` for the release build. The release-mode APK built successfully in Run #37 but is debug-signed; it is only for test installation.
2. **Realtime Database Rules must be published and verified.** The app stores data below `users/{uid}`. The repository's `database.rules.json` is a UID-matching template, not proof of deployed rules.
3. **Account isolation needs live-rule and multi-account tests.** Source-side queue/sync UID binding was hardened, but live Rules and physical account-switch behavior remain unverified.

## Medium severity

- Storage template restricts profile uploads to JPEG/PNG/WebP and less than 5 MiB, with authenticated UID ownership. Existing live rules were not inspected or changed.
- Firebase client API keys are client configuration, not server credentials; restrict APIs appropriately and enforce access through Firebase Authentication and Rules.
- Malformed pending queue data is preserved and reports an error rather than being silently cleared.

## CI and credentials

- Feature CI uses `permissions: contents: read`.
- Checkout uses `persist-credentials: false`.
- CI consumes committed source only; it does not auto-apply ZIP patches or push source.
- No private keystore or signing secret was committed.
- Run #37 passed the CI security/build workflow, but this is not a penetration test or Firebase Rules simulation.

## Required before production

- Review and publish database/storage Rules in Firebase Console.
- Use Rules Simulator for unauthenticated and cross-UID access.
- Verify existing app signing certificate and configure private release signing.
- Complete account-switch, offline queue, restore and device regression tests.

**Security gate: NO-GO until the above is verified.**
