import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:temple_onboarding/presentation/widgets/custom_notification_dialog.dart';
import 'package:temple_onboarding/core/api_constants.dart';
import 'package:temple_onboarding/presentation/widgets/custom_dropdown_search.dart';

class EditAdminScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const EditAdminScreen({super.key, required this.adminData});

  @override
  State<EditAdminScreen> createState() => _EditAdminScreenState();
}

class _EditAdminScreenState extends State<EditAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _godNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _addressController;
  late TextEditingController _reasonController;
  late String _selectedRole;
  late String _selectedStatus;
  late String _selectedReason;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final GlobalKey<FormFieldState> _mobileFieldKey = GlobalKey<FormFieldState>();
  final LayerLink _layerLink = LayerLink();
  bool _isCountryDropdownOpen = false;
  OverlayEntry? _countryOverlayEntry;
  late Country _selectedCountry;

  // Tables dropdown state
  String? _selectedTable;

  Timer? _debounceTimer;
  bool _isCheckingMobile = false;
  String? _mobileTakenError;

  void _onMobileChanged() {
    if (mounted) setState(() {});
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    final mobileText = _mobileNumberController.text.replaceAll(' ', '').trim();
    if (mobileText.isEmpty) {
      setState(() => _mobileTakenError = null);
      return;
    }
    
    bool isMobileValid = mobileText.length >= _selectedCountry.minLength && 
                          mobileText.length <= _selectedCountry.maxLength;
    if (isMobileValid && _selectedCountry.code == 'IN') {
      isMobileValid = RegExp(r'^[6-9]').hasMatch(mobileText);
    }
    
    if (isMobileValid) {
      _debounceTimer = Timer(const Duration(milliseconds: 600), _checkMobileNumber);
    } else {
      setState(() => _mobileTakenError = null);
    }
  }

  Future<void> _checkMobileNumber() async {
    final mobileText = _mobileNumberController.text.replaceAll(' ', '').trim();
    if (mobileText.isEmpty) return;

    final fullMobile = '+${_selectedCountry.dialCode} $mobileText';
    
    setState(() => _isCheckingMobile = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/check_mobile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile_number': fullMobile,
          'exclude_id': widget.adminData['id'],
          'exclude_is_super': widget.adminData['role'] == 'Super Admin'
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['is_taken'] == true) {
          setState(() => _mobileTakenError = 'This mobile number is already registered.');
        } else {
          setState(() => _mobileTakenError = null);
        }
        _mobileFieldKey.currentState?.validate();
      }
    } catch (e) {
      // Ignore network errors here to avoid spamming the user
    } finally {
      if (mounted) {
        setState(() => _isCheckingMobile = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.adminData['name'] ?? '');
    _emailController = TextEditingController(text: widget.adminData['email'] ?? '');
    _passwordController = TextEditingController();
    _godNameController = TextEditingController(text: widget.adminData['god_name'] ?? '');
    _contactPersonController = TextEditingController(text: widget.adminData['contact_person'] ?? '');
    _selectedCountry = countries.firstWhere((c) => c.code == 'IN');
    String initialMobile = widget.adminData['mobile_number']?.toString() ?? '';
    if (initialMobile.startsWith('+')) {
      int spaceIdx = initialMobile.indexOf(' ');
      if (spaceIdx != -1) {
        String dialCode = initialMobile.substring(1, spaceIdx);
        try {
          _selectedCountry = countries.firstWhere((c) => c.dialCode == dialCode);
        } catch (_) {}
        initialMobile = initialMobile.substring(spaceIdx + 1);
      } else {
        var sortedCountries = List<Country>.from(countries)..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
        for (var c in sortedCountries) {
          if (initialMobile.startsWith('+${c.dialCode}')) {
            _selectedCountry = c;
            initialMobile = initialMobile.substring(c.dialCode.length + 1);
            break;
          }
        }
      }
    }
    initialMobile = initialMobile.replaceAll(' ', '');
    if (initialMobile.length > 5) {
      initialMobile = '${initialMobile.substring(0, 5)} ${initialMobile.substring(5)}';
    }
    _mobileNumberController = TextEditingController(text: initialMobile);
    _mobileNumberController.addListener(_onMobileChanged);
    _addressController = TextEditingController(text: widget.adminData['address'] ?? '');
    _reasonController = TextEditingController();
    _selectedRole = 'Admin';
    _selectedStatus = widget.adminData['status'] ?? 'Active';
    _selectedReason = 'Subscription Expired';
    _selectedTable = widget.adminData['assigned_table'];
  }

  Future<void> _updateAdmin() async {
    if (_isCheckingMobile || _mobileTakenError != null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/update/${widget.adminData['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'status': _selectedStatus,
          'assigned_table': _selectedRole == 'Super Admin' ? null : _selectedTable,
          'god_name': _godNameController.text.trim(),
          'contact_person': _contactPersonController.text.trim(),
          'mobile_number': '+${_selectedCountry.dialCode} ${_mobileNumberController.text.replaceAll(' ', '').trim()}',
          'address': _addressController.text.trim(),
          if (_passwordController.text.isNotEmpty) 'password': _passwordController.text,
          if (_selectedStatus == 'Inactive') 
            'reason': _selectedReason == 'Other' ? _reasonController.text.trim() : _selectedReason,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        await CustomNotificationDialog.show(
          context,
          type: NotificationType.success,
          title: 'Success',
          message: 'Temple updated successfully!',
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        String errMsg = 'Update failed';
        if (data['detail'] != null) {
          if (data['detail'] is List) {
            errMsg = (data['detail'] as List).map((e) => e['msg'] ?? '').join(', ');
          } else {
            errMsg = data['detail'].toString();
            if (errMsg.contains('users_email_key') || errMsg.contains('super_admins_email_key')) {
              errMsg = 'This email address is already registered.';
            } else if (errMsg.contains('users_mobile_number_key') || errMsg.contains('mobile_number')) {
              errMsg = 'This mobile number is already registered.';
            } else if (errMsg.contains('duplicate key value violates unique constraint')) {
              errMsg = 'A record with this information already exists.';
            }
          }
        }
        CustomNotificationDialog.show(
          context,
          type: NotificationType.error,
          title: 'Error',
          message: errMsg,
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'Error',
        message: 'Connection error. Please try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _hasUnsavedChanges() {
    if (_nameController.text.trim() != (widget.adminData['name'] ?? '')) return true;
    if (_emailController.text.trim() != (widget.adminData['email'] ?? '')) return true;
    if (_passwordController.text.isNotEmpty) return true;
    if (_godNameController.text.trim() != (widget.adminData['god_name'] ?? '')) return true;
    if (_contactPersonController.text.trim() != (widget.adminData['contact_person'] ?? '')) return true;
    if (_addressController.text.trim() != (widget.adminData['address'] ?? '')) return true;
    if (_selectedStatus != (widget.adminData['status'] ?? 'Active')) return true;
    if (_selectedRole == 'Admin' && _selectedTable != widget.adminData['assigned_table']) return true;
    
    String initialMobile = widget.adminData['mobile_number']?.toString() ?? '';
    String currentMobile = '+${_selectedCountry.dialCode} ${_mobileNumberController.text.replaceAll(' ', '').trim()}';
    if (initialMobile.replaceAll(' ', '') != currentMobile.replaceAll(' ', '')) return true;

    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) return true;
    
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE40000)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          title: const Text('Edit Temple', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.1),
          iconTheme: const IconThemeData(color: Color(0xFF111827)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                        key: _formKey,
                        child: Builder(
                          builder: (context) {
                            final isDesktop = MediaQuery.of(context).size.width > 700;
                            
                            Widget leftColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Temple Details', style: TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _nameController, 
                                  label: 'Temple Name *', 
                                  hint: 'Enter Temple Name',
                                  icon: Icons.temple_hindu_outlined,
                                  validator: (v) => v!.trim().isEmpty ? 'Enter temple name' : null,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(254),
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _godNameController, 
                                  label: 'God Name *', 
                                  hint: 'Enter God Name',
                                  icon: Icons.self_improvement_outlined,
                                  validator: (v) => v!.trim().isEmpty ? 'Enter god name' : null,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(254),
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _addressController, 
                                  label: 'Temple Address *', 
                                  hint: 'Enter Temple Address',
                                  icon: Icons.location_on_outlined,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Temple Address is required';
                                    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Temple Address must contain at least one alphabetic character';
                                    return null;
                                  },
                                  inputFormatters: [LengthLimitingTextInputFormatter(254)],
                                ),
                                const SizedBox(height: 16),
                                _buildDropdown('Status', _selectedStatus, ['Active', 'Inactive'], (val) {
                                  setState(() {
                                    _selectedStatus = val!;
                                    if (val != 'Inactive') _reasonController.clear();
                                  });
                                }),
                                if (_selectedStatus == 'Inactive') ...[
                                  const SizedBox(height: 16),
                                  _buildDropdown('Reason for Inactivation', _selectedReason, 
                                    ['Subscription Expired', 'Maintenance Mode', 'Requested by Admin', 'Violation of Terms', 'Other'], 
                                    (val) {
                                      setState(() {
                                        _selectedReason = val!;
                                      });
                                    }
                                  ),
                                  if (_selectedReason == 'Other') ...[
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _reasonController,
                                      label: 'Specify Reason *',
                                      hint: 'Enter specific reason',
                                      icon: Icons.info_outline,
                                      validator: (v) => v!.trim().isEmpty ? 'Enter reason for inactivation' : null,
                                    ),
                                  ],
                                ],
                              ],
                            );

                            Widget rightColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Contact & Authentication', style: TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _contactPersonController, 
                                  label: 'Contact Person Name *', 
                                  hint: 'Enter Contact Person Name',
                                  icon: Icons.person_outline_outlined,
                                  validator: (v) => v!.trim().isEmpty ? 'Enter contact person name' : null,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(254),
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                CompositedTransformTarget(
                                  link: _layerLink,
                                  child: TextFormField(
                                    key: _mobileFieldKey,
                                    controller: _mobileNumberController,
                                  style: const TextStyle(color: Color(0xFF111827)),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
                                    _MobileNumberSpaceFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    label: const Text.rich(
                                      TextSpan(
                                        text: 'Mobile Number',
                                        children: [
                                          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                    labelStyle: const TextStyle(color: Color(0xFF4B5563)),
                                    hintText: 'Enter Mobile Number',
                                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                                    prefixIcon: GestureDetector(
                                      onTap: _toggleCountryDropdown,
                                      child: Container(
                                        color: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 4),
                                            const Icon(Icons.phone_android_outlined, color: Color(0xFF9CA3AF), size: 20),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${_selectedCountry.flag} +${_selectedCountry.dialCode}',
                                              style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
                                            ),
                                            Icon(
                                              _isCountryDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                              color: const Color(0xFF6B7280),
                                            ),
                                            Container(
                                              height: 22,
                                              width: 1,
                                              color: const Color(0xFFD1D5DB),
                                              margin: const EdgeInsets.only(left: 4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE40000)),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Colors.redAccent),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (v) {
                                    if (_mobileTakenError != null) return _mobileTakenError;
                                    if (v == null || v.isEmpty) return 'Enter mobile number';
                                    final text = v.replaceAll(' ', '').trim();
                                    
                                    if (_selectedCountry.code == 'IN') {
                                      if (text.length != 10) {
                                        return 'Enter a valid 10-digit mobile number';
                                      } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(text)) {
                                        return 'Indian mobile numbers must start with 6, 7, 8, or 9';
                                      }
                                    } else {
                                      if (text.length < _selectedCountry.minLength || text.length > _selectedCountry.maxLength) {
                                        if (_selectedCountry.minLength == _selectedCountry.maxLength) {
                                          return 'Enter a valid ${_selectedCountry.minLength}-digit mobile number';
                                        } else {
                                          return 'Enter between ${_selectedCountry.minLength} and ${_selectedCountry.maxLength} digits';
                                        }
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _emailController, 
                                  label: 'Email Address *', 
                                  hint: 'Enter Email Address',
                                  icon: Icons.email_outlined,
                                  enableCopy: true,
                                  validator: (v) => v!.trim().isEmpty ? 'Enter email' : null,
                                  inputFormatters: [LengthLimitingTextInputFormatter(254)],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController, 
                                  label: 'New Password (Optional)', 
                                  hint: 'Leave blank to keep current',
                                  icon: Icons.lock_outline, 
                                  isPassword: true,
                                  obscureText: _obscurePassword,
                                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                                  enableCopy: true,
                                  validator: (v) {
                                    if (v != null && v.isNotEmpty) {
                                      if (v.trim().isEmpty) return 'Password cannot be only spaces';
                                      if (v.length < 8) return 'Password must be at least 8 characters';
                                      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).+$').hasMatch(v)) {
                                        return 'Must contain at least 1 uppercase, 1 lowercase, 1 number, and 1 special character';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note_rounded, color: Color(0xFFE40000), size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                  'Edit Details',
                                  style: TextStyle(color: Color(0xFF111827), fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 32),
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: leftColumn),
                                      const SizedBox(width: 32),
                                      Expanded(child: rightColumn),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      leftColumn,
                                      const SizedBox(height: 32),
                                      rightColumn,
                                    ],
                                  ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _updateAdmin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE40000),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: _isLoading 
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text(
                                          'UPDATE TEMPLE', 
                                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                                        ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _toggleCountryDropdown() {
    if (_isCountryDropdownOpen) {
      _removeCountryOverlay();
    } else {
      _showCountryOverlay();
    }
  }

  void _showCountryOverlay() {
    final renderBox = _mobileFieldKey.currentContext!.findRenderObject()! as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final availableSpaceBelow = MediaQuery.of(context).size.height - offset.dy - size.height;
    final showAbove = availableSpaceBelow < 320;

    _countryOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeCountryOverlay,
            child: Container(color: Colors.transparent),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: showAbove ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(0, showAbove ? -4 : 4),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: size.width,
                child: GestureDetector(
                  onTap: () {}, // absorb taps
                  child: _CountryDropdownPanel(
                    initialCountry: _selectedCountry,
                    onSelect: (country) {
                      setState(() => _selectedCountry = country);
                      _removeCountryOverlay();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_countryOverlayEntry!);
    setState(() => _isCountryDropdownOpen = true);
  }

  void _removeCountryOverlay() {
    _countryOverlayEntry?.remove();
    _countryOverlayEntry = null;
    if (mounted) setState(() => _isCountryDropdownOpen = false);
  }

  @override


  @override
  void dispose() {
    _removeCountryOverlay();
    _mobileNumberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    String? hint,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggle,
    bool enableCopy = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFF111827)),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        label: label.endsWith('*') || label.endsWith(' *')
            ? Text.rich(
                TextSpan(
                  text: label.replaceAll(' *', '').replaceAll('*', '').trim(),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              )
            : Text(label),
        labelStyle: const TextStyle(color: Color(0xFF4B5563)),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
        suffixIcon: (isPassword || enableCopy)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPassword)
                  IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF6B7280),
                    ),
                    onPressed: onToggle,
                  ),
                if (enableCopy)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: const Color(0xFF6B7280)),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: controller.text));
                        CustomNotificationDialog.show(
                          context,
                          type: NotificationType.success,
                          title: 'Success',
                          message: 'Copied to clipboard!',
                        );
                      } else {
                        CustomNotificationDialog.show(
                          context,
                          type: NotificationType.warning,
                          title: 'Empty',
                          message: 'Nothing to copy!',
                        );
                      }
                    },
                  ),
              ],
            )
          : null,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE40000))),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return CustomDropdownSearch(
      label: label,
      value: value,
      dropdownItems: items,
      onChanged: onChanged,
      height: 52,
    );
  }
}

