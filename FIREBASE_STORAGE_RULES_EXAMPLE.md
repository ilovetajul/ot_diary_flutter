# Firebase Storage Rules — Profile Photo

এই Rules কেবল OT Diary-এর user profile photo path-এর উদাহরণ।

Firebase Console → Build → Storage → Rules-এ বর্তমান Rules দেখে প্রয়োজনীয় অংশ merge করুন। অন্য কোনো Storage feature থাকলে পুরো Rules replace করবেন না।

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/profile/{fileName} {
      allow read: if request.auth != null
                  && request.auth.uid == userId;

      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && request.resource != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

## নোট

- User কেবল নিজের profile photo path-এ read/write করতে পারে।
- সর্বোচ্চ ফাইল সাইজ ৫ MB।
- শুধু image MIME type গ্রহণ করা হয়।
- Firebase Storage চালু না থাকলে বা Rules অনুমতি না দিলে ছবি ফোনে থাকবে এবং Upload pending থাকবে।
- Realtime Database-এর Rules এই ফাইল দিয়ে পরিবর্তন করা হচ্ছে না।
