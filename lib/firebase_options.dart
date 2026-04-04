// এই ফাইলটি FlutterFire CLI দিয়ে auto-generate হবে
// অথবা নিচের template ব্যবহার করুন এবং আপনার Firebase config বসান

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default: throw UnsupportedError('এই platform সাপোর্ট করে না');
    }
  }

  // ===== আপনার Firebase Console থেকে এই মানগুলো বসান =====
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT.appspot.com',
    authDomain: 'YOUR_PROJECT.firebaseapp.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT.appspot.com',
    iosBundleId: 'com.otdiary.app',
  );
}