class _CountryDropdownPanel extends StatefulWidget {
  final Country initialCountry;
  final ValueChanged<Country> onSelect;

  const _CountryDropdownPanel({
    required this.initialCountry,
    required this.onSelect,
  });

  @override
  State<_CountryDropdownPanel> createState() => _CountryDropdownPanelState();
}

class _CountryDropdownPanelState extends State<_CountryDropdownPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Country> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(countries);
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = countries
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.dialCode.contains(q))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: 'Search country or code...',
                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 20),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE40000)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.black12),
            // Countries list
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No results', style: TextStyle(color: Colors.black54)),
                    )
                  : RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(40),
                      thumbColor: Colors.black26,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          final isSelected = c.code == widget.initialCountry.code;
                          return InkWell(
                            onTap: () => widget.onSelect(c),
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFFE40000).withOpacity(0.1)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Text(c.flag, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '+${c.dialCode}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNumberSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    StringBuffer buffer = StringBuffer();
    int selectionIndex = newValue.selection.end;
    int newSelectionIndex = 0;

    for (int i = 0; i < text.length; i++) {
      if (i == selectionIndex) {
        newSelectionIndex = buffer.length;
      }
      buffer.write(text[i]);
      if (i == 4 && i != text.length - 1) { // Add space after 5th digit
        buffer.write(' ');
        if (i + 1 == selectionIndex) {
          newSelectionIndex = buffer.length;
        }
      }
    }

    if (selectionIndex == text.length) {
      newSelectionIndex = buffer.length;
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
  }
}
