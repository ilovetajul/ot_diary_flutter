# Test Report — OT Diary 2.2.1

## Last known successful baseline

- GitHub Actions Run #30: PASS at commit `04025cb156fb15b0f1f34ecb4e94a88a420f5345`.
- Run #30 steps included dependency setup, Analyze, existing unit/widget tests, debug APK build/upload and release-mode APK build/upload.
- Run #30 is a baseline result only; it does not validate the new 2.2.1 changes.

## Stability branch runs

| Run | Commit | Result |
|---|---|---|
| #31 | `9c6b21c7...` | In progress/obsolete at report time |
| #32 | `1cfa51df...` | FAIL — duplicate `getProfile` analyzer error |
| #33 | `ce779d74...` | FAIL — same duplicate declaration |
| #34 | `c6d820e4...` | FAIL — same duplicate declaration |
| #35 | `bd4e80fd...` | In progress; latest source after duplicate removal |

Run #35 must complete before marking Analyze, tests or APK builds as PASS.

## Not tested yet

- Real Android phone installation/update and signing certificate continuity
- Firebase Emulator/Rules simulator
- Offline save/edit/delete after force-stop and reboot
- Reconnection and multi-device conflict resolution
- Account logout/switch during queued writes and photo upload
- Notification delivery/reboot/battery behavior
- Widget account/month rollover
- Full backup/restore and Bengali PDF layout on device

No live Firebase production data was used for testing.