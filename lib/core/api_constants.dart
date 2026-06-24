import 'package:flutter/foundation.dart';

class ApiConstants {
  // Update this IP address to your computer's local IP (or 10.0.2.2 for Android Emulator)
  static String get baseUrl {
    if (kIsWeb) {
      return 'https://kanavu-divine-soft.netlify.app';
    } else {
      return 'http://192.168.68.110:8005';
    }
  }
}
