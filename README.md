# ⚡ OT Diary — Flutter App

Flutter দিয়ে তৈরি OT ট্র্যাকার অ্যাপ। GitHub Actions দিয়ে APK auto-build হয়।

## ✨ ফিচার
- 🔐 Firebase Authentication (লগইন/রেজিস্ট্রেশন)
- ☁️ Firebase Realtime Database (ক্লাউড ব্যাকআপ)
- 🔔 Daily Notification Reminder
- 📄 PDF মাসিক রিপোর্ট
- 📊 Chart/গ্রাফ দেখুন
- 🏠 Home Screen Widget (শীঘ্রই)

---

## 🚀 GitHub Actions দিয়ে APK বানানো

### ধাপ ১ — firebase_options.dart ঠিক করুন
`lib/firebase_options.dart` ফাইলে আপনার Firebase config বসান।

### ধাপ ২ — google-services.json Secret যোগ করুন

Firebase Console → Project Settings → Android App → `google-services.json` ডাউনলোড করুন।

তারপর GitHub Repository তে:
```
Settings → Secrets and variables → Actions → New repository secret
Name:  GOOGLE_SERVICES_JSON
Value: (google-services.json এর সম্পূর্ণ কন্টেন্ট paste করুন)
```

### ধাপ ৩ — Push করুন

```bash
git add .
git commit -m "Flutter OT Diary"
git push origin main
```

### ধাপ ৪ — APK ডাউনলোড করুন

GitHub → Actions ট্যাব → সর্বশেষ workflow → Artifacts → ডাউনলোড করুন ✅

---

## 📁 প্রজেক্ট স্ট্রাকচার

```
lib/
├── main.dart
├── app_theme.dart
├── firebase_options.dart       ← আপনার config এখানে
├── models/
│   └── user_profile.dart
├── services/
│   ├── database_service.dart   ← Firebase + Local
│   ├── notification_service.dart
│   └── pdf_service.dart
└── screens/
    ├── splash_screen.dart
    ├── auth_screen.dart
    ├── home_screen.dart
    ├── chart_screen.dart
    └── settings_screen.dart
```

---

## 🔥 Firebase Android App যোগ করুন

Firebase Console → Project Settings → Add app → Android:
- Package name: `com.otdiary.app`
- `google-services.json` ডাউনলোড করুন
- GitHub Secret এ বসান (উপরে দেখুন)
