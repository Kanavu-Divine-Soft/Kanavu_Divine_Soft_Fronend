import 'package:flutter/foundation.dart';

class ApiConstants {
  // Update this IP address to your computer's local IP (or 10.0.2.2 for Android Emulator)
  static String get baseUrl {
    if (kIsWeb) {
      if (kReleaseMode) {
        return 'https://kanavu-divine-soft-backend-33om.onrender.com'; // Live Server
      } else {
        return 'http://127.0.0.1:8005'; // Local Server
      }
    } else {
      return 'http://192.168.68.110:8005';
    }
  }
}
