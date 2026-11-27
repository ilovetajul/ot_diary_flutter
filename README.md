# ⚡ OT Diary — Flutter App

আধুনিক ওভারটাইম ট্র্যাকার। Flutter, Firebase Authentication এবং Firebase Realtime Database ব্যবহার করে তৈরি।

## মূল ফিচার

- Firebase Authentication (লগইন/রেজিস্ট্রেশন)
- Firebase Realtime Database-এ User-specific OT ও Profile
- Local-first OT entry এবং Internet এলে automatic Firebase sync
- মাসে কতদিন ৩/৫/৭ ঘণ্টা বা অন্য OT duration হয়েছে তার breakdown
- Profile photo (local preview + Firebase Storage upload queue)
- নির্দিষ্ট সময়ে প্রতিদিনের OT reminder
- মাসিক Chart ও PDF report
- বাংলা UI

## Firebase data compatibility

পুরোনো Firebase paths অপরিবর্তিত:

- `users/{uid}/profile`
- `users/{uid}/ot/{yyyy_MM}/{day}`

পুরোনো profile field (`name`, `idNo`, `basic`, `allowance`, `rate`, `email`) রাখা হয়েছে। `photoUrl` নতুন optional field। কোনো automatic data migration বা deletion নেই।

## Firebase setup

`lib/firebase_options.dart`-এ বর্তমান Firebase project configuration রাখা আছে। Android build-এর জন্য এই configuration ব্যবহার হয়; এই Workflow-তে `google-services.json` Secret প্রয়োজন হয় না।

Profile photo cloud upload করতে Firebase Console-এ Storage Enable করুন এবং নিজের user-specific Storage Rules সেট করুন। Rules উদাহরণ `FIREBASE_STORAGE_RULES_EXAMPLE.md`-এ আছে।

Realtime Database Rules অবশ্যই এমন হতে হবে যাতে authenticated user শুধু নিজের `users/{uid}` node access করতে পারে। বিদ্যমান Rules না দেখে সেগুলো Replace করবেন না।

## Build

```bash
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter build apk --release
```

GitHub Actions `main`, `master`, এবং `feature/**` branch-এ APK build করে Artifact হিসেবে সংরক্ষণ করে। Workflow বিদ্যমান Android project মুছে বা নতুন করে তৈরি করে না; শুধু অনুপস্থিত Gradle wrapper files temporary Flutter template থেকে পূরণ করে এবং launcher icon generate করে।

## Offline data সতর্কতা

OT ও Profile প্রথমে local cache-এ সেভ হয় এবং pending sync queue-তে থাকে। Internet এলে Firebase-এ sync হয়। Offline অবস্থায় নতুন তথ্য যোগ করলে Sync শেষ হওয়ার আগে App Uninstall বা Clear Data করবেন না; এতে unsynced local cache মুছে যেতে পারে।

## Version

`2.1.0+2`
