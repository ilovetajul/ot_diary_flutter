# Feature branch verification

The `feature/modern-ot-diary` branch uses `.github/workflows/feature-ci.yml` to run Flutter dependency resolution, static analysis, tests, and a debug APK build without recreating or deleting the Android project.

The generated APK is uploaded as the `OT-Diary-feature-debug-apk` Actions artifact when the workflow succeeds.
