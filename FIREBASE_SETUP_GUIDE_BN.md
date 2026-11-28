# Firebase Setup & Security Rules Guide (বাংলা)

Firebase Project: `ot-diary-flutter`

এই Repository-তে `database.rules.json` এবং `storage.rules` নিরাপদ Rules Template হিসেবে রাখা হয়েছে। **এগুলো Firebase Console-এ Publish করা হয়নি।**

## আগে Backup নিন

1. Firebase Console খুলুন এবং `ot-diary-flutter` Project নির্বাচন করুন।
2. Realtime Database → Rules-এ বর্তমান Rules সম্পূর্ণ Copy করে নিরাপদে রাখুন।
3. Storage → Rules-এ বর্তমান Rules Copy করে রাখুন।
4. আপনার Project-এ অন্য Data/Storage feature থাকলে নতুন Rules পুরোপুরি Replace না করে Merge ও Review করুন।

## Realtime Database Rules

1. Realtime Database → Rules খুলুন।
2. `database.rules.json` ফাইলের Rules JSON দেখুন।
3. নিশ্চিত করুন বর্তমান OT Diary data path `users/{uid}/profile` এবং `users/{uid}/ot/{yyyy_MM}/{day}` এর সঙ্গে সামঞ্জস্যপূর্ণ।
4. Review শেষে Publish করুন।

Rules অনুযায়ী প্রতিটি authenticated user শুধু নিজের `users/{uid}` path পড়তে/লিখতে পারবে। অন্য user-এর path এবং unauthenticated access বন্ধ থাকবে।

## Firebase Storage Rules

1. Build → Storage → Rules খুলুন।
2. `storage.rules`-এর profile-photo path rules Review/Merge করুন।
3. Profile photo upload path `users/{uid}/profile/avatar.ext`-এর সঙ্গে মিলিয়ে নিন।
4. Publish করুন।

Template-এ নিজ UID-এর profile photo access, JPEG/PNG/WebP MIME type এবং 5 MiB-এর কম upload size অনুমোদিত। Delete কেবল নিজস্ব UID path-এ অনুমোদিত।

## Rules Test Checklist

- Signed out: Database read/write denied.
- User A: `users/A/profile` read/write allowed.
- User A: `users/B/profile` read/write denied.
- User A: নিজের profile photo read/upload allowed.
- অন্য UID-এর profile photo access denied.
- 5 MiB বা তার বেশি / unsupported MIME upload denied.

**Publish সফল হয়েছে কি না Firebase Console-এ যাচাই না করে Security Rules কার্যকর হয়েছে বলে ঘোষণা করবেন না।**