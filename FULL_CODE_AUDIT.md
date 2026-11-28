# Full Code Audit — OT Diary 2.2.1

**Status:** Phase 0 preliminary audit; not a complete final audit  
**Audit baseline:** `feature/ot-diary-v2.2` at `04025cb156fb15b0f1f34ecb4e94a88a420f5345`  
**Working branch:** `fix/ot-diary-v2.2.1-stability`  
**Current working commit at this report:** `bd4e80fd4d8cb3eadd88ba53433d561342724bf1`

## Scope inspected

- Main and feature GitHub Actions workflows
- `pubspec.yaml`, Android Gradle, Manifest and app identity
- `DatabaseService`: local cache, pending queue, OT save/reset, profile/photo, import/export
- `ExtraTools`: backup snapshot/restore, OT validation, CSV/PDF
- Notification service
- MainActivity file picker channel and Android home-screen widget
- Home and Settings screen save/input flows
- Existing tests and Firebase client configuration

## Findings and disposition

| Finding | Severity | Status |
|---|---|---|
| Main build workflow deleted Android/iOS folders and regenerated the Android project | Critical | Fixed in working branch; existing project is retained |
| Feature CI had write permission, persistent checkout credentials, ZIP auto-apply and automatic source push | High | Fixed in working branch; committed source only, read-only permissions |
| Main workflow self-check matched its own destructive-command pattern and required 2.2.1 on the older main branch | High | Fixed in working branch |
| Malformed pending queue was silently converted to empty, risking loss of offline operations | Critical | Fixed in working branch: preserve original queue and fail explicitly |
| Pending sync could use mutable current UID during async work | High | Hardened in working branch: capture UID, validate queue path and bind photo sync |
| OT save service accepted invalid dates and non-finite/out-of-range hours | High | Fixed in working branch with central validation |
| Realtime Database rules were not tracked in the repository | High | Safe per-user rule template added; live deployment not verified |
| Storage example allowed broad `image/.*` MIME type | Medium | Narrow image type template added; live deployment not verified |
| Release build uses debug signing configuration | Critical for production | BLOCKED; production signing must not be claimed |
| Test suite is small and does not cover full offline/reboot/multi-account/device behavior | High | Open; tests still need expansion |
| Notification test scheduled for two minutes later is not yet verified/implemented | Medium | Open |
| Backup, restore, widget, UI, PDF, notification and account-switch flows need complete regression audit | High | Open |

## Data compatibility

Existing Firebase paths are unchanged:

- `users/{uid}/profile`
- `users/{uid}/ot/{yyyy_MM}/{day}`

No Firebase data migration or deletion has been performed. No live Firebase Rules have been published.

## Gate

**Production readiness: NO-GO.** See `MERGE_READINESS_REPORT.md`.