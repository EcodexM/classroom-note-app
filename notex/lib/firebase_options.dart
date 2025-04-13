// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web. '
      'Reconfigure with FlutterFire CLI for other platforms.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCmSqAGNaGk6ZHVOb9sp0-9h55F-zk0A4k",
    appId: "1:164778924929:web:9348c0bd3623bf0999a680",
    messagingSenderId: "164778924929",
    projectId: "software-engi-project",
    authDomain: "software-engi-project.firebaseapp.com",
    storageBucket: "software-engi-project.appspot.com",
    measurementId: "G-NQ2MK80RMD",
  );
}
