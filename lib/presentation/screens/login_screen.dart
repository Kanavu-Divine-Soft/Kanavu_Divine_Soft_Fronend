import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/widgets/custom_notification_dialog.dart';
import 'package:temple_onboarding/presentation/screens/dashboard_screen.dart';
import 'package:temple_onboarding/presentation/screens/temple_member_details_screen.dart';
import 'package:temple_onboarding/presentation/screens/forgot_password_screen.dart';
import 'package:temple_onboarding/core/api_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Initialize as late to ensure they are set in initState
  late TextEditingController _identifierController;
  late TextEditingController _passwordController;
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      CustomNotificationDialog.show(
        context,
        title: 'Validation Error',
        message: 'Please enter your username or email.',
        type: NotificationType.error,
      );
      return;
    }

    if (password.isEmpty) {
      CustomNotificationDialog.show(
        context,
        title: 'Validation Error',
        message: 'Please enter your password.',
        type: NotificationType.error,
      );
      return;
    }

    if (password.length < 8) {
      CustomNotificationDialog.show(
        context,
        title: 'Validation Error',
        message: 'Password must be at least 8 characters.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Attempting login for: ${_identifierController.text}');
      
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': _identifierController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        
        // Save session to persist after refresh
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        await prefs.setString('user_system', data['system'] ?? 'temple');
        
        if (!mounted) return;

        if (data['user']['role'] == 'Super Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userData: data['user']),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TempleMemberDetailsScreen(),
            ),
          );
        }
      } else {
        if (!mounted) return;
        CustomNotificationDialog.show(
          context,
          title: 'Login Error',
          message: data['detail'] ?? 'Login failed',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      if (!mounted) return;
      
      String errorMessage = 'An unexpected error occurred. Please try again.';
      String errorTitle = 'Error';
      
      if (e is http.ClientException || e.toString().contains('Failed to fetch') || e.toString().contains('Connection refused')) {
        errorTitle = 'Connection Error';
        errorMessage = 'Unable to connect to the server. Please ensure the backend server is running and accessible.';
      } else {
        errorMessage = 'An unexpected error occurred: $e';
      }

      CustomNotificationDialog.show(
        context,
        title: errorTitle,
        message: errorMessage,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // ERP Light Gray Background
      body: isDesktop
          ? Row(
              children: [
                // Left Panel: Branding
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFFE40000), // Kanavu Red
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                'assets/images/kanavu-logo-1.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Kanavu Divine Soft',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Enterprise Management Portal',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right Panel: Form
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 64.0),
                        child: _buildLoginForm(context),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              // Mobile / Tablet Layout
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE40000), width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                'assets/images/kanavu-logo-1.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Kanavu Divine Soft',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildLoginForm(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827), // Dark Gray
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your credentials to continue',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // Medium Gray
              ),
            ),
            const SizedBox(height: 40),
            _buildTextField(
              controller: _identifierController,
              label: 'Username or Email',
              icon: Icons.person_outline_rounded,
              maxLength: 254,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscurePassword,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFFE40000),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE40000),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    int? maxLength,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
          style: const TextStyle(color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)), // Light gray border
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE40000), width: 2), // Red focus border
            ),
          ),
        ),
      ],
    );
  }
}
