# OT Diary 2.1 — Patch ও ইনস্টল গাইড (বাংলা)

## গুরুত্বপূর্ণ: GitHub Branch এখনো তৈরি হয়নি

এই কাজের জন্য প্রস্তাবিত Branch:

`feature/modern-ot-diary`

বর্তমান GitHub সংযোগে Repository read access আছে, কিন্তু Branch/Contents write permission নেই। তাই `main`-এ কোনো পরিবর্তন করা হয়নি এবং এই ZIP হলো **changed/new files patch**। GitHub-এ নতুন Branch তৈরি করে তারপর ZIP-এর ফাইলগুলো সেই Branch-এ আপলোড করতে হবে।

## ১. Firebase ডেটা সুরক্ষার নীতি

পুরোনো Firebase path অপরিবর্তিত রাখা হয়েছে:

- Profile: `users/{uid}/profile`
- OT: `users/{uid}/ot/{yyyy_MM}/{day}`

পুরোনো Profile field অপরিবর্তিত:

- `name`
- `idNo`
- `basic`
- `allowance`
- `rate`
- `email`

শুধু একটি নতুন ঐচ্ছিক field যোগ হয়েছে:

- `photoUrl`

পুরোনো ব্যবহারকারীর Profile-এ `photoUrl` না থাকলেও অ্যাপ চলবে। কোনো পুরোনো OT node বা Firebase user node migrate/delete করার কোড যোগ করা হয়নি।

## ২. নতুন Branch তৈরি

1. GitHub-এ `ilovetajul/ot_diary_flutter` Repository খুলুন।
2. Branch selector থেকে `main` নির্বাচন করুন।
3. Branch selector খুলে `View all branches` / `New branch` নির্বাচন করুন।
4. Branch name দিন: `feature/modern-ot-diary`
5. Source branch হিসেবে `main` নির্বাচন করে Branch তৈরি করুন।
6. নিশ্চিত করুন উপরে Branch হিসেবে `feature/modern-ot-diary` দেখা যাচ্ছে।

## ৩. ZIP আপলোড

1. ZIP Extract করুন।
2. Extract করা ফোল্ডারের ভিতরের ফাইলগুলো Repository root-এর একই path-এ বসান।
3. GitHub-এ নতুন Branch নির্বাচন করা অবস্থায় `Add file → Upload files` ব্যবহার করুন।
4. একই path-এর পুরোনো ফাইল Replace করুন এবং নতুন ফাইলগুলো Add করুন।
5. Commit message দিন: `Modern OT Diary UI, offline sync and profile photo`
6. Commit অবশ্যই `feature/modern-ot-diary` Branch-এ করুন; `main`-এ নয়।

ZIP-এ শুধু পরিবর্তিত/নতুন ফাইল রাখা হয়েছে। মূল Repository-এর অন্য ফাইল মুছবেন না।

## ৪. নতুন ফিচার

### আধুনিক UI/UX
- নতুন Dashboard ও Material 3 Navigation
- OT, OT দিন, OT আয় ও Salary summary
- উন্নত দৈনিক OT entry list
- Profile avatar ও নতুন Settings layout

### OT Duration Breakdown
এক মাসে কতদিন ৩ ঘণ্টা, ৫ ঘণ্টা, ৭ ঘণ্টা বা অন্য কোনো সময় OT হয়েছে, তা আলাদা group-এ দেখাবে। যেমন:

- ৩ ঘণ্টা — ৫ দিন
- ৫ ঘণ্টা — ৪ দিন
- ৭ ঘণ্টা — ২ দিন

দশমিক OT-ও দুই ঘর পর্যন্ত আলাদা group হিসেবে দেখানো হয়।

### Daily Notification
- ব্যবহারকারী নিজের সুবিধামতো সময় বেছে নিতে পারবেন।
- প্রতিদিন পুনরাবৃত্ত রিমাইন্ডার আসবে।
- Notification text: “আজ কত ঘণ্টা OT করেছেন? OT Diary খুলে আজকের হিসাব লিখে রাখুন।”
- ফোন Restart হলে সংরক্ষিত সময় অনুযায়ী আবার Schedule হবে।
- Inexact alarm ব্যবহার করা হয়েছে; Exact Alarm permission আর প্রয়োজন নেই।

### Profile Photo
- Gallery থেকে ছবি নির্বাচন করা যাবে।
- ছবিটি প্রথমে ফোনের App Documents-এ কপি হবে।
- Internet না থাকলে স্থানীয় ছবিটি দেখা যাবে এবং Upload pending থাকবে।
- Internet এলে Firebase Storage-এ Upload করে Realtime Database-এর `photoUrl` field আপডেট করবে।

