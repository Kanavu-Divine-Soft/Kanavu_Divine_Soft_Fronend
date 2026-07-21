import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/widgets/custom_notification_dialog.dart';
import 'package:temple_onboarding/presentation/screens/main_layout_screen.dart';
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
  String _selectedLanguage = 'English';

  final Map<String, Map<String, String>> _translations = {
    'English': {
      'title': 'Kanavu Divine Soft',
      'subtitle': 'Enterprise Management Portal',
      'signIn': 'Sign In',
      'signInSubtitle': 'Please enter your credentials to continue',
      'usernameLabel': 'Username or Email',
      'passwordLabel': 'Password',
      'forgotPassword': 'Forgot Password?',
      'loginBtn': 'LOGIN',
      'validationError': 'Validation Error',
      'validationUsername': 'Please enter your username or email.',
      'validationPassword': 'Please enter your password.',
      'validationPasswordLength': 'Password must be at least 8 characters.',
      'loginError': 'Login Error',
      'loginFailed': 'Login failed',
      'error': 'Error',
      'connectionError': 'Connection Error',
      'connectionErrorMsg': 'Unable to connect to the server. Please ensure the backend server is running and accessible.',
      'unexpectedError': 'An unexpected error occurred. Please try again.',
      'hintUsername': 'Enter your Username or Email',
      'hintPassword': 'Enter your Password',
    },
    'Tamil': {
      'title': 'கனவு டிவைன் சாப்ட்',
      'subtitle': 'நிறுவன மேலாண்மை போர்டல்',
      'signIn': 'உள்நுழைக',
      'signInSubtitle': 'தொடர உங்கள் உள்நுழைவு விவரங்களை உள்ளிடவும்',
      'usernameLabel': 'பயனர்பெயர் அல்லது மின்னஞ்சல்',
      'passwordLabel': 'கடவுச்சொல்',
      'forgotPassword': 'கடவுச்சொல் மறந்துவிட்டதா?',
      'loginBtn': 'உள்நுழைக',
      'validationError': 'சரிபார்ப்பு பிழை',
      'validationUsername': 'உங்கள் பயனர்பெயர் அல்லது மின்னஞ்சலை உள்ளிடவும்.',
      'validationPassword': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்.',
      'validationPasswordLength': 'கடவுச்சொல் குறைந்தது 8 எழுத்துகளைக் கொண்டிருக்க வேண்டும்.',
      'loginError': 'உள்நுழைவு பிழை',
      'loginFailed': 'உள்நுழைவு தோல்வியடைந்தது',
      'error': 'பிழை',
      'connectionError': 'தொடர்பு பிழை',
      'connectionErrorMsg': 'சேவையகத்துடன் இணைக்க முடியவில்லை. பின்தள சேவையகம் இயங்குகிறதா என்பதை உறுதிப்படுத்தவும்.',
      'unexpectedError': 'எதிர்பாராத பிழை ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.',
      'hintUsername': 'உங்கள் பயனர்பெயர் அல்லது மின்னஞ்சலை உள்ளிடவும்',
      'hintPassword': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
    },
  };

  String _t(String key) => _translations[_selectedLanguage]![key] ?? key;

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
        title: _t('validationError'),
        message: _t('validationUsername'),
        type: NotificationType.error,
      );
      return;
    }

    if (password.isEmpty) {
      CustomNotificationDialog.show(
        context,
        title: _t('validationError'),
        message: _t('validationPassword'),
        type: NotificationType.error,
      );
      return;
    }

    if (password.length < 8) {
      CustomNotificationDialog.show(
        context,
        title: _t('validationError'),
        message: _t('validationPasswordLength'),
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
              builder: (context) => MainLayoutScreen(userData: data['user']),
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
          title: _t('loginError'),
          message: data['detail'] ?? _t('loginFailed'),
          type: NotificationType.error,
        );
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      if (!mounted) return;
      
      String errorMessage = _t('unexpectedError');
      String errorTitle = _t('error');
      
      if (e is http.ClientException || e.toString().contains('Failed to fetch') || e.toString().contains('Connection refused')) {
        errorTitle = _t('connectionError');
        errorMessage = _t('connectionErrorMsg');
      } else {
        errorMessage = '${_t('error')}: $e';
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
      body: Stack(
        children: [
          isDesktop
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
                          Text(
                            _t('title'),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _t('subtitle'),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
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
                          Text(
                            _t('title'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            textAlign: TextAlign.center,
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
          Positioned(
            top: 24,
            right: 32,
            child: _buildLanguageSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final isEnglish = _selectedLanguage == 'English';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLanguage = isEnglish ? 'Tamil' : 'English';
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD1D5DB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 18, color: Color(0xFFE40000)), // Kanavu Red
              const SizedBox(width: 8),
              Text(
                isEnglish ? 'English' : 'தமிழ் (Tamil)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.sync_alt, size: 16, color: Color(0xFF9CA3AF)),
            ],
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
            Text(
              _t('signIn'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827), // Dark Gray
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Text(
              _t('signInSubtitle'),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // Medium Gray
              ),
            ),
            const SizedBox(height: 40),
            _buildTextField(
              controller: _identifierController,
              label: _t('usernameLabel'),
              hintText: _t('hintUsername'),
              icon: Icons.person_outline_rounded,
              maxLength: 254,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _passwordController,
              label: _t('passwordLabel'),
              hintText: _t('hintPassword'),
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
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
                child: Text(
                  _t('forgotPassword'),
                  style: const TextStyle(
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
                    : Text(
                        _t('loginBtn'),
                        style: const TextStyle(
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
    String? hintText,
    bool isPassword = false,
    bool obscureText = false,
    int? maxLength,
    VoidCallback? onTogglePassword,
    ValueChanged<String>? onFieldSubmitted,
    TextInputAction? textInputAction,
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
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
          style: const TextStyle(color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter your $label',
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
