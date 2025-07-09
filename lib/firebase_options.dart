import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // To use new options, change 'android' to 'androidNew'
        return androidNew;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjFC-lW5KvktLp589ax1Xf0bYwkOjkrzY',
    appId: '1:633961256537:web:your_web_app_id',
    messagingSenderId: '633961256537',
    projectId: 'yoga-c673e',
    authDomain: 'yoga-c673e.firebaseapp.com',
    storageBucket: 'yoga-c673e.appspot.com',
    databaseURL: 'https://yoga-c673e-default-rtdb.firebaseio.com',
  );

  // Existing Android options
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjFC-lW5KvktLp589ax1Xf0bYwkOjkrzY',
    appId: '1:633961256537:android:c96efe2965d8977728c348',
    messagingSenderId: '633961256537',
    projectId: 'yoga-c673e',
    storageBucket: 'yoga-c673e.appspot.com',
    databaseURL: 'https://yoga-c673e-default-rtdb.firebaseio.com',
  );

  // New Android options based on provided JSON data
  static const FirebaseOptions androidNew = FirebaseOptions(
    apiKey: 'AIzaSyDWynNTCIUdE9f5JlGJvf4ZorzPjvnsBS8',
    appId: '1:925990855330:android:57edb01e86e5139c0fadfb',
    messagingSenderId: '925990855330',
    projectId: 'yogaugam-92534',
    storageBucket: 'yogaugam-92534.firebasestorage.app',
    databaseURL: 'https://yogaugam-92534-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your_ios_api_key',
    appId: '1:633961256537:ios:your_ios_app_id',
    messagingSenderId: '633961256537',
    projectId: 'yoga-c673e',
    storageBucket: 'yoga-c673e.appspot.com',
    databaseURL: 'https://yoga-c673e-default-rtdb.firebaseio.com',
  );
}
