import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/screens/login_screen.dart';
import 'package:temple_onboarding/presentation/screens/dashboard_screen.dart';
import 'package:temple_onboarding/presentation/screens/temple_member_details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String? userDataString = prefs.getString('user_data');
  Map<String, dynamic>? userData;
  
  if (userDataString != null) {
    try {
      userData = jsonDecode(userDataString);
    } catch (e) {
      userData = null;
    }
  }

  runApp(MyApp(userData: userData));
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? userData;
  
  const MyApp({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanavu Divine Soft',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE40000),
          primary: const Color(0xFFE40000),
          secondary: const Color(0xFFB30000),
        ),
        useMaterial3: true,
      ),
      home: _getHome(),
    );
  }

  Widget _getHome() {
    if (userData == null) return const LoginScreen();
    
    if (userData!['role'] == 'Super Admin') {
      return DashboardScreen(userData: userData!);
    } else {
      return const TempleMemberDetailsScreen();
    }
  }
}
