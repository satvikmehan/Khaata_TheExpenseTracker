// Template for FirebaseOptions.
// To generate your actual configuration, run: flutterfire configure
// Or copy this file to lib/firebase_options.dart and replace with your project values.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    authDomain: 'your-firebase-project.firebaseapp.com',
    storageBucket: 'your-firebase-project.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    storageBucket: 'your-firebase-project.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: '1:000000000000:windows:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    authDomain: 'your-firebase-project.firebaseapp.com',
    storageBucket: 'your-firebase-project.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    storageBucket: 'your-firebase-project.appspot.com',
    iosBundleId: 'com.satvik.expensetracker',
  );
}