## ৫. Offline ও Firebase Sync

- OT entry প্রথমে SharedPreferences local cache-এ লেখা হয়।
- একই সঙ্গে একটি per-user pending sync queue তৈরি হয়।
- Firebase Realtime Database persistence চালু করা হয়েছে।
- Connection ফিরে এলে queue-র write/remove operation একে একে Firebase-এ পাঠানো হয়।
- Profile update-ও local-first।
- Logout করলে per-user local cache বা pending queue মুছে ফেলা হয় না।

**সতর্কতা:** কোনো ডিভাইস Offline থাকা অবস্থায় নতুন OT যোগ করলে সেটি Sync সম্পন্ন হওয়ার আগে অ্যাপ Uninstall/Clear Data করবেন না। Uninstall করলে ফোনের local pending data মুছে যেতে পারে। আগে Internet চালু করে Sync সম্পন্ন করুন।

## ৬. Firebase Storage চালু করা

Profile photo Cloud-এ পাঠাতে Firebase Console-এ:

1. Firebase Project `ot-diary-flutter` খুলুন।
2. Build → Storage খুলুন।
3. Firebase Storage এখনো চালু না থাকলে Enable করুন।
4. Rules-এ নিচের উদাহরণ অনুযায়ী নিজের বর্তমান Rules-এর সঙ্গে মিলিয়ে User-specific access দিন।

সম্পূর্ণ উদাহরণ এই ZIP-এর `FIREBASE_STORAGE_RULES_EXAMPLE.md` ফাইলে আছে।

**গুরুত্বপূর্ণ:** আপনার বর্তমান Storage Rules-এ অন্য কোনো feature থাকলে পুরো Rules replace করবেন না; প্রয়োজনীয় match block merge করুন।

## ৭. Firebase Realtime Database Rules

এই Patch আপনার Realtime Database Rules পরিবর্তন করে না। বর্তমান Rules অবশ্যই যাচাই করুন যাতে:

- Login ছাড়া User data read/write করা না যায়।
- `auth.uid` শুধু নিজের `users/{uid}` node access করতে পারে।
- অন্য User-এর OT বা Profile পড়া/পরিবর্তন করা না যায়।

বর্তমান Rules না দেখে সেগুলো Replace করা নিরাপদ নয়।

## ৮. Build ও Test

GitHub Actions-এ নতুন Branch-এ Commit করলে Workflow চালু হবে।

Workflow:
1. `flutter pub get`
2. Gradle wrapper files ও launcher icon প্রস্তুত
3. `flutter analyze`
4. `flutter test`
5. Android release APK build
6. APK artifact upload

লোকাল Flutter environment থাকলে:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter build apk --release
```

এই ZIP তৈরি করার পরিবেশে Flutter SDK/Android SDK নেই। তাই এখানে APK Build চালানো হয়নি। GitHub Actions-এর ফলাফল দেখে Build সফল কি না নিশ্চিত করবেন।

## ৯. ইনস্টল ও ডেটা যাচাই

প্রথমে একটি বিদ্যমান অ্যাকাউন্টে নতুন APK ইনস্টল/Update করে যাচাই করুন:

- পুরোনো Email/Password দিয়ে Login হচ্ছে কি না
- আগের Profile name, ID, Basic, Allowance, OT Rate ঠিক আছে কি না
- আগের মাসগুলোর OT অক্ষত আছে কি না
- ৩/৫/৭ ঘণ্টার OT count সঠিক কি না
- Offline অবস্থায় একটি Test OT entry সেভ হচ্ছে কি না
- Internet চালু করলে Firebase-এ নতুন entry যাচ্ছে কি না
- Daily reminder নির্বাচিত সময়ে আসছে কি না
- Profile photo local preview এবং Storage upload হচ্ছে কি না

প্রথম পরীক্ষায় `মাস রিসেট` ব্যবহার করবেন না।

## ১০. Firebase Storage Rules উদাহরণ

`FIREBASE_STORAGE_RULES_EXAMPLE.md` দেখুন।

## ১১. বর্তমান সীমাবদ্ধতা

- GitHub Branch এই মুহূর্তে এই সংযোগ থেকে তৈরি করা যায়নি; write permission প্রয়োজন।
- Firebase Storage Enable/Rules আপনার Firebase Console-এ নিশ্চিত করতে হবে।
- GitHub Actions সফল না হওয়া পর্যন্ত APK Build Verified বলা যাবে না।
- Existing Realtime Database Rules না দেখে সেগুলো পরিবর্তন করা হয়নি।
