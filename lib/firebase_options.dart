// এই ফাইলটি FlutterFire CLI দিয়ে auto-generate হবে
// অথবা নিচের template ব্যবহার করুন এবং আপনার Firebase config বসান

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvJ0BDsTARpRWWgR68rNzlMyKTgeTPSMU',
    appId: '1:226972293146:android:72c952eab333f6d83b99a3',
    messagingSenderId: '226972293146',
    projectId: 'ot-diary-flutter',
    databaseURL: 'https://ot-diary-flutter-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ot-diary-flutter.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBy7iUo-a9tFavhW1An1xYN2ICDdzZz7oI',
    appId: '1:226972293146:web:41aa9d8a79df6f6b3b99a3',
    messagingSenderId: '226972293146',
    projectId: 'ot-diary-flutter',
    databaseURL: 'https://ot-diary-flutter-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'ot-diary-flutter.firebasestorage.app',
    authDomain: 'ot-diary-flutter.firebaseapp.com',
  );
}
