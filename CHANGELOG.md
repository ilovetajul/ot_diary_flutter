# Changelog

## 2.2.0 — Tools update (pending CI/device verification)
- Calendar, quick entry, holidays and configurable monthly target.
- Light/dark palette, password reset, CSV, Bengali PDF and annual summary.
- JSON backup and non-destructive OT restore, Android home widget.


## 2.1.0 — Modern OT Diary Patch

### Added
- Material 3 inspired modern dark UI
- Monthly OT duration distribution (hours → number of days)
- Profile photo selection and local preview
- Firebase Storage upload queue for profile photo
- Local-first OT and profile writes
- Durable per-user pending Firebase sync queue
- Realtime Database disk persistence initialization
- Daily configurable OT reminder with Dhaka timezone
- Reminder rescheduling after device reboot
- OT analytics unit tests
- Updated GitHub Actions workflow that preserves the existing Android project

### Fixed / Improved
- Emptying a daily OT field now queues a Firebase delete
- Profile edit validation for non-negative numeric values
- Existing Firebase user and OT paths preserved
- Import merges OT day entries rather than replacing the whole OT node
- Removed unnecessary Exact Alarm permissions for inexact reminders
- Removed CI step that deleted and regenerated the Android project

### Data compatibility
- Existing profile fields remain unchanged.
- `photoUrl` is an optional additive profile field.
- Existing OT path remains `users/{uid}/ot/{yyyy_MM}/{day}`.
- No automatic Firebase data deletion or migration is performed.
