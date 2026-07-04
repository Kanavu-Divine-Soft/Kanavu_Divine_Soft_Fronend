import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/widgets/custom_notification_dialog.dart';
import 'package:temple_onboarding/presentation/screens/login_screen.dart';
import 'package:temple_onboarding/presentation/screens/dashboard_screen.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart' as intl_country;
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:temple_onboarding/core/api_constants.dart';
import 'package:temple_onboarding/core/download_helper.dart' if (dart.library.html) 'package:temple_onboarding/core/download_helper_web.dart';
import 'package:temple_onboarding/presentation/widgets/custom_dropdown_search.dart';
import 'package:temple_onboarding/presentation/utils/pdf_receipt_generator.dart';

class ExpandableYearPill extends StatelessWidget {
  final String yearsStr;
  const ExpandableYearPill({super.key, required this.yearsStr});

  void _showAllYears(BuildContext context, List<String> years) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: years.map((yr) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: yr == years.first ? const Color(0xFFE40000) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE40000)),
              ),
              child: Text(
                yr,
                style: TextStyle(
                  color: yr == years.first ? Colors.white : const Color(0xFFE40000),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (yearsStr.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey));
    
    final List<String> years = yearsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (years.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey));
    
    years.sort((a, b) => b.compareTo(a));
    final String latest = years.first;
    final int othersCount = years.length - 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE40000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(latest, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        if (othersCount > 0) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showAllYears(context, years),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                '+$othersCount',
                style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TempleMemberDetailsScreen extends StatefulWidget {
  final String? tableName;
  final String? templeName;
  const TempleMemberDetailsScreen({super.key, this.tableName, this.templeName});

  @override
  State<TempleMemberDetailsScreen> createState() => _TempleMemberDetailsScreenState();
}

class _TempleMemberDetailsScreenState extends State<TempleMemberDetailsScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _userData;
  List<dynamic> _allMembers = [];
  List<dynamic> _baseMembers = [];
  List<dynamic> _filteredMembers = [];
  String _error = '';
  bool _showAdvancedFilters = false;
  
  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;
  
  final TextEditingController _commonSearchController = TextEditingController();
  String _currentSearchQuery = '';
  bool _isSearchExpanded = false;
  String _nameSearchLang = 'English';
  String _selectedStatusFilter = 'All';

  // Filter Options (Stored as Map to keep track of Language)
  List<Map<String, String>> _countries = [{'val': 'All Countries', 'lang': 'English'}];
  List<Map<String, String>> _states = [{'val': 'All States', 'lang': 'English'}];
  List<Map<String, String>> _districts = [{'val': 'All Districts', 'lang': 'English'}];
  List<Map<String, String>> _cities = [{'val': 'All Cities', 'lang': 'English'}];
  List<Map<String, String>> _events = [{'val': 'All Events', 'lang': 'English'}];
  List<Map<String, String>> _paymentStatuses = [
    {'val': 'All Status', 'lang': 'English'},
    {'val': 'Paid', 'lang': 'English'},
    {'val': 'Unpaid', 'lang': 'English'},
  ];
  List<String> _years = [
    'All Years',
    ...List.generate(101, (i) => (2100 - i).toString())
  ];

  // Selected Filters
  String _selectedCountry = 'All Countries';
  String _selectedState = 'All States';
  String _selectedDistrict = 'All Districts';
  String _selectedCity = 'All Cities';
  String _selectedYear = 'All Years';
  String _selectedEventName = 'All Events';
  String _selectedPaymentStatus = 'All Status';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchMembers();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('user_data');
    if (data != null) {
      setState(() {
        _userData = jsonDecode(data);
      });
    }
  }

  Future<void> _fetchMembers() async {
    try {
      String tableName = widget.tableName ?? 'ponsoft_members';
      if (widget.tableName == null) {
        final prefs = await SharedPreferences.getInstance();
        final String? dataStr = prefs.getString('user_data');
        if (dataStr != null) {
          final userData = jsonDecode(dataStr);
          tableName = userData['assigned_table'] ?? 'ponsoft_members';
        }
      }

      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members?table=$tableName'));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final members = data['data'] as List;
        
        // Extract unique filter values with language detection (Match PHP logic)
        Map<String, String> countryMap = {'All Countries': 'English'};
        Map<String, String> stateMap = {'All States': 'English'};
        Map<String, String> districtMap = {'All Districts': 'English'};
        Map<String, String> cityMap = {'All Cities': 'English'};
        Map<String, String> eventMap = {'All Events': 'English'};
        Set<String> yearsSet = {'All Years'};

        for (var m in members) {
          String lang = m['Language']?.toString() ?? 'English';
          
          if (m['Country'] != null && m['Country'].toString().isNotEmpty) {
            String val = m['Country'].toString();
            countryMap[val] = 'English'; // Country is always English
          }
          if (m['State'] != null && m['State'].toString().isNotEmpty) {
            String val = m['State'].toString();
            if (stateMap[val] != 'Tamil') stateMap[val] = lang;
          }
          if (m['District'] != null && m['District'].toString().isNotEmpty) {
            String val = m['District'].toString();
            if (districtMap[val] != 'Tamil') districtMap[val] = lang;
          }
          if (m['City'] != null && m['City'].toString().isNotEmpty) {
            String val = m['City'].toString();
            if (cityMap[val] != 'Tamil') cityMap[val] = lang;
          }
          if (m['Payments'] != null) {
            List<dynamic> existingPayments = [];
            if (m['Payments'] is String) {
              try { existingPayments = jsonDecode(m['Payments']); } catch (_) {}
            } else if (m['Payments'] is List) {
              existingPayments = m['Payments'];
            }
            for (var p in existingPayments) {
              if (p['event_name'] != null && p['event_name'].toString().isNotEmpty) {
                eventMap[p['event_name'].toString()] = lang;
              }
            }
          }
        }

        setState(() {
          _allMembers = members;
          _filteredMembers = _allMembers;
          _baseMembers = _allMembers;
          
          _countries = countryMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
          _states = stateMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
          _districts = districtMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
          _cities = cityMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
          _events = eventMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['detail'] ?? 'Failed to load members';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _downloadSampleFormat() {
    const String csvContent = 'Code,Name,Mobile,Father\'s Name,Email,Address,Address-2,Address-3,Address-4,City,District,State,Country,Pincode,Gender,VIP,Language\n999999,John Doe,9876543210,Father Name,john@example.com,Address Line 1,Address Line 2,Address Line 3,Address Line 4,Chennai,Chennai,Tamil Nadu,India,600001,Male,No,English';
    downloadCsv('bulk_upload_sample.csv', csvContent);
  }

  Future<void> _handleBulkUpload() async {
    String? selectedLanguage = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () => Navigator.pop(context, 'English'),
              ),
              ListTile(
                title: const Text('Tamil'),
                onTap: () => Navigator.pop(context, 'Tamil'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadSampleFormat();
              },
              child: const Text('Download Sample Format', style: TextStyle(color: Color(0xFF1E40AF))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (selectedLanguage == null) return;

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null) {
        setState(() => _isUploading = true);
        
        final file = result.files.first;
        String tableName = widget.tableName ?? 'ponsoft_members';
        if (widget.tableName == null && _userData != null) {
          tableName = _userData!['assigned_table'] ?? 'ponsoft_members';
        }

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/bulk-upload?table=$tableName&language=$selectedLanguage'),
        );

        if (kIsWeb) {
          if (file.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ));
          } else {
            throw Exception("File bytes are null on web. Please try selecting the file again.");
          }
        } else {
          if (file.path != null) {
            request.files.add(await http.MultipartFile.fromPath(
              'file',
              file.path!,
            ));
          } else if (file.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ));
          }
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          String successMessage = 'Bulk upload successful!';
          NotificationType notifType = NotificationType.success;
          String notifTitle = 'Success';
          
          try {
            final jsonResponse = jsonDecode(response.body);
            if (jsonResponse['message'] != null) {
              successMessage = jsonResponse['message'];
            }
            if (jsonResponse['imported_count'] == 0) {
              notifType = NotificationType.error;
              notifTitle = 'Upload Error (Duplicates)';
            }
          } catch (e) {
            // fallback to default
          }
          if (mounted) {
            CustomNotificationDialog.show(
              context,
              type: notifType,
              title: notifTitle,
              message: successMessage,
            );
          }
          await _fetchMembers();
        } else {
          if (mounted) {
            CustomNotificationDialog.show(
              context,
              type: NotificationType.error,
              title: 'Upload Failed',
              message: response.body,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _filterMembers() {
    setState(() {
      final baseMembers = _allMembers.where((member) {
        final query = _currentSearchQuery.toLowerCase().trim();
        
        final matchesSearch = query.isEmpty ||
            (member['Code']?.toString().toLowerCase().contains(query) ?? false) ||
            (member['Name']?.toString().toLowerCase().contains(query) ?? false) ||
            (member['Mobile_Number']?.toString().toLowerCase().contains(query) ?? false) ||
            (member['Email']?.toString().toLowerCase().contains(query) ?? false);
        
        final countryMatch = _selectedCountry == 'All Countries' || (member['Country'] ?? '') == _selectedCountry;
        final stateMatch = _selectedState == 'All States' || (member['State'] ?? '') == _selectedState;
        final districtMatch = _selectedDistrict == 'All Districts' || (member['District'] ?? '') == _selectedDistrict;
        final cityMatch = _selectedCity == 'All Cities' || (member['City'] ?? '') == _selectedCity;
        bool paymentRequirementsMatch = true;

        if (_selectedYear != 'All Years' || _selectedEventName != 'All Events' || _selectedPaymentStatus != 'All Status') {
          List<dynamic> payments = [];
          if (member['Payments'] != null) {
            if (member['Payments'] is String) {
              try { payments = jsonDecode(member['Payments']); } catch(_) {}
            } else if (member['Payments'] is List) {
              payments = member['Payments'];
            }
          }
          
          bool hasPaidRecord = payments.any((p) {
            final matchesYear = _selectedYear == 'All Years' || p['year']?.toString() == _selectedYear;
            final matchesEvent = _selectedEventName == 'All Events' || p['event_name']?.toString() == _selectedEventName;
            return matchesYear && matchesEvent && p['status']?.toString() == 'Paid';
          });

          bool hasAnyRecord = payments.any((p) {
            final matchesYear = _selectedYear == 'All Years' || p['year']?.toString() == _selectedYear;
            final matchesEvent = _selectedEventName == 'All Events' || p['event_name']?.toString() == _selectedEventName;
            return matchesYear && matchesEvent;
          });

          if (_selectedPaymentStatus == 'Paid') {
             paymentRequirementsMatch = hasPaidRecord;
          } else if (_selectedPaymentStatus == 'Unpaid') {
             // Unpaid means they DO NOT have a paid record for the selected criteria
             paymentRequirementsMatch = !hasPaidRecord;
          } else {
             // All Status
             if (_selectedEventName != 'All Events') {
                 // If filtering by a specific event, everyone is either Paid or Unpaid for it.
                 // So we return true to show all members.
                 paymentRequirementsMatch = true; 
             } else {
                 paymentRequirementsMatch = hasAnyRecord;
             }
          }
        }

        return matchesSearch && countryMatch && stateMatch && districtMatch && cityMatch && paymentRequirementsMatch;
      }).toList();

      _baseMembers = baseMembers;

      _filteredMembers = baseMembers.where((member) {
        final String status = member['Status']?.toString() ?? 'Active';
        if (_selectedStatusFilter == 'All') return true;
        if (_selectedStatusFilter == 'Male') {
          return (member['Sex']?.toString() ?? 'Male') == 'Male';
        }
        if (_selectedStatusFilter == 'Female') {
          return (member['Sex']?.toString() ?? '') == 'Female';
        }
        return status == _selectedStatusFilter;
      }).toList();
      
      _currentPage = 1; // Reset to first page on search
    });
  }

  int get _totalPages => (_filteredMembers.length / _itemsPerPage).ceil();
  
  List<Map<String, String>> get _dynamicEvents {
    if (_selectedYear == 'All Years') {
       return _events;
    }
    Map<String, String> eventMap = {'All Events': 'English'};
    for (var m in _allMembers) {
      String lang = m['Language']?.toString() ?? 'English';
      if (m['Payments'] != null) {
        List<dynamic> existingPayments = [];
        if (m['Payments'] is String) {
          try { existingPayments = jsonDecode(m['Payments']); } catch (_) {}
        } else if (m['Payments'] is List) {
          existingPayments = m['Payments'];
        }
        for (var p in existingPayments) {
          if (p['year']?.toString() == _selectedYear) {
            if (p['event_name'] != null && p['event_name'].toString().isNotEmpty) {
              eventMap[p['event_name'].toString()] = lang;
            }
          }
        }
      }
    }
    return eventMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
  }

  List<Map<String, String>> get _dynamicStates {
    if (_selectedCountry == 'All Countries') return _states;
    Map<String, String> stateMap = {'All States': 'English'};
    for (var m in _allMembers) {
      if (m['Country'] == _selectedCountry && m['State'] != null && m['State'].toString().isNotEmpty) {
        String lang = m['Language']?.toString() ?? 'English';
        String val = m['State'].toString();
        if (stateMap[val] != 'Tamil') stateMap[val] = lang;
      }
    }
    return stateMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
  }

  List<Map<String, String>> get _dynamicDistricts {
    if (_selectedState == 'All States' && _selectedCountry == 'All Countries') return _districts;
    Map<String, String> districtMap = {'All Districts': 'English'};
    for (var m in _allMembers) {
      bool countryMatch = _selectedCountry == 'All Countries' || m['Country'] == _selectedCountry;
      bool stateMatch = _selectedState == 'All States' || m['State'] == _selectedState;
      if (countryMatch && stateMatch && m['District'] != null && m['District'].toString().isNotEmpty) {
        String lang = m['Language']?.toString() ?? 'English';
        String val = m['District'].toString();
        if (districtMap[val] != 'Tamil') districtMap[val] = lang;
      }
    }
    return districtMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
  }

  List<Map<String, String>> get _dynamicCities {
    if (_selectedDistrict == 'All Districts' && _selectedState == 'All States' && _selectedCountry == 'All Countries') return _cities;
    Map<String, String> cityMap = {'All Cities': 'English'};
    for (var m in _allMembers) {
      bool countryMatch = _selectedCountry == 'All Countries' || m['Country'] == _selectedCountry;
      bool stateMatch = _selectedState == 'All States' || m['State'] == _selectedState;
      bool districtMatch = _selectedDistrict == 'All Districts' || m['District'] == _selectedDistrict;
      if (countryMatch && stateMatch && districtMatch && m['City'] != null && m['City'].toString().isNotEmpty) {
        String lang = m['Language']?.toString() ?? 'English';
        String val = m['City'].toString();
        if (cityMap[val] != 'Tamil') cityMap[val] = lang;
      }
    }
    return cityMap.entries.map((e) => {'val': e.key, 'lang': e.value}).toList()..sort((a, b) => a['val']!.compareTo(b['val']!));
  }

  List<dynamic> get _paginatedMembers {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredMembers.length) return [];
    return _filteredMembers.sublist(
      startIndex,
      endIndex > _filteredMembers.length ? _filteredMembers.length : endIndex,
    );
  }
  String _getRawTempleName() {
    if (widget.templeName != null && widget.templeName!.isNotEmpty) {
      return widget.templeName!;
    }
    
    if (_userData == null) return '';
    
    if (_userData!['role'] != 'Super Admin' && _userData!['name'] != null && _userData!['name'].toString().isNotEmpty) {
       return _userData!['name'];
    }
    
    if (_userData!['role'] == 'Super Admin' && widget.tableName != null) {
      final prefix = widget.tableName!.replaceAll('_members', '');
      if (prefix.isNotEmpty) {
        final words = prefix.split(RegExp(r'[_ ]'));
        final capitalized = words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
        return capitalized;
      }
    }
    
    return '';
  }

  String _getTempleName() {
    final raw = _getRawTempleName();
    return raw.isEmpty ? 'Members Directory' : '$raw Members Directory';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        toolbarHeight: 85,
        leadingWidth: 160,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = MediaQuery.of(context).size.width < 800;
            if (isMobile) {
              return Text(_getTempleName(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
            }
            return Row(
              children: [
                Expanded(
                  child: Text(
                    _getTempleName(), 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add New Member'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE40000), foregroundColor: Colors.white),
                  ),
                ),
              ],
            );
          }
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Row(
          children: [
            const SizedBox(width: 8),
            if (_userData?['role'] == 'Super Admin')
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                tooltip: 'Back to Dashboard',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DashboardScreen(userData: _userData!)),
                  );
                },
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Image.asset('assets/images/kanavu-logo-1.png', height: 80, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Builder(
            builder: (context) {
              final bool isMobile = MediaQuery.of(context).size.width < 600;
              if (isMobile) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFE40000), size: 24),
                      tooltip: 'Add New Member',
                      onPressed: _showAddMemberDialog,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        switch (value) {
                          case 'add_event':
                            _showAddEventForAllDialog();
                            break;
                          case 'bulk_upload':
                            if (!_isUploading) _handleBulkUpload();
                            break;
                          case 'dashboard':
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => DashboardScreen(userData: _userData!)),
                            );
                            break;
                          case 'logout':
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE40000)),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Logout', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) break;

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('user_data');
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'add_event',
                          child: ListTile(
                            leading: Icon(Icons.event_available, color: Color(0xFF10B981)),
                            title: Text('Add Event'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'bulk_upload',
                          child: ListTile(
                            leading: _isUploading 
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file, color: Color(0xFF1E40AF)),
                            title: Text(_isUploading ? 'Uploading...' : 'Bulk Upload'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(),
                        if (_userData?['role'] == 'Super Admin')
                          const PopupMenuItem<String>(
                            value: 'dashboard',
                            child: ListTile(
                              leading: Icon(Icons.dashboard_rounded, color: Color(0xFFE40000)),
                              title: Text('Dashboard'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: ListTile(
                            leading: Icon(Icons.logout, color: Colors.redAccent),
                            title: Text('Logout'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              final String name = _userData?['name']?.toString() ?? 'Administrator';
              final String role = _userData?['role']?.toString() ?? 'Administrator';
              final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'A';

              return Row(
                children: [
                  // Premium Profile Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFE5E7EB),
                          child: Text(
                            firstLetter,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              role,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // View Events Button
                  TextButton.icon(
                    onPressed: _showViewEventsDialog,
                    icon: const Icon(Icons.list_alt, color: Color(0xFF3B82F6), size: 18),
                    label: const Text(
                      'View Events',
                      style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Add Event for All Button
                  TextButton.icon(
                    onPressed: _showAddEventForAllDialog,
                    icon: const Icon(Icons.event_available, color: Color(0xFF10B981), size: 18),
                    label: const Text(
                      'Add Event for All',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2), // Light pinkish-red background
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
                      tooltip: 'Sign Out',
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE40000)),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Logout', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true) return;

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('user_data');
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              );
            }
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildMemberStatusOverview(_baseMembers),
            ),
            _buildSummaryBar(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(50.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error.isNotEmpty)
              Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            else
              Column(
                children: [
                  _buildMembersTable(),
                  _buildPaginationControls(),
                  const SizedBox(height: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatIndianCurrency(double amount) {
    String str = amount.toStringAsFixed(0);
    if (str.length <= 3) return '₹$str';
    String result = str.substring(str.length - 3);
    str = str.substring(0, str.length - 3);
    while (str.length > 2) {
      result = '${str.substring(str.length - 2)},$result';
      str = str.substring(0, str.length - 2);
    }
    if (str.isNotEmpty) {
      result = '$str,$result';
    }
    return '₹$result';
  }

  Widget _buildMemberStatusOverview(List<dynamic> members) {
    int maleCount = members.where((m) => (m['Sex'] ?? 'Male') == 'Male').length;
    int femaleCount = members.where((m) => (m['Sex'] ?? '') == 'Female').length;
    int total = members.length;
    int inactiveCount = _allMembers.where((m) => m['Status']?.toString() == 'Inactive').length;
    int activeCount = _allMembers.where((m) => (m['Status']?.toString() ?? 'Active') == 'Active').length;
    
    double grandTotalAmount = 0;
    for (var member in members) {
      double totalPayments = 0;
      if (member['Payments'] != null) {
        List<dynamic> existingPayments = [];
        if (member['Payments'] is String) {
          try {
            existingPayments = jsonDecode(member['Payments']);
          } catch (e) {}
        } else if (member['Payments'] is List) {
          existingPayments = member['Payments'];
        }
        for (var p in existingPayments) {
          if (p['status']?.toString() == 'Paid') {
            totalPayments += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          }
        }
      }
      
      grandTotalAmount += totalPayments;
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Demographics', style: TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 200, child: _buildStatCard('Total Members', _baseMembers.length.toString(), Icons.groups, const Color(0xFFF59E0B), onTap: () { setState(() { _selectedStatusFilter = 'All'; _filterMembers(); }); }, isSelected: _selectedStatusFilter == 'All')),
                SizedBox(width: 200, child: _buildStatCard('Active Members', activeCount.toString(), Icons.people_alt, const Color(0xFF8B5CF6), onTap: () { setState(() { _selectedStatusFilter = 'Active'; _filterMembers(); }); }, isSelected: _selectedStatusFilter == 'Active')),
                SizedBox(width: 200, child: _buildStatCard('Inactive Members', inactiveCount.toString(), Icons.person_off, const Color(0xFFEF4444), onTap: () { setState(() { _selectedStatusFilter = 'Inactive'; _filterMembers(); }); }, isSelected: _selectedStatusFilter == 'Inactive')),
                SizedBox(width: 200, child: _buildStatCard('Male', maleCount.toString(), Icons.male, const Color(0xFF3B82F6), onTap: () { setState(() { _selectedStatusFilter = 'Male'; _filterMembers(); }); }, isSelected: _selectedStatusFilter == 'Male')),
                SizedBox(width: 200, child: _buildStatCard('Female', femaleCount.toString(), Icons.female, const Color(0xFFEC4899), onTap: () { setState(() { _selectedStatusFilter = 'Female'; _filterMembers(); }); }, isSelected: _selectedStatusFilter == 'Female')),
                SizedBox(width: 200, child: _buildStatCard('Paid Amount', _formatIndianCurrency(grandTotalAmount), Icons.currency_rupee, const Color(0xFF10B981))),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 64,
              runSpacing: 32,
              children: [
              HoverScaleWidget(
                child: SizedBox(
                  height: 200,
                  width: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: total.toDouble() > 0 ? (total.toDouble() * 1.2) : 1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              rod.toY.round().toString(),
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              const style = TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold, fontSize: 14);
                              Widget text;
                              switch (value.toInt()) {
                                case 0:
                                  text = const Text('Male', style: style);
                                  break;
                                case 1:
                                  text = const Text('Female', style: style);
                                  break;
                                default:
                                  text = const Text('');
                                  break;
                              }
                              return SideTitleWidget(meta: meta, child: text);
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value == value.toInt()) {
                                return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(toY: maleCount.toDouble(), gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(toY: femaleCount.toDouble(), gradient: const LinearGradient(colors: [Color(0xFFF472B6), Color(0xFFDB2777)], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              HoverScaleWidget(
                child: SizedBox(
                  height: 200,
                  width: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (activeCount > inactiveCount ? activeCount.toDouble() : inactiveCount.toDouble()) > 0 ? ((activeCount > inactiveCount ? activeCount.toDouble() : inactiveCount.toDouble()) * 1.2) : 1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              rod.toY.round().toString(),
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              const style = TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold, fontSize: 14);
                              Widget text;
                              switch (value.toInt()) {
                                case 0:
                                  text = const Text('Active', style: style);
                                  break;
                                case 1:
                                  text = const Text('Inactive', style: style);
                                  break;
                                default:
                                  text = const Text('');
                                  break;
                              }
                              return SideTitleWidget(meta: meta, child: text);
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value == value.toInt()) {
                                return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(toY: activeCount.toDouble(), gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(toY: inactiveCount.toDouble(), gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 40, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap, bool isSelected = false}) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color colorDark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final Color colorLight = color;

    return HoverScaleWidget(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorLight, colorDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.black87 : Colors.transparent, 
              width: 3
            ),
            boxShadow: [
              BoxShadow(
                color: colorDark.withOpacity(isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 16 : 12,
                offset: const Offset(0, 6),
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  List<Map<String, String>> _getAllEvents() {
    List<Map<String, String>> allEvents = [];
    Set<String> seenEventNames = {};
    for (var m in _allMembers) {
      if (m['Payments'] != null) {
        List<dynamic> payments = [];
        if (m['Payments'] is String) {
          try { payments = jsonDecode(m['Payments']); } catch (_) {}
        } else if (m['Payments'] is List) {
          payments = m['Payments'];
        }
        for (var p in payments) {
          String evtName = p['event_name']?.toString() ?? '';
          if (evtName.isNotEmpty && !seenEventNames.contains(evtName)) {
            seenEventNames.add(evtName);
            allEvents.add({
              'event_name': evtName,
              'from_date': p['from_date']?.toString() ?? '',
              'to_date': p['to_date']?.toString() ?? '',
              'amount': p['amount']?.toString() ?? '0.00',
            });
          }
        }
      }
    }
    return allEvents;
  }

  void _showViewEventsDialog() {
    final allEvents = _getAllEvents();
    String _filter = 'All'; // 'All', 'Current', 'Completed'
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            
            List<Map<String, String>> displayedEvents = allEvents.where((evt) {
              if (_filter == 'All') return true;
              
              bool isCompleted = false;
              try {
                final parts = evt['to_date'].toString().split('/');
                if (parts.length == 3) {
                  DateTime tD = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                  if (tD.isBefore(today)) isCompleted = true;
                }
              } catch (_) {}
              
              if (_filter == 'Completed') return isCompleted;
              return !isCompleted;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 600,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Events',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B0000)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filter == 'All',
                          onSelected: (val) => setDialogState(() => _filter = 'All'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Current Event'),
                          selected: _filter == 'Current',
                          onSelected: (val) => setDialogState(() => _filter = 'Current'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Completed Event'),
                          selected: _filter == 'Completed',
                          onSelected: (val) => setDialogState(() => _filter = 'Completed'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (displayedEvents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No events found.', style: TextStyle(color: Colors.black54))),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: displayedEvents.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final evt = displayedEvents[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(evt['event_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('From: ${evt['from_date']}  To: ${evt['to_date']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${evt['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showEditEventForAllDialog(evt);
                                    },
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditEventForAllDialog(Map<String, String> event) {
    final _dialogFormKey = GlobalKey<FormState>();
    final _amountController = TextEditingController(text: event['amount']);
    final _eventNameController = TextEditingController(text: event['event_name']);
    final _fromDateController = TextEditingController(text: event['from_date']);
    final _toDateController = TextEditingController(text: event['to_date']);
    final _yearController = TextEditingController(text: event['year'] ?? DateTime.now().year.toString());
    bool _isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isMobile = MediaQuery.of(context).size.width < 600;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: isMobile ? double.infinity : 500,
                    height: isMobile ? double.infinity : null,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Form(
                      key: _dialogFormKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Edit Event for All Members',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B0000)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _eventNameController,
                            maxLength: 254,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                            decoration: const InputDecoration(labelText: 'Event Name', border: OutlineInputBorder(), isDense: true),
                            onChanged: (v) => setDialogState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v)) return 'Only letters and spaces allowed';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _fromDateController,
                                  decoration: const InputDecoration(labelText: 'From Date', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (date != null) {
                                      setDialogState(() {
                                        _fromDateController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                      });
                                    }
                                  },
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _toDateController,
                                  decoration: const InputDecoration(labelText: 'To Date', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (date != null) {
                                      setDialogState(() {
                                        _toDateController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                      });
                                    }
                                  },
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _yearController.text.isEmpty ? DateTime.now().year.toString() : _yearController.text,
                                  decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), isDense: true),
                                  items: List.generate(101, (index) => (2100 - index).toString())
                                      .map((String year) => DropdownMenuItem<String>(value: year, child: Text(year)))
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setDialogState(() {
                                        _yearController.text = newValue;
                                      });
                                    }
                                  },
                                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _amountController,
                                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setDialogState(() {}),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC0000),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isSaving || !(_amountController.text.trim() != (event['amount'] ?? '') || _eventNameController.text.trim() != (event['event_name'] ?? '') || _fromDateController.text.trim() != (event['from_date'] ?? '') || _toDateController.text.trim() != (event['to_date'] ?? '') || _yearController.text.trim() != (event['year'] ?? DateTime.now().year.toString()))
                                  ? null
                                  : () async {
                                      if (!_dialogFormKey.currentState!.validate()) return;
                                      setDialogState(() => _isSaving = true);
                                      try {
                                        String tableName = widget.tableName ?? 'ponsoft_members';
                                        if (widget.tableName == null) {
                                          final prefs = await SharedPreferences.getInstance();
                                          final String? dataStr = prefs.getString('user_data');
                                          if (dataStr != null) {
                                            final userData = jsonDecode(dataStr);
                                            tableName = userData['assigned_table'] ?? 'ponsoft_members';
                                          }
                                        }

                                        final response = await http.put(
                                          Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/update-event-all?table=$tableName'),
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode({
                                            'old_event_name': event['event_name'],
                                            'amount': double.parse(_amountController.text.trim()),
                                            'event_name': _eventNameController.text.trim().isEmpty ? null : _eventNameController.text.trim(),
                                            'from_date': _fromDateController.text.trim().isEmpty ? null : _fromDateController.text.trim(),
                                            'to_date': _toDateController.text.trim().isEmpty ? null : _toDateController.text.trim(),
                                            'year': _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
                                          }),
                                        );

                                        if (response.statusCode == 200) {
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                          CustomNotificationDialog.show(
                                            context,
                                            type: NotificationType.success,
                                            title: 'Success',
                                            message: 'Event updated for all members successfully!',
                                          );
                                          _fetchMembers();
                                        } else {
                                          final resData = jsonDecode(response.body);
                                          if (!context.mounted) return;
                                          CustomNotificationDialog.show(
                                            context,
                                            type: NotificationType.error,
                                            title: 'Error',
                                            message: resData['detail'] ?? 'Failed to update event',
                                          );
                                        }
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        CustomNotificationDialog.show(
                                          context,
                                          type: NotificationType.error,
                                          title: 'Error',
                                          message: 'Error: $e',
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setDialogState(() => _isSaving = false);
                                        }
                                      }
                                    },
                              child: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Save Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEventForAllDialog() {
    if (_allMembers.isEmpty) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.warning,
        title: 'No Members Found',
        message: 'There are no members in the directory. Please add members first before assigning an event to all of them.',
      );
      return;
    }
    final _dialogFormKey = GlobalKey<FormState>();
    final _amountController = TextEditingController(text: '0.00');
    final _eventNameController = TextEditingController();
    final _fromDateController = TextEditingController();
    final _toDateController = TextEditingController();
    final _yearController = TextEditingController(text: DateTime.now().year.toString());
    bool _isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isMobile = MediaQuery.of(context).size.width < 600;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: isMobile ? double.infinity : 500,
                    height: isMobile ? double.infinity : null,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Form(
                      key: _dialogFormKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Add Event for All Members',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B0000)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This will add a new event entry with the specified amount for all members in the current directory.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _eventNameController,
                            maxLength: 254,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                            decoration: InputDecoration(
                              labelText: 'Event Name',
                              prefixIcon: const Icon(Icons.event, color: Color(0xFFE40000)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v)) return 'Only letters and spaces allowed';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _fromDateController,
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      _fromDateController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'From Date',
                                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFE40000)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _toDateController,
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      _toDateController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'To Date',
                                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFFE40000)),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CustomDropdownSearch(
                            label: 'Event Year',
                            value: _yearController.text.isEmpty ? DateTime.now().year.toString() : _yearController.text,
                            dropdownItems: List.generate(101, (index) => (2100 - index).toString()),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                _yearController.text = newValue;
                              }
                            },
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            height: 50,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                            decoration: InputDecoration(
                              labelText: 'Event Amount *',
                              prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFFE40000)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onTap: () {
                              if (_amountController.text == '0.00') {
                                _amountController.clear();
                              }
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null) return 'Invalid amount';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSaving ? null : () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        if (_dialogFormKey.currentState!.validate()) {
                                          setDialogState(() => _isSaving = true);
                                          try {
                                            String tableName = widget.tableName ?? 'ponsoft_members';
                                            if (widget.tableName == null) {
                                              final prefs = await SharedPreferences.getInstance();
                                              final String? dataStr = prefs.getString('user_data');
                                              if (dataStr != null) {
                                                final userData = jsonDecode(dataStr);
                                                tableName = userData['assigned_table'] ?? 'ponsoft_members';
                                              }
                                            }

                                            final response = await http.post(
                                              Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/add-event-all?table=$tableName'),
                                              headers: {'Content-Type': 'application/json'},
                                              body: jsonEncode({
                                                'amount': double.parse(_amountController.text.trim()),
                                                'event_name': _eventNameController.text.trim().isEmpty ? null : _eventNameController.text.trim(),
                                                'from_date': _fromDateController.text.trim().isEmpty ? null : _fromDateController.text.trim(),
                                                'to_date': _toDateController.text.trim().isEmpty ? null : _toDateController.text.trim(),
                                                'year': _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
                                              }),
                                            );
                                            final resData = jsonDecode(response.body);
                                            if (response.statusCode == 200) {
                                              if (!context.mounted) return;
                                              Navigator.pop(context);
                                              CustomNotificationDialog.show(
                                                context,
                                                type: NotificationType.success,
                                                title: 'Success',
                                                message: resData['message'] ?? 'Event added to all members successfully!',
                                              );
                                              _fetchMembers();
                                            } else {
                                              if (!context.mounted) return;
                                              CustomNotificationDialog.show(
                                                context,
                                                type: NotificationType.error,
                                                title: 'Error',
                                                message: resData['detail'] ?? 'Failed to add event',
                                              );
                                            }
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            CustomNotificationDialog.show(
                                              context,
                                              type: NotificationType.error,
                                              title: 'Error',
                                              message: 'Error: $e',
                                            );
                                          } finally {
                                            if (mounted) setDialogState(() => _isSaving = false);
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: _isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text('Add Event', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, String>> _getActiveEvents() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    List<Map<String, String>> activeEvents = [];
    Set<String> seenEventNames = {};
    for (var m in _allMembers) {
      if (m['Payments'] != null) {
        List<dynamic> payments = [];
        if (m['Payments'] is String) {
          try { payments = jsonDecode(m['Payments']); } catch (_) {}
        } else if (m['Payments'] is List) {
          payments = m['Payments'];
        }
        for (var p in payments) {
          if (p['to_date'] != null && p['to_date'].toString().isNotEmpty) {
            try {
              final parts = p['to_date'].toString().split('/');
              if (parts.length == 3) {
                DateTime tD = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                if (tD.isAfter(today) || tD.isAtSameMomentAs(today)) {
                  String evtName = p['event_name']?.toString() ?? '';
                  if (evtName.isNotEmpty && !seenEventNames.contains(evtName)) {
                    seenEventNames.add(evtName);
                    activeEvents.add({
                      'event_name': evtName,
                      'from_date': p['from_date']?.toString() ?? '',
                      'to_date': p['to_date']?.toString() ?? '',
                      'amount': p['amount']?.toString() ?? '0.00',
                    });
                  }
                }
              }
            } catch (_) {}
          }
        }
      }
    }
    return activeEvents;
  }

  void _showAddMemberDialog() {
    final _personalIdentityKey = GlobalKey();
    final _contactInfoKey = GlobalKey();
    final _addressDetailsKey = GlobalKey();
    final _eventsKey = GlobalKey();
    final _dialogFormKey = GlobalKey<FormState>();
    final _dialogScrollController = ScrollController();
    final _addCodeController = TextEditingController();
    final _addNameController = TextEditingController();
    final _addFatherNameController = TextEditingController();
    final _addMobileController = TextEditingController();
    final _addEmailController = TextEditingController();
    final _addAddress1Controller = TextEditingController();
    final _addAddress2Controller = TextEditingController();
    final _addAddress3Controller = TextEditingController();
    final _addAddress4Controller = TextEditingController();
    final _addCityController = TextEditingController();
    final _addDistrictController = TextEditingController();
    final _addStateController = TextEditingController(text: 'Tamil Nadu');
    final _addCountryController = TextEditingController(text: 'India');
    final _addPincodeController = TextEditingController();
    final activeEvents = _getActiveEvents();

    final List<Map<String, TextEditingController>> _paymentControllers = activeEvents.isEmpty 
        ? [
            {
              'amount': TextEditingController(text: '0.00'),
              'event_name': TextEditingController(text: ''),
              'from_date': TextEditingController(text: ''),
              'to_date': TextEditingController(text: ''),
              'year': TextEditingController(text: DateTime.now().year.toString()),
              'status': TextEditingController(text: 'Unpaid'),
            }
          ]
        : activeEvents.map((ae) => {
              'amount': TextEditingController(text: ae['amount']),
              'event_name': TextEditingController(text: ae['event_name']),
              'from_date': TextEditingController(text: ae['from_date']),
              'to_date': TextEditingController(text: ae['to_date']),
              'year': TextEditingController(text: DateTime.now().year.toString()),
              'status': TextEditingController(text: 'Unpaid'),
            }).toList();

    String _dialogSex = 'Male';
    String _dialogVip = 'No';
    String _dialogLanguage = 'English';
    Set<int> _dialogSelectedYears = {};
    String _dialogCountryCode = 'IN';
    bool _isSaving = false;
    

    Future<void> _fetchNextCode(StateSetter setDialogState) async {
      try {
        String tableName = widget.tableName ?? 'ponsoft_members';
        if (widget.tableName == null) {
          final prefs = await SharedPreferences.getInstance();
          final String? dataStr = prefs.getString('user_data');
          if (dataStr != null) {
            final userData = jsonDecode(dataStr);
            tableName = userData['assigned_table'] ?? 'ponsoft_members';
          }
        }
        final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/next_code?table=$tableName'));
        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          setDialogState(() {
            _addCodeController.text = data['next_code'].toString();
          });
        }
      } catch (e) {
        // ignore
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (_addCodeController.text.isEmpty && !_isSaving) {
              _fetchNextCode(setDialogState);
            }

            final bool isMobile = MediaQuery.of(context).size.width < 600;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.85,
                    height: isMobile ? double.infinity : null,
                    constraints: BoxConstraints(
                      maxWidth: 1000,
                      maxHeight: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDialogHeader(context, _translate('Add New ${_getRawTempleName()} Member'.replaceAll('  ', ' ').trim(), _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null), _dialogLanguage, (lang) {
                          if (_dialogLanguage != lang) {
                            _addNameController.clear();
                            _addFatherNameController.clear();
                            _addMobileController.clear();
                            _addEmailController.clear();
                            _addAddress1Controller.clear();
                            _addAddress2Controller.clear();
                            _addAddress3Controller.clear();
                            _addAddress4Controller.clear();
                            _addCityController.clear();
                            _addDistrictController.clear();
                            _addPincodeController.clear();
                            _addStateController.text = 'Tamil Nadu';
                            _addCountryController.text = 'India';
                            _paymentControllers.clear();
                            final activeEvents = _getActiveEvents();
                            if (activeEvents.isEmpty) {
                              _paymentControllers.add({
                                'amount': TextEditingController(text: '0.00'),
                                'event_name': TextEditingController(text: ''),
                                'from_date': TextEditingController(text: ''),
                                'to_date': TextEditingController(text: ''),
                                'year': TextEditingController(text: DateTime.now().year.toString()),
                                'status': TextEditingController(text: 'Unpaid'),
                              });
                            } else {
                              for (var ae in activeEvents) {
                                _paymentControllers.add({
                                  'amount': TextEditingController(text: ae['amount']),
                                  'event_name': TextEditingController(text: ae['event_name']),
                                  'from_date': TextEditingController(text: ae['from_date']),
                                  'to_date': TextEditingController(text: ae['to_date']),
                                  'year': TextEditingController(text: DateTime.now().year.toString()),
                                  'status': TextEditingController(text: 'Unpaid'),
                                });
                              }
                            }
                            setDialogState(() => _dialogLanguage = lang);
                          }
                        }),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _dialogScrollController,
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _dialogFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildResponsiveFieldsGrid(context, setDialogState, {
                                    'code': _addCodeController,
                                    'name': _addNameController,
                                    'father_name': _addFatherNameController,
                                    'mobile': _addMobileController,
                                    'email': _addEmailController,
                                    'addr1': _addAddress1Controller,
                                    'addr2': _addAddress2Controller,
                                    'addr3': _addAddress3Controller,
                                    'addr4': _addAddress4Controller,
                                    'city': _addCityController,
                                    'district': _addDistrictController,
                                    'state': _addStateController,
                                    'country': _addCountryController,
                                    'pincode': _addPincodeController,
                                    
                                  }, _dialogSex, (sex) => setDialogState(() => _dialogSex = sex),
                                     _dialogVip, (vip) => setDialogState(() => _dialogVip = vip),
                                     _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null,
                                     dialogCountryCode: _dialogCountryCode,
                                     onCountryCodeChanged: (code) {
                                      setDialogState(() {
                                        _dialogCountryCode = code;
                                        try {
                                          final c = intl_country.countries.firstWhere((x) => x.code == code);
                                          _addCountryController.text = c.name;
                                        } catch (_) {}
                                      });
                                    },
                                     paymentControllers: _paymentControllers,
                                    onAddPayment: () {
                                      if (_paymentControllers.isNotEmpty) {
                                        final last = _paymentControllers.last;
                                        final eventName = last['event_name']?.text.trim() ?? '';
                                        final fromDate = last['from_date']?.text.trim() ?? '';
                                        final toDate = last['to_date']?.text.trim() ?? '';
                                        final amount = last['amount']?.text.trim() ?? '';
                                        bool isDateValid = true;
                                        if (fromDate.isNotEmpty && toDate.isNotEmpty) {
                                          try {
                                            final fParts = fromDate.split('/');
                                            final tParts = toDate.split('/');
                                            if (fParts.length == 3 && tParts.length == 3) {
                                              final fD = DateTime(int.parse(fParts[2]), int.parse(fParts[1]), int.parse(fParts[0]));
                                              final tD = DateTime(int.parse(tParts[2]), int.parse(tParts[1]), int.parse(tParts[0]));
                                              if (tD.isBefore(fD)) isDateValid = false;
                                            }
                                          } catch (_) {}
                                        }
                                        if (eventName.isEmpty || fromDate.isEmpty || toDate.isEmpty || amount.isEmpty || amount == '0' || amount == '0.00' || !isDateValid) {
                                          CustomNotificationDialog.show(
                                            context,
                                            title: _translate('Validation Error', _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null),
                                            message: _translate(!isDateValid ? 'To Date cannot be before From Date.' : 'Please fill all the current event details before adding a new one.', _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null),
                                            type: NotificationType.error,
                                          );
                                          return;
                                        }
                                      }
                                      setDialogState(() {
                                        _paymentControllers.add({
                                          'amount': TextEditingController(text: ''),
                                          'event_name': TextEditingController(text: ''),
                                          'from_date': TextEditingController(text: ''),
                                          'to_date': TextEditingController(text: ''),
                                          'year': TextEditingController(text: DateTime.now().year.toString()),
                                          'status': TextEditingController(text: 'Unpaid'),
                                        });
                                      });
                                    },
                                    onRemovePayment: (index) {
                                      setDialogState(() {
                                        _paymentControllers[index]['amount']?.dispose();
                                        _paymentControllers[index]['event_name']?.dispose();
                                        _paymentControllers[index]['from_date']?.dispose();
                                        _paymentControllers[index]['to_date']?.dispose();
                                        _paymentControllers[index]['year']?.dispose();
                                        _paymentControllers[index]['status']?.dispose();
                                        _paymentControllers.removeAt(index);
                                      });
                                    },
                                    personalIdentityKey: _personalIdentityKey,
                                    contactInfoKey: _contactInfoKey,
                                    addressDetailsKey: _addressDetailsKey,
                                    eventsKey: _eventsKey,
                                  ),
                                  
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildDialogActions(context, _isSaving, fontFamily: _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null, () async {
                          if (!_dialogFormKey.currentState!.validate()) {
                            BuildContext? targetContext;
                            
                            if (_addNameController.text.trim().isEmpty) {
                              targetContext = _personalIdentityKey.currentContext;
                            } else if (_addMobileController.text.replaceAll(' ', '').trim().isEmpty || _addMobileController.text.replaceAll(' ', '').trim().length != 10) {
                              targetContext = _contactInfoKey.currentContext;
                            } else if (_addEmailController.text.trim().isNotEmpty && !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(_addEmailController.text.trim())) {
                              targetContext = _contactInfoKey.currentContext;
                            } else if (_addAddress1Controller.text.trim().isEmpty || 
                                       _addCityController.text.trim().isEmpty || 
                                       _addDistrictController.text.trim().isEmpty || 
                                       _addStateController.text.trim().isEmpty || 
                                       _addCountryController.text.trim().isEmpty || 
                                       _addPincodeController.text.trim().isEmpty) {
                              targetContext = _addressDetailsKey.currentContext;
                            } else {
                              targetContext = _eventsKey.currentContext;
                            }

                            if (targetContext != null) {
                              Scrollable.ensureVisible(
                                targetContext,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                            return;
                          }
                          
                          setDialogState(() => _isSaving = true);
                          

                          try {
                            String tableName = widget.tableName ?? 'ponsoft_members';
                            if (widget.tableName == null) {
                              final prefs = await SharedPreferences.getInstance();
                              final String? dataStr = prefs.getString('user_data');
                              if (dataStr != null) {
                                final userData = jsonDecode(dataStr);
                                tableName = userData['assigned_table'] ?? 'ponsoft_members';
                              }
                            }

                            final response = await http.post(
                              Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/create?table=$tableName'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'code': int.parse(_addCodeController.text.trim()),
                                'name': _addNameController.text.trim(),
                                'father_name': _addFatherNameController.text.trim(),
                                'address_1': _addAddress1Controller.text.trim(),
                                'address_2': _addAddress2Controller.text.trim(),
                                'address_3': _addAddress3Controller.text.trim(),
                                'address_4': _addAddress4Controller.text.trim(),
                                'city': _addCityController.text.trim(),
                                'district': _addDistrictController.text.trim(),
                                'state': _addStateController.text.trim(),
                                'mobile_number': _addMobileController.text.replaceAll(' ', '').trim(),
                                'email': _addEmailController.text.trim(),
                                'sex': _dialogSex,
                                'vip': _dialogVip,
                                'payments': _paymentControllers.where((c) {
                                  return c['event_name']!.text.trim().isNotEmpty;
                                }).map((c) => {
                                  'amount': double.tryParse(c['amount']?.text.trim() ?? '') ?? 0.0,
                                  'event_name': c['event_name']?.text.trim().isEmpty ?? true ? null : c['event_name']!.text.trim(),
                                  'from_date': c['from_date']?.text.trim().isEmpty ?? true ? null : c['from_date']!.text.trim(),
                                  'to_date': c['to_date']?.text.trim().isEmpty ?? true ? null : c['to_date']!.text.trim(),
                                  'year': c['year']?.text.trim().isEmpty ?? true ? null : c['year']!.text.trim(),
                                  'status': c['status']?.text.trim().isEmpty ?? true ? 'Unpaid' : c['status']!.text.trim(),
                                }).toList(),
                                'country': _addCountryController.text.trim(),
                                'pincode': _addPincodeController.text.trim(),
                                'language': _dialogLanguage == 'Sun Tommy' ? 'Tamil' : 'English',
                              }),
                            );

                            final resData = jsonDecode(response.body);
                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              CustomNotificationDialog.show(
                                context,
                                type: NotificationType.success,
                                title: 'Success',
                                message: 'Member added successfully!',
                              );
                              _fetchMembers();
                            } else {
                              CustomNotificationDialog.show(
                                context,
                                type: NotificationType.error,
                                title: 'Error',
                                message: resData['detail'] ?? 'Failed to add member',
                              );
                            }
                          } catch (e) {
                            CustomNotificationDialog.show(
                              context,
                              type: NotificationType.error,
                              title: 'Error',
                              message: 'Error: $e',
                            );
                          } finally {
                            setDialogState(() => _isSaving = false);
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restoreMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Member'),
        content: Text('Are you sure you want to restore ${member['Name']} (Code: ${member['Code']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String tableName = widget.tableName ?? 'ponsoft_members';
      if (widget.tableName == null) {
        final prefs = await SharedPreferences.getInstance();
        final String? dataStr = prefs.getString('user_data');
        if (dataStr != null) {
          final userData = jsonDecode(dataStr);
          tableName = userData['assigned_table'] ?? 'ponsoft_members';
        }
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/restore/${member['Code']}?table=$tableName'),
      );

      if (response.statusCode == 200) {
        CustomNotificationDialog.show(
          context,
          type: NotificationType.success,
          title: 'Restored',
          message: 'Member restored successfully',
        );
        _fetchMembers();
      } else {
        final data = jsonDecode(response.body);
        CustomNotificationDialog.show(
          context,
          type: NotificationType.error,
          title: 'Error',
          message: data['detail'] ?? 'Failed to restore member',
        );
      }
    } catch (e) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'Error',
        message: 'Network error occurred',
      );
    }
  }

  Future<void> _permanentDeleteMember(Map<String, dynamic> member) async {
    // First confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Permanent Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This action CANNOT be undone. The member will be permanently removed from the database.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_off_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${member['Name']} (Code: ${member['Code']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Permanently Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String tableName = widget.tableName ?? 'ponsoft_members';
      if (widget.tableName == null) {
        final prefs = await SharedPreferences.getInstance();
        final String? dataStr = prefs.getString('user_data');
        if (dataStr != null) {
          final userData = jsonDecode(dataStr);
          tableName = userData['assigned_table'] ?? 'ponsoft_members';
        }
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/permanent-delete/${member['Code']}?table=$tableName'),
      );

      if (response.statusCode == 200) {
        CustomNotificationDialog.show(
          context,
          type: NotificationType.success,
          title: 'Deleted',
          message: 'Member permanently deleted',
        );
        _fetchMembers();
      } else {
        final data = jsonDecode(response.body);
        CustomNotificationDialog.show(
          context,
          type: NotificationType.error,
          title: 'Error',
          message: data['detail'] ?? 'Failed to permanently delete member',
        );
      }
    } catch (e) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'Error',
        message: 'Network error: $e',
      );
    }
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member['Name']} (Code: ${member['Code']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String tableName = widget.tableName ?? 'ponsoft_members';
      if (widget.tableName == null) {
        final prefs = await SharedPreferences.getInstance();
        final String? dataStr = prefs.getString('user_data');
        if (dataStr != null) {
          final userData = jsonDecode(dataStr);
          tableName = userData['assigned_table'] ?? 'ponsoft_members';
        }
      }

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/delete/${member['Code']}?table=$tableName'),
      );

      if (response.statusCode == 200) {
        CustomNotificationDialog.show(
          context,
          type: NotificationType.success,
          title: 'Deleted',
          message: 'Member deleted successfully',
        );
        _fetchMembers();
      } else {
        final data = jsonDecode(response.body);
        CustomNotificationDialog.show(
          context,
          type: NotificationType.error,
          title: 'Error',
          message: data['detail'] ?? 'Failed to delete member',
        );
      }
    } catch (e) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'Error',
        message: 'Error: $e',
      );
    }
  }

  void _showDownloadReceiptDialog(Map<String, dynamic> member) {
    List<dynamic> payments = [];
    if (member['Payments'] != null) {
      if (member['Payments'] is String) {
        try {
          payments = jsonDecode(member['Payments']);
        } catch (_) {}
      } else if (member['Payments'] is List) {
        payments = member['Payments'];
      }
    }

    final paidPayments = payments.where((p) => p['status']?.toString() == 'Paid').toList();

    if (paidPayments.isEmpty) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'No Payments',
        message: 'There are no paid events to generate a receipt for.',
      );
      return;
    }

    final List<String> dropdownItems = ['All Events (Full Statement)'];
    for (var p in paidPayments) {
      final name = p['event_name']?.toString() ?? 'Unknown Event';
      final year = p['year']?.toString() ?? '';
      final amt = double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00';
      dropdownItems.add('$name $year - Rs. $amt');
    }

    String selectedPaymentString = 'All Events (Full Statement)';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Download Receipt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Text('Select the event you want to generate a receipt for:'),
                        const SizedBox(height: 16),
                        CustomDropdownSearch(
                          label: 'Event',
                          value: selectedPaymentString,
                          dropdownItems: dropdownItems,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedPaymentString = val;
                              });
                            }
                          },
                          height: 52,
                          borderColor: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                dynamic selectedPayment;
                                if (selectedPaymentString != 'All Events (Full Statement)') {
                                  int index = dropdownItems.indexOf(selectedPaymentString) - 1;
                                  if (index >= 0 && index < paidPayments.length) {
                                    selectedPayment = paidPayments[index];
                                  }
                                }
                                PdfReceiptGenerator.generateAndSaveReceipt(
                                  member, 
                                  templeName: _getRawTempleName(), 
                                  selectedPayment: selectedPayment,
                                );
                              },
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE40000), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(Map<String, dynamic> member) {
    // Parse existing payments
    List<Map<String, dynamic>> payments = [];
    if (member['Payments'] != null) {
      List<dynamic> raw = [];
      if (member['Payments'] is String) {
        try { raw = jsonDecode(member['Payments']); } catch (_) {}
      } else if (member['Payments'] is List) {
        raw = member['Payments'];
      }
      payments = raw.map((p) => Map<String, dynamic>.from(p)).toList();
    }

    bool _isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 500,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 24),
                            const Text(
                              'Record Payment',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black54),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Member name
                        Builder(
                          builder: (context) {
                            final bool isTamil = member['Language'] == 'Tamil';
                            final String nameText = member['Name']?.toString() ?? '';
                            bool hasUnicodeTamil = nameText.runes.any((r) => r >= 0x0B80 && r <= 0x0BFF);
                            return Text(
                              nameText,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFE40000),
                                fontFamily: (isTamil && !hasUnicodeTamil) ? 'Sun Tommy' : null,
                              ),
                              textAlign: TextAlign.center,
                            );
                          }
                        ),
                        Text(
                          'Code: ${member['Code']}',
                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Events list
                        payments.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 40, color: Colors.black26),
                                  SizedBox(height: 8),
                                  Text(
                                    'No events found for this member.\nAdd events from the Edit Member dialog.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black45, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: payments.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final p = entry.value;
                                    final bool isPaid = (p['status']?.toString() ?? 'Unpaid') == 'Paid';
                                    final String eventName = p['event_name']?.toString().isNotEmpty == true
                                        ? p['event_name'].toString()
                                        : 'Annual Payment';
                                    final String year = p['year']?.toString() ?? '';
                                    final String amount = p['amount'] != null
                                        ? '₹${double.tryParse(p['amount'].toString())?.toStringAsFixed(2) ?? p['amount']}'
                                        : '';
                                    final String dateRange = [
                                      p['from_date']?.toString() ?? '',
                                      p['to_date']?.toString() ?? '',
                                    ].where((s) => s.isNotEmpty).join(' – ');

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? const Color(0xFFF0FDF4)
                                            : const Color(0xFFFFF7F7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isPaid
                                              ? const Color(0xFF22C55E).withOpacity(0.4)
                                              : const Color(0xFFE40000).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Event icon
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isPaid
                                                  ? const Color(0xFF22C55E).withOpacity(0.1)
                                                  : const Color(0xFFE40000).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                                              color: isPaid ? const Color(0xFF22C55E) : const Color(0xFFE40000),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Event info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  eventName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                                                ),
                                                if (year.isNotEmpty || amount.isNotEmpty)
                                                  Text(
                                                    [if (year.isNotEmpty) year, if (amount.isNotEmpty) amount].join('  •  '),
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                                  ),
                                                if (dateRange.isNotEmpty)
                                                  Text(
                                                    dateRange,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          // Paid/Unpaid toggle
                                          GestureDetector(
                                            onTap: () {
                                              if (isPaid) {
                                                CustomNotificationDialog.show(
                                                  context,
                                                  type: NotificationType.warning,
                                                  title: 'Not Allowed',
                                                  message: 'Payment status cannot be changed to Unpaid once marked as Paid.',
                                                );
                                                return;
                                              }
                                              setDialogState(() {
                                                payments[idx]['status'] = 'Paid';
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isPaid ? const Color(0xFF22C55E) : Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isPaid ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Text(
                                                isPaid ? '✓ Paid' : 'Unpaid',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPaid ? Colors.white : const Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                        const SizedBox(height: 20),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (payments.isEmpty || _isSaving)
                                ? null
                                : () async {
                                    setDialogState(() => _isSaving = true);
                                    try {
                                      String tableName = widget.tableName ?? 'ponsoft_members';
                                      if (widget.tableName == null) {
                                        final prefs = await SharedPreferences.getInstance();
                                        final String? dataStr = prefs.getString('user_data');
                                        if (dataStr != null) {
                                          final userData = jsonDecode(dataStr);
                                          tableName = userData['assigned_table'] ?? 'ponsoft_members';
                                        }
                                      }

                                      // Build updated member fields to pass to the update endpoint
                                      final response = await http.put(
                                        Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/update/${member['Code']}?table=$tableName'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode({
                                          'name': member['Name'] ?? '',
                                          'father_name': member['Father_Name'] ?? '',
                                          'address_1': member['Address_1'] ?? '',
                                          'address_2': member['Address_2'] ?? '',
                                          'address_3': member['Address_3'] ?? '',
                                          'address_4': member['Address_4'] ?? '',
                                          'city': member['City'] ?? '',
                                          'district': member['District'] ?? '',
                                          'state': member['State'] ?? '',
                                          'mobile_number': member['Mobile_Number'] ?? '',
                                          'email': member['Email'] ?? '',
                                          'sex': member['Sex'] ?? 'Male',
                                          'vip': member['VIP'] ?? 'No',
                                          'payments': payments,
                                          'country': member['Country'] ?? '',
                                          'pincode': member['Pincode'] ?? '',
                                          'language': member['Language'] ?? 'English',
                                        }),
                                      );

                                      final resData = jsonDecode(response.body);
                                      if (response.statusCode == 200) {
                                        Navigator.pop(context);
                                        CustomNotificationDialog.show(
                                          context,
                                          type: NotificationType.success,
                                          title: 'Success',
                                          message: 'Payment status updated successfully!',
                                        );
                                        _fetchMembers();
                                      } else {
                                        CustomNotificationDialog.show(
                                          context,
                                          type: NotificationType.error,
                                          title: 'Error',
                                          message: resData['detail'] ?? 'Failed to update payment',
                                        );
                                      }
                                    } catch (e) {
                                      CustomNotificationDialog.show(
                                        context,
                                        type: NotificationType.error,
                                        title: 'Error',
                                        message: 'Error: $e',
                                      );
                                    } finally {
                                      setDialogState(() => _isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE40000),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Save Payment Status',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showEditMemberDialog(Map<String, dynamic> member) {
    final _personalIdentityKey = GlobalKey();
    final _contactInfoKey = GlobalKey();
    final _addressDetailsKey = GlobalKey();
    final _eventsKey = GlobalKey();
    final _dialogFormKey = GlobalKey<FormState>();
    final _dialogScrollController = ScrollController();
    final _addCodeController = TextEditingController(text: member['Code']?.toString() ?? '');
    final _addNameController = TextEditingController(text: member['Name']?.toString() ?? '');
    final _addFatherNameController = TextEditingController(text: member['Father_Name']?.toString() ?? '');
    String initialMobile = member['Mobile_Number']?.toString() ?? '';
    initialMobile = initialMobile.replaceAll(' ', '');
    if (initialMobile.length > 5) {
      initialMobile = '${initialMobile.substring(0, 5)} ${initialMobile.substring(5)}';
    }
    final _addMobileController = TextEditingController(text: initialMobile);
    final _addEmailController = TextEditingController(text: member['Email']?.toString() ?? '');
    final _addAddress1Controller = TextEditingController(text: (member['Address_1'] ?? member['address_1'])?.toString() ?? '');
    final _addAddress2Controller = TextEditingController(text: (member['Address_2'] ?? member['address_2'])?.toString() ?? '');
    final _addAddress3Controller = TextEditingController(text: (member['Address_3'] ?? member['address_3'])?.toString() ?? '');
    final _addAddress4Controller = TextEditingController(text: (member['Address_4'] ?? member['address_4'])?.toString() ?? '');
    final _addCityController = TextEditingController(text: (member['City'] ?? member['city'])?.toString() ?? '');
    final _addDistrictController = TextEditingController(text: (member['District'] ?? member['district'])?.toString() ?? '');
    final _addStateController = TextEditingController(text: ((member['State'] ?? member['state'])?.toString() ?? '').isEmpty ? 'Tamil Nadu' : (member['State'] ?? member['state'])!.toString());
    final _addCountryController = TextEditingController(text: ((member['Country'] ?? member['country'])?.toString() ?? '').isEmpty ? 'India' : (member['Country'] ?? member['country'])!.toString());
    final _addPincodeController = TextEditingController(text: (member['Pincode'] ?? member['pincode'])?.toString() ?? '');
    List<dynamic> existingPayments = [];
    if (member['Payments'] != null) {
      if (member['Payments'] is String) {
        try {
          existingPayments = jsonDecode(member['Payments']);
        } catch (e) {}
      } else if (member['Payments'] is List) {
        existingPayments = member['Payments'];
      }
    }
    final List<Map<String, TextEditingController>> _paymentControllers = existingPayments.isNotEmpty
        ? existingPayments.map((p) => <String, TextEditingController>{
            'amount': TextEditingController(text: p['amount']?.toString() ?? '0.00'),
            'event_name': TextEditingController(text: p['event_name']?.toString() ?? ''),
            'from_date': TextEditingController(text: p['from_date']?.toString() ?? ''),
            'to_date': TextEditingController(text: p['to_date']?.toString() ?? ''),
            'year': TextEditingController(text: p['year']?.toString() ?? DateTime.now().year.toString()),
            'status': TextEditingController(text: p['status']?.toString() ?? 'Unpaid'),
            'is_existing': TextEditingController(text: 'true'),
          }).toList()
        : [
            {
              'amount': TextEditingController(text: '0.00'),
              'event_name': TextEditingController(),
              'from_date': TextEditingController(),
              'to_date': TextEditingController(),
              'year': TextEditingController(text: DateTime.now().year.toString()),
              'status': TextEditingController(text: 'Unpaid'),
              'is_existing': TextEditingController(text: 'false'),
            }
          ];

    String _dialogSex = member['Sex']?.toString() ?? 'Male';
    if (_dialogSex.isEmpty || _dialogSex == '-- Not Specified --') _dialogSex = 'Male';
    
    String _dialogVip = member['VIP']?.toString() ?? 'No';
    if (_dialogVip.isEmpty || _dialogVip == '-- Not Specified --') _dialogVip = 'No';

    String _dialogLanguage = (member['Language'] == 'Tamil' || member['Language'] == 'Sun Tommy') ? 'Sun Tommy' : 'English';
    String _dialogCountryCode = 'IN';
    {
      String cName = ((member['Country'] ?? member['country']) ?? '').toString().trim().toLowerCase();
      if (cName.isNotEmpty) {
        try {
          final found = intl_country.countries.firstWhere((x) => x.name.toLowerCase() == cName);
          _dialogCountryCode = found.code;
        } catch (_) {
          if (cName == 'uk' || cName == 'united kingdom') _dialogCountryCode = 'GB';
          else if (cName == 'usa' || cName == 'united states') _dialogCountryCode = 'US';
          else if (cName == 'uae' || cName == 'united arab emirates') _dialogCountryCode = 'AE';
        }
      }
    }
    

    
    bool _isSaving = false;

    
    bool _isEditingEnabled = false; // Default is View-Only mode!

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void _handleLangChange(String lang) {
              if (_dialogLanguage != lang) {
                _addNameController.clear();
                _addFatherNameController.clear();
                _addMobileController.clear();
                _addEmailController.clear();
                _addAddress1Controller.clear();
                _addAddress2Controller.clear();
                _addAddress3Controller.clear();
                _addAddress4Controller.clear();
                _addCityController.clear();
                _addDistrictController.clear();
                _addPincodeController.clear();
                _addStateController.text = 'Tamil Nadu';
                _addCountryController.text = 'India';
                setDialogState(() => _dialogLanguage = lang);
              }
            }
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: BoxConstraints(
                      maxWidth: 1000,
                      maxHeight: MediaQuery.of(context).size.height * 0.9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B0000), Color(0xFFE40000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: MediaQuery.of(context).size.width < 600
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Edit ${_getRawTempleName()} Member Details'.replaceAll('  ', ' ').trim(),
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () => Navigator.pop(context),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: Icon(_isEditingEnabled ? Icons.visibility : Icons.edit, size: 16, color: Colors.white),
                                          label: Text(
                                            _isEditingEnabled ? 'View Mode' : 'Edit Details',
                                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isEditingEnabled ? Colors.orange : const Color(0xFFE40000),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              _isEditingEnabled = !_isEditingEnabled;
                                            });
                                          },
                                        ),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            color: Colors.white.withOpacity(0.15),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildLangPill('English', _dialogLanguage == 'English', _isEditingEnabled ? () => _handleLangChange('English') : null),
                                                _buildLangPill('Sun Tommy', _dialogLanguage == 'Sun Tommy', _isEditingEnabled ? () => _handleLangChange('Sun Tommy') : null),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Edit ${_getRawTempleName()} Member Details'.replaceAll('  ', ' ').trim(),
                                        style: const TextStyle(
                                          fontSize: 20, 
                                          fontWeight: FontWeight.bold, 
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          icon: Icon(_isEditingEnabled ? Icons.visibility : Icons.edit, size: 16, color: Colors.white),
                                          label: Text(
                                            _isEditingEnabled ? 'View Mode' : 'Edit Details',
                                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isEditingEnabled ? Colors.orange : const Color(0xFFE40000),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              _isEditingEnabled = !_isEditingEnabled;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 16),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            color: Colors.white.withOpacity(0.15),
                                            child: Row(
                                              children: [
                                                _buildLangPill('English', _dialogLanguage == 'English', _isEditingEnabled ? () => _handleLangChange('English') : null),
                                                _buildLangPill('Sun Tommy', _dialogLanguage == 'Sun Tommy', _isEditingEnabled ? () => _handleLangChange('Sun Tommy') : null),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () => Navigator.pop(context),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _dialogScrollController,
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _dialogFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildResponsiveFieldsGrid(context, setDialogState, {
                                    'code': _addCodeController,
                                    'name': _addNameController,
                                    'father_name': _addFatherNameController,
                                    'mobile': _addMobileController,
                                    'email': _addEmailController,
                                    'addr1': _addAddress1Controller,
                                    'addr2': _addAddress2Controller,
                                    'addr3': _addAddress3Controller,
                                    'addr4': _addAddress4Controller,
                                    'city': _addCityController,
                                    'district': _addDistrictController,
                                    'state': _addStateController,
                                    'country': _addCountryController,
                                    'pincode': _addPincodeController,
                                    
                                  }, _dialogSex, (sex) => setDialogState(() => _dialogSex = sex),
                                     _dialogVip, (vip) => setDialogState(() => _dialogVip = vip),
                                     _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null,
                                     isEdit: true,
                                     isEditable: _isEditingEnabled,
                                     dialogCountryCode: _dialogCountryCode,
                                     onCountryCodeChanged: (code) {
                                      setDialogState(() {
                                        _dialogCountryCode = code;
                                        try {
                                          final c = intl_country.countries.firstWhere((x) => x.code == code);
                                          _addCountryController.text = c.name;
                                        } catch (_) {}
                                      });
                                    },
                                     paymentControllers: _paymentControllers,
                                    onAddPayment: () {
                                      if (_paymentControllers.isNotEmpty) {
                                        final last = _paymentControllers.last;
                                        final eventName = last['event_name']?.text.trim() ?? '';
                                        final fromDate = last['from_date']?.text.trim() ?? '';
                                        final toDate = last['to_date']?.text.trim() ?? '';
                                        final amount = last['amount']?.text.trim() ?? '';
                                        bool isDateValid = true;
                                        if (fromDate.isNotEmpty && toDate.isNotEmpty) {
                                          try {
                                            final fParts = fromDate.split('/');
                                            final tParts = toDate.split('/');
                                            if (fParts.length == 3 && tParts.length == 3) {
                                              final fD = DateTime(int.parse(fParts[2]), int.parse(fParts[1]), int.parse(fParts[0]));
                                              final tD = DateTime(int.parse(tParts[2]), int.parse(tParts[1]), int.parse(tParts[0]));
                                              if (tD.isBefore(fD)) isDateValid = false;
                                            }
                                          } catch (_) {}
                                        }
                                        if (eventName.isEmpty || fromDate.isEmpty || toDate.isEmpty || amount.isEmpty || amount == '0' || amount == '0.00' || !isDateValid) {
                                          CustomNotificationDialog.show(
                                            context,
                                            title: _translate('Validation Error', _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null),
                                            message: _translate(!isDateValid ? 'To Date cannot be before From Date.' : 'Please fill all the current event details before adding a new one.', _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null),
                                            type: NotificationType.error,
                                          );
                                          return;
                                        }
                                      }
                                      setDialogState(() {
                                        _paymentControllers.add({
                                          'amount': TextEditingController(text: ''),
                                          'event_name': TextEditingController(text: ''),
                                          'from_date': TextEditingController(text: ''),
                                          'to_date': TextEditingController(text: ''),
                                          'year': TextEditingController(text: DateTime.now().year.toString()),
                                          'status': TextEditingController(text: 'Unpaid'),
                                          'is_existing': TextEditingController(text: 'false'),
                                        });
                                      });
                                    },
                                    onRemovePayment: (index) {
                                      setDialogState(() {
                                        _paymentControllers[index]['amount']?.dispose();
                                        _paymentControllers[index]['event_name']?.dispose();
                                        _paymentControllers[index]['from_date']?.dispose();
                                        _paymentControllers[index]['to_date']?.dispose();
                                        _paymentControllers[index]['year']?.dispose();
                                        _paymentControllers[index]['status']?.dispose();
                                        _paymentControllers[index]['is_existing']?.dispose();
                                        _paymentControllers.removeAt(index);
                                      });
                                    },
                                    personalIdentityKey: _personalIdentityKey,
                                    contactInfoKey: _contactInfoKey,
                                    addressDetailsKey: _addressDetailsKey,
                                    eventsKey: _eventsKey,
                                  ),
                                  
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildDialogActions(context, _isSaving, fontFamily: _dialogLanguage == 'Sun Tommy' ? 'Sun Tommy' : null, () async {
                          if (!_dialogFormKey.currentState!.validate()) {
                            BuildContext? targetContext;
                            
                            if (_addNameController.text.trim().isEmpty) {
                              targetContext = _personalIdentityKey.currentContext;
                            } else if (_addMobileController.text.replaceAll(' ', '').trim().isEmpty || _addMobileController.text.replaceAll(' ', '').trim().length != 10) {
                              targetContext = _contactInfoKey.currentContext;
                            } else if (_addEmailController.text.trim().isNotEmpty && !RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(_addEmailController.text.trim())) {
                              targetContext = _contactInfoKey.currentContext;
                            } else if (_addAddress1Controller.text.trim().isEmpty || 
                                       _addCityController.text.trim().isEmpty || 
                                       _addDistrictController.text.trim().isEmpty || 
                                       _addStateController.text.trim().isEmpty || 
                                       _addCountryController.text.trim().isEmpty || 
                                       _addPincodeController.text.trim().isEmpty) {
                              targetContext = _addressDetailsKey.currentContext;
                            } else {
                              targetContext = _eventsKey.currentContext;
                            }

                            if (targetContext != null) {
                              Scrollable.ensureVisible(
                                targetContext,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                            return;
                          }
                          
                          setDialogState(() => _isSaving = true);
                          
                          try {
                            String tableName = widget.tableName ?? 'ponsoft_members';
                            if (widget.tableName == null) {
                              final prefs = await SharedPreferences.getInstance();
                              final String? dataStr = prefs.getString('user_data');
                              if (dataStr != null) {
                                final userData = jsonDecode(dataStr);
                                tableName = userData['assigned_table'] ?? 'ponsoft_members';
                              }
                            }

                            final response = await http.put(
                              Uri.parse('${ApiConstants.baseUrl}/api/ponsoft/members/update/${member['Code']}?table=$tableName'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'name': _addNameController.text.trim(),
                                'father_name': _addFatherNameController.text.trim(),
                                'address_1': _addAddress1Controller.text.trim(),
                                'address_2': _addAddress2Controller.text.trim(),
                                'address_3': _addAddress3Controller.text.trim(),
                                'address_4': _addAddress4Controller.text.trim(),
                                'city': _addCityController.text.trim(),
                                'district': _addDistrictController.text.trim(),
                                'state': _addStateController.text.trim(),
                                'mobile_number': _addMobileController.text.replaceAll(' ', '').trim(),
                                'email': _addEmailController.text.trim(),
                                'sex': _dialogSex,
                                'vip': _dialogVip,
                                'payments': _paymentControllers.where((c) {
                                  return c['event_name']!.text.trim().isNotEmpty;
                                }).map((c) => {
                                  'amount': double.tryParse(c['amount']?.text.trim() ?? '') ?? 0.0,
                                  'event_name': c['event_name']?.text.trim().isEmpty ?? true ? null : c['event_name']!.text.trim(),
                                  'from_date': c['from_date']?.text.trim().isEmpty ?? true ? null : c['from_date']!.text.trim(),
                                  'to_date': c['to_date']?.text.trim().isEmpty ?? true ? null : c['to_date']!.text.trim(),
                                  'year': c['year']?.text.trim().isEmpty ?? true ? null : c['year']!.text.trim(),
                                  'status': c['status']?.text.trim().isEmpty ?? true ? 'Unpaid' : c['status']!.text.trim(),
                                }).toList(),
                                'country': _addCountryController.text.trim(),
                                'pincode': _addPincodeController.text.trim(),
                                'language': _dialogLanguage == 'Sun Tommy' ? 'Tamil' : 'English',
                              }),
                            );

                            final resData = jsonDecode(response.body);
                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              CustomNotificationDialog.show(
                                context,
                                type: NotificationType.success,
                                title: 'Success',
                                message: 'Member details updated successfully!',
                              );
                              _fetchMembers();
                            } else {
                              CustomNotificationDialog.show(
                                context,
                                type: NotificationType.error,
                                title: 'Error',
                                message: resData['detail'] ?? 'Failed to update member',
                              );
                            }
                          } catch (e) {
                            CustomNotificationDialog.show(
                              context,
                              type: NotificationType.error,
                              title: 'Error',
                              message: 'Error: $e',
                            );
                          } finally {
                            setDialogState(() => _isSaving = false);
                          }
                        }, isEditable: _isEditingEnabled),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader(BuildContext context, String title, String currentLang, Function(String) onLangChanged) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final titleWidget = Text(
      title,
      style: const TextStyle(
        fontSize: 20, 
        fontWeight: FontWeight.bold, 
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );

    final langToggle = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Colors.white.withOpacity(0.15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangPill('English', currentLang == 'English', () => onLangChanged('English')),
            _buildLangPill('Sun Tommy', currentLang == 'Sun Tommy', () => onLangChanged('Sun Tommy')),
          ],
        ),
      ),
    );

    final closeButton = IconButton(
      icon: const Icon(Icons.close, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFE40000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    closeButton,
                  ],
                ),
                const SizedBox(height: 12),
                langToggle,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleWidget),
                Row(
                  children: [
                    langToggle,
                    const SizedBox(width: 16),
                    closeButton,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildLangPill(String title, bool isSelected, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF8B0000) : Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(BuildContext context, List<Widget> children) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    if (isMobile) {
      return Column(
        children: children.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: c,
        )).toList(),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: children.map((c) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: c,
            ),
          )).toList(),
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing, String? fontFamily, Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFDCDC), width: 1.5),
            ),
            child: Icon(icon, color: const Color(0xFFE40000), size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            _translate(title, fontFamily),
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 17, 
              fontWeight: FontWeight.w700, 
              color: const Color(0xFF1E293B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Divider(
              color: Color(0xFFF1F5F9),
              thickness: 1.5,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveFieldsGrid(
    BuildContext context,
    StateSetter setDialogState,
    Map<String, TextEditingController> controllers,
    String sex, Function(String) onSexChanged,
    String vip, Function(String) onVipChanged,
    String? fontFamily, {
    bool isEdit = false,
    bool isEditable = true,
    String dialogCountryCode = 'IN',
    Function(String)? onCountryCodeChanged,
    List<Map<String, TextEditingController>> paymentControllers = const [],
    VoidCallback? onAddPayment,
    Function(int)? onRemovePayment,
    GlobalKey? personalIdentityKey,
    GlobalKey? contactInfoKey,
    GlobalKey? addressDetailsKey,
    GlobalKey? eventsKey,
  }) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Personal Identity', Icons.badge_outlined, fontFamily: fontFamily, key: personalIdentityKey),
        _buildResponsiveRow(context, [
          if (isEdit)
            _buildDialogTextField(
              controller: controllers['code']!,
              label: 'Member Code',
              icon: Icons.qr_code,
              fontFamily: fontFamily,
              enabled: false,
            ),
          _buildDialogTextField(
            controller: controllers['name']!,
            label: 'Full Name *',
            icon: Icons.person,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => v!.trim().isEmpty ? _translate('Required', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
          _buildDialogTextField(
            controller: controllers['father_name']!,
            label: "Father's Name",
            icon: Icons.person_outline,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => (v != null && v.isNotEmpty && v.trim().isEmpty) ? _translate('Invalid input', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
        ]),
        _buildResponsiveRow(context, [
          _buildDialogDropdown(
            label: 'Gender',
            value: sex,
            items: ['Male', 'Female'],
            onChanged: isEditable ? (v) => onSexChanged(v!) : null,
          ),
          _buildDialogDropdown(
            label: 'VIP Status',
            value: vip,
            items: ['Yes', 'No'],
            onChanged: isEditable ? (v) => onVipChanged(v!) : null,
          ),
          const SizedBox(), // Empty spacer
        ]),

        _buildSectionHeader('Contact Information', Icons.contact_phone_outlined, fontFamily: fontFamily, key: contactInfoKey),
        _buildResponsiveRow(context, [
          _CustomMobileNumberField(
            key: ValueKey(dialogCountryCode),
            controller: controllers['mobile']!,
            enabled: isEditable,
            initialCountryCode: dialogCountryCode,
            onCountryCodeChanged: onCountryCodeChanged ?? (code) {},
            fontFamily: fontFamily,
          ),
          _buildDialogTextField(
            controller: controllers['email']!,
            label: 'Email *',
            icon: Icons.email,
            maxLength: 254,
            enabled: isEditable,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              final bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value);
              if (!emailValid) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(),
        ]),

        _buildSectionHeader('Address Details', Icons.home_outlined, fontFamily: fontFamily, key: addressDetailsKey),
        _buildResponsiveRow(context, [
          _buildDialogTextField(
            controller: controllers['addr1']!,
            label: 'Address Line 1 *',
            icon: Icons.home,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) {
              if (v == null || v.isEmpty) return _translate('Required', fontFamily);
              if (v.trim().isEmpty) return _translate('Invalid input', fontFamily);
              return null;
            },
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
          _buildDialogTextField(
            controller: controllers['addr2']!,
            label: 'Address Line 2 *',
            icon: Icons.home_outlined,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) {
              if (v == null || v.isEmpty) return _translate('Required', fontFamily);
              if (v.trim().isEmpty) return _translate('Invalid input', fontFamily);
              return null;
            },
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
          _buildDialogTextField(
            controller: controllers['addr3']!,
            label: 'Address Line 3',
            icon: Icons.home_outlined,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => (v != null && v.isNotEmpty && v.trim().isEmpty) ? _translate('Invalid input', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
        ]),
        _buildResponsiveRow(context, [
          _buildDialogTextField(
            controller: controllers['addr4']!,
            label: 'Address Line 4',
            icon: Icons.home_outlined,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => (v != null && v.isNotEmpty && v.trim().isEmpty) ? _translate('Invalid input', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
          _buildDialogTextField(
            controller: controllers['city']!,
            label: 'City *',
            icon: Icons.location_city,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => v!.trim().isEmpty ? _translate('Required', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
          _buildDialogTextField(
            controller: controllers['district']!,
            label: 'District *',
            icon: Icons.map,
            fontFamily: fontFamily,
            enabled: isEditable,
            validator: (v) => v!.trim().isEmpty ? _translate('Required', fontFamily) : null,
            maxLength: 254,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          ),
        ]),
        _buildResponsiveRow(context, [
          FormField<String>(
            initialValue: controllers['state']!.text,
            validator: (v) => (v == null || v.trim().isEmpty || v == 'Select State') ? _translate('Required', fontFamily) : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            builder: (FormFieldState<String> stateField) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomStateSelectField(
                    initialState: controllers['state']!.text,
                    selectedCountry: controllers['country']!.text,
                    enabled: isEditable,
                    fontFamily: fontFamily,
                    onStateSelect: (state) {
                      controllers['state']!.text = state;
                      stateField.didChange(state);
                      setDialogState(() {});
                    },
                  ),
                  if (stateField.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        stateField.errorText!,
                        style: TextStyle(color: const Color(0xFFD32F2F), fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
          FormField<String>(
            initialValue: controllers['country']!.text,
            validator: (v) => (v == null || v.trim().isEmpty || v == 'Select Country') ? _translate('Required', fontFamily) : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            builder: (FormFieldState<String> countryField) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomCountrySelectField(
                    initialCountryCode: dialogCountryCode,
                    enabled: isEditable,
                    fontFamily: fontFamily,
                    onCountrySelect: (code, name) {
                      controllers['country']!.text = name;
                      countryField.didChange(name);
                      if (onCountryCodeChanged != null) {
                        onCountryCodeChanged(code);
                      }
                      setDialogState(() {});
                    },
                  ),
                  if (countryField.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        countryField.errorText!,
                        style: TextStyle(color: const Color(0xFFD32F2F), fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
          _buildDialogTextField(
            controller: controllers['pincode']!,
            label: 'PinCode *',
            icon: Icons.pin,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: isEditable,
            validator: (v) => v!.trim().isEmpty ? _translate('Required', fontFamily) : null,
            fontFamily: fontFamily,
          ),
        ]),

        _buildSectionHeader(
          'Events', 
          Icons.event,
          fontFamily: fontFamily,
          key: eventsKey,
          trailing: onAddPayment != null && isEditable
              ? InkWell(
                  onTap: onAddPayment,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFDCDC), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Color(0xFFE40000), size: 18),
                        const SizedBox(width: 4),
                        Text(_translate('Add Event', fontFamily), style: TextStyle(fontFamily: fontFamily, color: const Color(0xFFE40000), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        Builder(
          builder: (context) {
            final InputDecoration tableInputDec = InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE40000))),
              fillColor: Colors.white,
              filled: true,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 45,
                  dataRowMinHeight: 65,
                  dataRowMaxHeight: 65,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                  columns: [
                    DataColumn(label: Text(_translate('Event Name', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('From Date', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('To Date', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('Year', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('Status', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('Amount *', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                    DataColumn(label: Text(_translate('Action', fontFamily), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                  ],
                  rows: [
                    for (int j = 0; j < paymentControllers.length; j++)
                      () {
                        final isExistingRow = paymentControllers[j].containsKey('is_existing') && paymentControllers[j]['is_existing']!.text == 'true';
                        final isRowEditable = isEditable && !isExistingRow;
                        return DataRow(
                          cells: [
                            DataCell(SizedBox(
                              width: 150,
                              child: TextFormField(
                                controller: paymentControllers[j]['event_name']!,
                                enabled: isRowEditable,
                                style: const TextStyle(fontSize: 13),
                                decoration: tableInputDec,
                                onChanged: isRowEditable ? (v) {
                                final activeEvts = _getActiveEvents();
                                final match = activeEvts.where((e) => e['event_name'] == v).toList();
                                if (match.isNotEmpty) {
                                  paymentControllers[j]['amount']!.text = match.first['amount'] ?? '0.00';
                                  paymentControllers[j]['from_date']!.text = match.first['from_date'] ?? '';
                                  paymentControllers[j]['to_date']!.text = match.first['to_date'] ?? '';
                                }
                                setDialogState(() {});
                              } : null,
                              validator: (v) {
                                final p = paymentControllers[j];
                                bool isActive = j > 0 || p['from_date']!.text.isNotEmpty || p['to_date']!.text.isNotEmpty || (p['amount']!.text.isNotEmpty && p['amount']!.text != '0.00' && p['amount']!.text != '0');
                                return (isActive && (v == null || v.trim().isEmpty)) ? 'Req' : null;
                              },
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 130,
                            child: TextFormField(
                              controller: paymentControllers[j]['from_date'],
                              style: const TextStyle(fontSize: 13),
                              readOnly: true,
                              decoration: tableInputDec.copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Colors.grey)),
                              enabled: isRowEditable,
                              validator: (v) {
                                final p = paymentControllers[j];
                                bool isActive = j > 0 || p['event_name']!.text.trim().isNotEmpty || p['to_date']!.text.isNotEmpty || (p['amount']!.text.isNotEmpty && p['amount']!.text != '0.00' && p['amount']!.text != '0');
                                return (isActive && (v == null || v.trim().isEmpty)) ? 'Req' : null;
                              },
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              onTap: isRowEditable ? () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  paymentControllers[j]['from_date']!.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                }
                              } : null,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 130,
                            child: TextFormField(
                              controller: paymentControllers[j]['to_date'],
                              style: const TextStyle(fontSize: 13),
                              readOnly: true,
                              decoration: tableInputDec.copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 16, color: Colors.grey)),
                              enabled: isRowEditable,
                              validator: (v) {
                                final p = paymentControllers[j];
                                bool isActive = j > 0 || p['event_name']!.text.trim().isNotEmpty || p['from_date']!.text.isNotEmpty || (p['amount']!.text.isNotEmpty && p['amount']!.text != '0.00' && p['amount']!.text != '0');
                                if (isActive && (v == null || v.trim().isEmpty)) return 'Req';

                                if (v != null && v.isNotEmpty && p['from_date']!.text.isNotEmpty) {
                                  try {
                                    final fParts = p['from_date']!.text.split('/');
                                    final tParts = v.split('/');
                                    if (fParts.length == 3 && tParts.length == 3) {
                                      final fD = DateTime(int.parse(fParts[2]), int.parse(fParts[1]), int.parse(fParts[0]));
                                      final tD = DateTime(int.parse(tParts[2]), int.parse(tParts[1]), int.parse(tParts[0]));
                                      if (tD.isBefore(fD)) return 'Invalid';
                                    }
                                  } catch (_) {}
                                }
                                return null;
                              },
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              onTap: isRowEditable ? () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  paymentControllers[j]['to_date']!.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                }
                              } : null,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 110,
                            child: Builder(builder: (context) {
                              final val = paymentControllers[j]['year']?.text.isNotEmpty == true ? paymentControllers[j]['year']!.text : DateTime.now().year.toString();
                              final items = List<String>.generate(28, (index) => (2027 - index).toString());
                              final fromDateText = paymentControllers[j]['from_date']?.text ?? '';
                              if (fromDateText.isNotEmpty) {
                                final fromYearStr = fromDateText.split('/').last;
                                if (int.tryParse(fromYearStr) != null && !items.contains(fromYearStr)) items.add(fromYearStr);
                              }
                              final toDateText = paymentControllers[j]['to_date']?.text ?? '';
                              if (toDateText.isNotEmpty) {
                                final toYearStr = toDateText.split('/').last;
                                if (int.tryParse(toYearStr) != null && !items.contains(toYearStr)) items.add(toYearStr);
                              }
                              if (!items.contains(val)) items.add(val);
                              items.sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
                              return CustomDropdownSearch(
                                label: '',
                                height: 40,
                                value: val,
                                borderColor: const Color(0xFFE5E7EB),
                                dropdownItems: items,
                                isEnabled: isRowEditable,
                                onChanged: isRowEditable ? (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      paymentControllers[j]['year']!.text = value;
                                    });
                                  }
                                } : null,
                              );
                            }),
                          )),
                          DataCell(SizedBox(
                            width: 120,
                            child: CustomDropdownSearch(
                              label: '',
                              height: 40,
                              value: paymentControllers[j]['status']?.text.isNotEmpty == true ? paymentControllers[j]['status']!.text : 'Unpaid',
                              borderColor: const Color(0xFFE5E7EB),
                              dropdownItems: const ['Paid', 'Unpaid'],
                              isEnabled: isEditable,
                              onChanged: isEditable ? (value) {
                                  if (value != null) {
                                    if (paymentControllers[j]['status']?.text == 'Paid' && value == 'Unpaid') {
                                      CustomNotificationDialog.show(
                                        context,
                                        type: NotificationType.warning,
                                        title: 'Not Allowed',
                                        message: 'Payment status cannot be changed to Unpaid once marked as Paid.',
                                      );
                                      setDialogState(() {}); // Force UI to revert dropdown
                                      return;
                                    }
                                    setDialogState(() {
                                      paymentControllers[j]['status']!.text = value;
                                    });
                                  }
                                } : null,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 100,
                            child: Builder(builder: (context) {
                              bool isAmountReadOnly = false;
                              final activeEvts = _getActiveEvents();
                              final evtName = paymentControllers[j]['event_name']!.text.trim();
                              if (evtName.isNotEmpty) {
                                isAmountReadOnly = activeEvts.any((e) => e['event_name'] == evtName);
                              }
                              return TextFormField(
                                controller: paymentControllers[j]['amount'],
                                style: const TextStyle(fontSize: 13),
                                decoration: tableInputDec.copyWith(
                                  fillColor: isAmountReadOnly ? Colors.grey[200] : Colors.white,
                                  filled: true,
                                ),
                                readOnly: isAmountReadOnly,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                                enabled: isEditable,
                                onTap: isEditable && !isAmountReadOnly ? () {
                                  if (paymentControllers[j]['amount']!.text == '0.00' || paymentControllers[j]['amount']!.text == '0') {
                                    paymentControllers[j]['amount']!.clear();
                                  }
                                } : null,
                                validator: (v) {
                                  final p = paymentControllers[j];
                                  bool isActive = j > 0 || p['event_name']!.text.trim().isNotEmpty || p['from_date']!.text.isNotEmpty || p['to_date']!.text.isNotEmpty;
                                  return (isActive && (v == null || v.trim().isEmpty)) ? 'Req' : null;
                                },
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                              );
                            }),
                          )),
                          DataCell(
                            onRemovePayment != null && paymentControllers.length > 1 && !isExistingRow
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.grey),
                                    onPressed: isRowEditable ? () => onRemovePayment(j) : null,
                                    tooltip: 'Remove event',
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }(),
                  ],
                ),
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? fontFamily,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      enabled: enabled,
      onTap: onTap,
      onChanged: onChanged,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      buildCounter: maxLength != null ? (context, {required currentLength, required isFocused, maxLength}) => null : null,
      style: TextStyle(
        color: const Color(0xFF1E293B),
        fontFamily: fontFamily,
        fontSize: fontFamily != null ? 18 : 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        label: label.endsWith('*') || label.endsWith(' *')
            ? Text.rich(
                TextSpan(
                  text: _translate(label.replaceAll(' *', '').replaceAll('*', '').trim(), fontFamily),
                  children: const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              )
            : Text(_translate(label, fontFamily)),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFFE40000), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE40000), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return CustomDropdownSearch(
      label: label,
      value: value,
      dropdownItems: items,
      onChanged: onChanged,
      height: 52,
      borderColor: const Color(0xFFE2E8F0),
      isSearchable: false,
    );
  }

  Widget _buildYearsCheckboxGrid(BuildContext context, StateSetter setDialogState, Set<int> selectedYears, {bool isEditable = true}) {
    return _MultiYearDropdownField(
      selectedYears: selectedYears,
      isEditable: isEditable,
      onChanged: (newSelection) {
        selectedYears.clear();
        selectedYears.addAll(newSelection);
        setDialogState(() {});
      },
    );
  }

  Widget _buildDialogActions(BuildContext context, bool isSaving, VoidCallback onSave, {bool isEditable = true, String? fontFamily}) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 16,
        runSpacing: 12,
        children: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _translate('Cancel', fontFamily), 
              style: TextStyle(
                fontFamily: fontFamily,
                color: const Color(0xFF64748B), 
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          InkWell(
            onTap: (isSaving || !isEditable) ? null : onSave,
            child: Container(
              decoration: BoxDecoration(
                gradient: (isSaving || !isEditable) 
                    ? null 
                    : const LinearGradient(
                        colors: [Color(0xFF8B0000), Color(0xFFE40000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: (isSaving || !isEditable) ? Colors.grey[400] : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (isSaving || !isEditable) 
                    ? null 
                    : [
                        BoxShadow(
                          color: const Color(0xFFE40000).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              child: Center(
                child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _translate('Save Member', fontFamily), 
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bars Row/Column
          if (isMobile)
            Column(
              children: [
                _buildSearchField(
                  controller: _commonSearchController,
                  hint: 'Search by Code, Name, Mobile or Email...',
                  icon: Icons.search,
                  onChanged: (val) {
                    _currentSearchQuery = val;
                    _filterMembers();
                  },
                  fontFamily: _nameSearchLang == 'Sun Tommy' ? 'Sun Tommy' : null,
                  suffixIcon: _buildSearchLangToggle(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAdvancedFilters = !_showAdvancedFilters;
                          });
                        },
                        icon: const Icon(Icons.tune),
                        label: const Text('Filters'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: _showAdvancedFilters ? const Color(0xFFFFF5F5) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        _commonSearchController.clear();
                        _currentSearchQuery = '';
                        _filterMembers();
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                const Spacer(),

                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _handleBulkUpload,
                  icon: _isUploading 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                  label: Text(_isUploading ? 'Uploading...' : 'Bulk Upload'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16)),
                ),
                const SizedBox(width: 16),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isSearchExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  alignment: Alignment.centerRight,
                  firstChild: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: () => setState(() => _isSearchExpanded = true),
                    ),
                  ),
                  secondChild: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: _buildSearchField(
                      controller: _commonSearchController,
                      hint: 'Search by Code, Name, Mobile or Email...',
                      icon: Icons.search,
                      onChanged: (val) {
                        _currentSearchQuery = val;
                        _filterMembers();
                      },
                      fontFamily: _nameSearchLang == 'Sun Tommy' ? 'Sun Tommy' : null,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSearchLangToggle(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                            onPressed: () {
                              setState(() {
                                _isSearchExpanded = false;
                                _commonSearchController.clear();
                                _currentSearchQuery = '';
                                _filterMembers();
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAdvancedFilters = !_showAdvancedFilters;
                    });
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('Advanced Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _showAdvancedFilters ? const Color(0xFFFFF5F5) : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _commonSearchController.clear();
                      _currentSearchQuery = '';
                      _selectedCountry = 'All Countries';
                      _selectedState = 'All States';
                      _selectedDistrict = 'All Districts';
                      _selectedCity = 'All Cities';
                      _selectedYear = 'All Years';
                      _selectedEventName = 'All Events';
                      _selectedPaymentStatus = 'All Status';
                      _filterMembers();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset All',
                ),
              ],
            ),
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 16),
            // Filters Wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDynamicDropdown('COUNTRY', _selectedCountry, _countries, (val) {
                  setState(() { 
                    _selectedCountry = val!; 
                    _selectedState = 'All States';
                    _selectedDistrict = 'All Districts';
                    _selectedCity = 'All Cities';
                    _filterMembers(); 
                  });
                }),
                _buildDynamicDropdown('STATE', _selectedState, _dynamicStates, (val) {
                  setState(() { 
                    _selectedState = val!; 
                    _selectedDistrict = 'All Districts';
                    _selectedCity = 'All Cities';
                    _filterMembers(); 
                  });
                }),
                _buildDynamicDropdown('DISTRICT', _selectedDistrict, _dynamicDistricts, (val) {
                  setState(() { 
                    _selectedDistrict = val!; 
                    _selectedCity = 'All Cities';
                    _filterMembers(); 
                  });
                }),
                _buildDynamicDropdown('CITY OR TALUK', _selectedCity, _dynamicCities, (val) {
                  setState(() { 
                    _selectedCity = val!; 
                    _filterMembers(); 
                  });
                }),
                _buildDynamicDropdown('EVENT YEAR', _selectedYear, _years.map((y) => {'val': y, 'lang': 'English'}).toList(), (val) {
                  setState(() { 
                    _selectedYear = val!; 
                    _selectedEventName = 'All Events';
                    _filterMembers(); 
                  });
                }),
                _buildDynamicDropdown('EVENT NAME', _selectedEventName, _dynamicEvents, (val) {
                  setState(() { _selectedEventName = val!; _filterMembers(); });
                }),
                _buildDynamicDropdown('STATUS', _selectedPaymentStatus, _paymentStatuses, (val) {
                  setState(() { _selectedPaymentStatus = val!; _filterMembers(); });
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicDropdown(String label, String selectedValue, List<Map<String, String>> items, ValueChanged<String?> onChanged) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final List<String> dropdownItems = items.map((item) => item['val']!).toList();
    final String currentVal = items.any((i) => i['val'] == selectedValue) ? selectedValue : items.first['val']!;

    return SizedBox(
      width: isMobile ? (MediaQuery.of(context).size.width - 52) / 2 : 170,
      child: CustomDropdownSearch(
        label: label,
        value: currentVal,
        dropdownItems: dropdownItems,
        onChanged: onChanged,
        height: 48,
      ),
    );
  }

  Widget _buildSearchLangToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _nameSearchLang = _nameSearchLang == 'Sun Tommy' ? 'English' : 'Sun Tommy';
        });
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          _nameSearchLang == 'Sun Tommy' ? 'TA' : 'EN',
          style: const TextStyle(
            color: Color(0xFFE40000),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({required TextEditingController controller, required String hint, required IconData icon, Function(String)? onChanged, String? fontFamily, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontFamily: fontFamily, fontSize: fontFamily == 'Sun Tommy' ? 18 : 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 13)),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    final endIndex = startIndex + _paginatedMembers.length - 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Text(
                  _filteredMembers.isEmpty 
                    ? 'Total Records: 0' 
                    : 'Showing $startIndex-$endIndex of ${_filteredMembers.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 12),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Text(
                  _filteredMembers.isEmpty 
                    ? 'Total Records: 0' 
                    : 'Showing $startIndex-$endIndex of ${_filteredMembers.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
    );
  }

  final ScrollController _horizontalScrollController = ScrollController();

  Widget _buildMembersTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: SizedBox(
        height: _paginatedMembers.isEmpty ? 200 : (_paginatedMembers.length * 70.0) + 65.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable2(
            empty: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No members found', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            showCheckboxColumn: false,
            dataRowHeight: 70.0,
            columnSpacing: 24.0,
            horizontalMargin: 16.0,
            fixedLeftColumns: MediaQuery.of(context).size.width < 800 ? 0 : 3,
          minWidth: 2200,
          border: const TableBorder(
            verticalInside: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          headingRowColor:
              MaterialStateProperty.all(const Color(0xFFF9FAFB)),
          columns: const [
            DataColumn2(label: Text('CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: ColumnSize.S),
            DataColumn2(label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: ColumnSize.L),
            DataColumn2(label: Text('MOBILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: ColumnSize.M),
            DataColumn2(label: Text('TOTAL PAID AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), fixedWidth: 150),
            DataColumn2(label: Text('FATHER\'S NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), size: ColumnSize.L),
            DataColumn2(label: Text('ADDRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), fixedWidth: 500),
            DataColumn2(label: Text('CITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('DISTRICT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('STATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('GENDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('COUNTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('PINCODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn2(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), fixedWidth: 210),
          ],
          rows: _paginatedMembers.map((member) {
            final isTamil = member['Language'] == 'Tamil';
            double totalPayments = 0;
            if (member['Payments'] != null) {
              List<dynamic> existingPayments = [];
              if (member['Payments'] is String) {
                try {
                  existingPayments = jsonDecode(member['Payments']);
                } catch (e) {}
              } else if (member['Payments'] is List) {
                existingPayments = member['Payments'];
              }
              for (var p in existingPayments) {
                if (p['status']?.toString() == 'Paid') {
                  totalPayments += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
                }
              }
            }
            
            final totalAmount = totalPayments;
            
            return DataRow(
              onSelectChanged: (selected) {
                if (selected != null && selected) {
                  _showEditMemberDialog(member);
                }
              },
              cells: [
              DataCell(Text(member['Code'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(_buildTamilText(member['Name'], isTamil)),
              DataCell(Text(member['Mobile_Number'] ?? '-')),
              DataCell(Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
              DataCell(_buildTamilText(member['Father_Name'], isTamil)),
              DataCell(Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildCombinedAddress(member, isTamil),
              )),
              DataCell(_buildTamilText(member['City'], isTamil)),
              DataCell(_buildTamilText(member['District'], isTamil)),
              DataCell(_buildTamilText(member['State'], isTamil)),
              DataCell(Text(member['Sex'] ?? '-')),
              DataCell(_buildTamilText(member['Country']?.toString(), isTamil)),
              DataCell(Text(member['Pincode']?.toString() ?? '-')),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: member['Status']?.toString() == 'Inactive'
                ? [
                    IconButton(
                      icon: const Icon(Icons.restore_page_outlined, color: Colors.green, size: 22),
                      tooltip: 'Restore Member',
                      onPressed: () => _restoreMember(member),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Color(0xFF8B0000), size: 22),
                      tooltip: 'Permanently Delete',
                      onPressed: () => _permanentDeleteMember(member),
                    ),
                  ]
                : [
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, color: Colors.blue, size: 20),
                    tooltip: 'Download Receipt',
                    onPressed: () => _showDownloadReceiptDialog(member),
                  ),
                  IconButton(
                    icon: const Icon(Icons.payments_outlined, color: Colors.green, size: 20),
                    tooltip: 'Add Payment',
                    onPressed: () => _showRecordPaymentDialog(member),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _showEditMemberDialog(member),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _deleteMember(member),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ), // DataTable2
      ), // ClipRRect
      ), // SizedBox
    ); // Container
  }

  Widget _buildTamilText(String? text, bool isTamil) {
    if (text == null || text.isEmpty) return const Text('-');
    
    // If the text already contains Tamil Unicode characters, don't force Sun Tommy
    // as it will turn them into gibberish.
    bool hasUnicodeTamil = text.runes.any((r) => r >= 0x0B80 && r <= 0x0BFF);

    return Text(
      text,
      style: TextStyle(
        fontFamily: (isTamil && !hasUnicodeTamil) ? 'Sun Tommy' : null,
        fontSize: isTamil ? 16 : 14,
        fontWeight: isTamil ? FontWeight.w500 : FontWeight.normal,
      ),
    );
  }

  Widget _buildCombinedAddress(Map<String, dynamic> member, bool isTamil) {
    final List<String> parts = [
      member['Address_1'] ?? member['address_1'],
      member['Address_2'] ?? member['address_2'],
      member['Address_3'] ?? member['address_3'],
      member['Address_4'] ?? member['address_4']
    ].where((s) => s != null && s.toString().trim().isNotEmpty).map((s) => s.toString()).toList();

    if (parts.isEmpty) return const Text('-');

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
        children: List.generate(parts.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const TextSpan(text: ', ', style: TextStyle(fontFamily: null));
          }
          final partIndex = index ~/ 2;
          final text = parts[partIndex];
          bool hasUnicodeTamil = text.runes.any((r) => r >= 0x0B80 && r <= 0x0BFF);
          
          return TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: (isTamil && !hasUnicodeTamil) ? 'Sun Tommy' : null,
              fontSize: isTamil ? 16 : 13,
              fontWeight: isTamil ? FontWeight.w500 : FontWeight.normal,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_filteredMembers.isEmpty) return const SizedBox.shrink();
    
    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    final endIndex = startIndex + _paginatedMembers.length - 1;
    final total = _filteredMembers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Builder(
        builder: (context) {
          final bool isMobile = MediaQuery.of(context).size.width < 600;
          
          final textWidget = Text(
            'Showing $startIndex to $endIndex of $total entries',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          );
          
          final buttonsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageButton('1', 1, _currentPage == 1),
                if (_currentPage > 3) 
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...')),
                
                // Dynamic page numbers around current page
                ...List.generate(5, (index) {
                  int pageNum = _currentPage - 2 + index;
                  if (pageNum <= 1 || pageNum >= _totalPages) return const SizedBox.shrink();
                  return _buildPageButton(pageNum.toString(), pageNum, _currentPage == pageNum);
                }),

                if (_currentPage < _totalPages - 2) 
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...')),
                
                if (_totalPages > 1)
                  _buildPageButton(_totalPages.toString(), _totalPages, _currentPage == _totalPages),
                
                const SizedBox(width: 8),
                
                // Next Button
                _buildTextButton('Next', _currentPage < _totalPages ? () => setState(() => _currentPage++) : null),
                
                // Last Button
                _buildTextButton('»', _currentPage < _totalPages ? () => setState(() => _currentPage = _totalPages) : null),
              ],
            ),
          );

          if (isMobile) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                textWidget,
                const SizedBox(height: 12),
                buttonsWidget,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              textWidget,
              buttonsWidget,
            ],
          );
        }
      ),
    );
  }

  Widget _buildPageButton(String label, int pageNum, bool isActive) {
    return InkWell(
      onTap: () => setState(() => _currentPage = pageNum),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE40000) : Colors.transparent,
          border: Border.all(color: isActive ? const Color(0xFFE40000) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTextButton(String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? Colors.grey : const Color(0xFFE40000),
            fontSize: 13,
          ),
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

// ─────────────────────────────────────────────────────────────
// Custom Mobile Number Field with Overlay Country Picker (Light Theme)
// ─────────────────────────────────────────────────────────────
class _CustomMobileNumberField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String initialCountryCode;
  final Function(String) onCountryCodeChanged;
  final String? fontFamily;

  const _CustomMobileNumberField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.initialCountryCode,
    required this.onCountryCodeChanged,
    this.fontFamily,
  });

  @override
  State<_CustomMobileNumberField> createState() => _CustomMobileNumberFieldState();
}

class _CustomMobileNumberFieldState extends State<_CustomMobileNumberField> {
  late intl_country.Country _selectedCountry;
  OverlayEntry? _countryOverlayEntry;
  final GlobalKey _mobileFieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  bool _isCountryDropdownOpen = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedCountry = intl_country.countries.firstWhere((c) => c.code == widget.initialCountryCode, orElse: () => intl_country.countries.firstWhere((c) => c.code == 'IN'));
  }

  void _toggleCountryDropdown() {
    if (!widget.enabled) return;
    if (_isCountryDropdownOpen) {
      _removeCountryOverlay();
    } else {
      _showCountryOverlay();
    }
  }

  void _showCountryOverlay() {
    final renderBox = _mobileFieldKey.currentContext!.findRenderObject()! as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final availableHeightBelow = screenHeight - offset.dy - size.height - 24;
    final availableHeightAbove = offset.dy - 48;
    
    final bool openUpwards = availableHeightBelow < 250 && availableHeightAbove > availableHeightBelow;
    
    double dropdownHeight = 350.0;
    if (openUpwards && dropdownHeight > availableHeightAbove) {
      dropdownHeight = availableHeightAbove;
    } else if (!openUpwards && dropdownHeight > availableHeightBelow) {
      dropdownHeight = availableHeightBelow > 100 ? availableHeightBelow : 100;
    }

    _countryOverlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeCountryOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, openUpwards ? -dropdownHeight - 4 : size.height + 4),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: size.width,
                height: dropdownHeight,
                child: GestureDetector(
                  onTap: () {}, // absorb taps
                  child: _CountryDropdownPanel(
                    initialCountry: _selectedCountry,
                    fontFamily: widget.fontFamily,
                    onSelect: (country) {
                      setState(() => _selectedCountry = country);
                      widget.onCountryCodeChanged(country.code);
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
  void dispose() {
    _focusNode.dispose();
    _removeCountryOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: _mobileFieldKey,
      focusNode: _focusNode,
      controller: widget.controller,
      enabled: widget.enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return _translate('Required', widget.fontFamily);
        final text = v.replaceAll(' ', '').trim();
        
        if (_selectedCountry.code == 'IN') {
          if (text.length != 10) {
            return _translate('Enter a valid', widget.fontFamily) + ' 10-' + _translate('digit mobile number', widget.fontFamily);
          } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(text)) {
            return _translate('Invalid Indian mobile number', widget.fontFamily);
          }
        } else {
          final bool isValid = text.length >= _selectedCountry.minLength && text.length <= _selectedCountry.maxLength;
          if (!isValid) {
            if (_selectedCountry.minLength == _selectedCountry.maxLength) {
              return _translate('Enter a valid', widget.fontFamily) + ' ${_selectedCountry.maxLength}-' + _translate('digit mobile number', widget.fontFamily);
            } else {
              return _translate('Enter between', widget.fontFamily) + ' ${_selectedCountry.minLength} ' + _translate('and', widget.fontFamily) + ' ${_selectedCountry.maxLength} ' + _translate('digits', widget.fontFamily);
            }
          }
        }
        return null;
      },
      style: TextStyle(
        color: const Color(0xFF1E293B),
        fontSize: 15,
        fontFamily: widget.fontFamily,
        fontWeight: FontWeight.w500,
      ),
      keyboardType: TextInputType.phone,
      onChanged: (value) {},
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
        _MobileNumberSpaceFormatter(),
      ],
      decoration: InputDecoration(
        label: Text.rich(
          TextSpan(
            text: _translate('Mobile Number', widget.fontFamily),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: GestureDetector(
          onTap: _toggleCountryDropdown,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selectedCountry.flag} +${_selectedCountry.dialCode}',
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w500),
                ),
                if (widget.enabled)
                  Icon(
                    _isCountryDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: const Color(0xFF64748B),
                  ),
                Container(
                  height: 22,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.only(left: 8),
                ),
              ],
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE40000), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      ),
    );
  }
}

class CustomCountrySelectField extends StatefulWidget {
  final String initialCountryCode;
  final Function(String, String) onCountrySelect; // code, name
  final bool enabled;
  final String? fontFamily;

  const CustomCountrySelectField({
    Key? key,
    required this.initialCountryCode,
    required this.onCountrySelect,
    this.enabled = true,
    this.fontFamily,
  }) : super(key: key);

  @override
  State<CustomCountrySelectField> createState() => _CustomCountrySelectFieldState();
}

class _CustomCountrySelectFieldState extends State<CustomCountrySelectField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late intl_country.Country _selectedCountry;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = intl_country.countries.firstWhere((c) => c.code == widget.initialCountryCode, orElse: () => intl_country.countries.firstWhere((c) => c.code == 'IN'));
  }
  
  @override
  void didUpdateWidget(CustomCountrySelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCountryCode != widget.initialCountryCode) {
      setState(() {
        _selectedCountry = intl_country.countries.firstWhere((c) => c.code == widget.initialCountryCode, orElse: () => intl_country.countries.firstWhere((c) => c.code == 'IN'));
      });
    }
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    
    final availableHeightBelow = screenHeight - position.dy - size.height - 24;
    final availableHeightAbove = position.dy - 48;
    
    final bool openUpwards = availableHeightBelow < 250 && availableHeightAbove > availableHeightBelow;
    
    double dropdownHeight = 350.0;
    if (openUpwards && dropdownHeight > availableHeightAbove) {
      dropdownHeight = availableHeightAbove;
    } else if (!openUpwards && dropdownHeight > availableHeightBelow) {
      dropdownHeight = availableHeightBelow > 100 ? availableHeightBelow : 100;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, openUpwards ? -dropdownHeight - 4 : size.height + 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Container(
                width: size.width,
                height: dropdownHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _CountryDropdownPanel(
                  initialCountry: _selectedCountry,
                  fontFamily: widget.fontFamily,
                  onSelect: (country) {
                    setState(() => _selectedCountry = country);
                    widget.onCountrySelect(country.code, country.name);
                    _removeOverlay();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isDropdownOpen = false);
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: InputDecorator(
          decoration: InputDecoration(
            label: Text(_translate('Country *', widget.fontFamily)),
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: widget.enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE40000), width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCountry.name,
                        style: TextStyle(
                          color: widget.enabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryDropdownPanel extends StatefulWidget {
  final intl_country.Country initialCountry;
  final ValueChanged<intl_country.Country> onSelect;
  final String? fontFamily;

  const _CountryDropdownPanel({
    required this.initialCountry,
    required this.onSelect,
    this.fontFamily,
  });

  @override
  State<_CountryDropdownPanel> createState() => _CountryDropdownPanelState();
}

class _CountryDropdownPanelState extends State<_CountryDropdownPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<intl_country.Country> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(intl_country.countries);
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = intl_country.countries
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: _translate('Search country or code...', widget.fontFamily),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE40000)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // Countries list
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No results', style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(40),
                      thumbColor: Colors.grey[400],
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
                                  ? const Color(0xFFFFF5F5)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Text(c.flag, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF8B0000) : const Color(0xFF1E293B), 
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '+${c.dialCode}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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

class _MultiYearDropdownField extends StatefulWidget {
  final Set<int> selectedYears;
  final ValueChanged<Set<int>> onChanged;
  final bool isEditable;

  const _MultiYearDropdownField({
    required this.selectedYears,
    required this.onChanged,
    this.isEditable = true,
  });

  @override
  State<_MultiYearDropdownField> createState() => _MultiYearDropdownFieldState();
}

class _MultiYearDropdownFieldState extends State<_MultiYearDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late Set<int> _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = Set.from(widget.selectedYears);
  }

  @override
  void didUpdateWidget(_MultiYearDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentSelection = Set.from(widget.selectedYears);
  }

  void _toggleDropdown() {
    if (!widget.isEditable) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);
    var screenHeight = MediaQuery.of(context).size.height;
    var spaceBelow = screenHeight - offset.dy - size.height - 20; // 20px padding from bottom
    var spaceAbove = offset.dy - 20; // 20px padding from top
    
    // Determine if we should open upwards or downwards
    bool openUpwards = spaceBelow < 250 && spaceAbove > spaceBelow;
    double maxHeight = openUpwards ? (spaceAbove > 300 ? 300 : spaceAbove) : (spaceBelow > 300 ? 300 : spaceBelow);
    if (maxHeight < 150) maxHeight = 150; // ensure at least some items are visible

    List<int> years = List<int>.generate(28, (index) => 2027 - index);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(),
            ),
          ),
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0.0, openUpwards ? -(maxHeight + 5.0) : size.height + 5.0),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setDropdownState) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: years.length,
                        itemBuilder: (context, index) {
                          final year = years[index];
                          final isSelected = _currentSelection.contains(year);
                          return InkWell(
                            onTap: () {
                              setDropdownState(() {
                                if (isSelected) {
                                  _currentSelection.remove(year);
                                } else {
                                  _currentSelection.add(year);
                                }
                              });
                              widget.onChanged(_currentSelection);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF5F5) : Colors.transparent,
                                border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE40000) : Colors.white,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFE40000) : const Color(0xFFCBD5E1),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isSelected 
                                      ? const Icon(Icons.check, size: 14, color: Colors.white) 
                                      : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    year.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFF8B0000) : const Color(0xFF1E293B),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<int> sortedSelected = _currentSelection.toList()..sort((a, b) => b.compareTo(a));

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Last Year Paid',
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: sortedSelected.isEmpty 
                    ? const Text(
                        'Select Last Year Paid',
                        style: TextStyle(
                          color: Color(0xFF1E293B), 
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: sortedSelected.map((year) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE40000).withOpacity(0.08),
                            border: Border.all(color: const Color(0xFFE40000).withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            year.toString(),
                            style: const TextStyle(
                              color: Color(0xFF8B0000),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )).toList(),
                      ),
              ),
              Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: const Color(0xFFE40000),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


String _translate(String text, String? fontFamily) {
  if (fontFamily != 'Sun Tommy') return text;
  final Map<String, String> translations = {
    'Personal Identity': 'தனிப்பட்ட அடையாளம்',
    'Member Code': 'உறுப்பினர் குறியீடு',
    'Full Name': 'முழு பெயர்',
    'Full Name *': 'முழு பெயர் *',
    "Father's Name": 'தந்தை பெயர்',
    'Gender': 'பாலினம்',
    'Male': 'ஆண்',
    'Female': 'பெண்',
    'Other': 'மற்றவை',
    'VIP Status': 'விஐபி அந்தஸ்து',
    'Yes': 'ஆம்',
    'No': 'இல்லை',
    'Contact Information': 'தொடர்புத் தகவல்',
    'Mobile Number *': 'கைபேசி எண் *',
    'Mobile Number': 'கைபேசி எண்',
    'Email *': 'மின்னஞ்சல் *',
    'Email': 'மின்னஞ்சல்',
    'Cancel': 'ரத்து செய்',
    'Save Member': 'உறுப்பினரைச் சேமி',
    'Update Member': 'உறுப்பினரைப் புதுப்பி',
    'Address Details': 'முகவரி விவரங்கள்',
    'Address Line 1 *': 'முகவரி வரி 1 *',
    'Address Line 1': 'முகவரி வரி 1',
    'Address Line 2 *': 'முகவரி வரி 2 *',
    'Address Line 2': 'முகவரி வரி 2',
    'Address Line 3': 'முகவரி வரி 3',
    'Address Line 4': 'முகவரி வரி 4',
    'City': 'நகரம்',
    'District': 'மாவட்டம்',
    'State': 'மாநிலம்',
    'Country': 'நாடு',
    'PinCode': 'அஞ்சல் குறியீடு',
    'Events': 'நிகழ்வுகள்',
    'Add Event': 'நிகழ்வைச் சேர்',
    'Event Name': 'நிகழ்வின் பெயர்',
    'Amount': 'தொகை',
    'Amount *': 'தொகை *',
    'India': 'இந்தியா',
    'Tamil Nadu': 'தமிழ்நாடு',
    'Kerala': 'கேரளா',
    'Karnataka': 'கர்நாடகா',
    'Andhra Pradesh': 'ஆந்திரப் பிரதேசம்',
    'Telangana': 'தெலுங்கானா',
    'Puducherry': 'புதுச்சேரி',
    'Payment Status': 'கட்டண நிலை',
    'Select Status': 'நிலையைத் தேர்ந்தெடு',
    'Please fill the current event details before adding a new one.': 'புதிய நிகழ்வைச் சேர்ப்பதற்கு முன் தற்போதைய நிகழ்வு விவரங்களை நிரப்பவும்.',
    'Please fill all the current event details before adding a new one.': 'புதிய நிகழ்வைச் சேர்ப்பதற்கு முன் தற்போதைய அனைத்து நிகழ்வு விவரங்களையும் நிரப்பவும்.',
    'Validation Error': 'சரிபார்ப்பு பிழை',
    'Paid': 'செலுத்தப்பட்டது',
    'Unpaid': 'செலுத்தப்படவில்லை',
    'Required': 'கட்டாயம்',
    'Please enter a valid email': 'சரியான மின்னஞ்சலை உள்ளிடவும்',
    'Search state...': 'மாநிலத்தைத் தேடு...',
    'Search country or code...': 'நாடு அல்லது குறியீட்டைத் தேடு...',
    'Select State': 'மாநிலத்தைத் தேர்ந்தெடு',
    'Remove': 'நீக்கு',
    'From Date': 'தொடக்க தேதி',
    'To Date': 'முடிவு தேதி',
    'Year': 'ஆண்டு',
    'Status': 'நிலை',
    'Action': 'செயல்',
    'Invalid Mobile Number': 'தவறான கைபேசி எண்',
    'Enter a valid': 'சரியானதை உள்ளிடவும்',
    'digit mobile number': 'இலக்க கைபேசி எண்',
    'Enter between': 'இடையே உள்ளிடவும்',
    'and': 'மற்றும்',
    'digits': 'இலக்கங்கள்',
    'No states found for this country': 'இந்த நாட்டிற்கு மாநிலங்கள் காணப்படவில்லை',
  };
  if (text.startsWith('Add New') && text.endsWith('Member')) {
    final middle = text.substring('Add New'.length, text.length - 'Member'.length).trim();
    return middle.isEmpty ? 'புதிய உறுப்பினரைச் சேர்' : 'புதிய ${middle} உறுப்பினரைச் சேர்';
  }
  if (text.startsWith('Edit') && text.endsWith('Member')) {
    final middle = text.substring('Edit'.length, text.length - 'Member'.length).trim();
    return middle.isEmpty ? 'உறுப்பினரைப் புதுப்பி' : '${middle} உறுப்பினரைப் புதுப்பி';
  }
  return translations[text] ?? text;
}

class CustomStateSelectField extends StatefulWidget {

  final String initialState;
  final String selectedCountry;
  final Function(String) onStateSelect;
  final bool enabled;
  final String? fontFamily;

  const CustomStateSelectField({
    Key? key,
    required this.initialState,
    required this.selectedCountry,
    required this.onStateSelect,
    this.enabled = true,
    this.fontFamily,
  }) : super(key: key);

  @override
  State<CustomStateSelectField> createState() => _CustomStateSelectFieldState();
}

class _CustomStateSelectFieldState extends State<CustomStateSelectField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late String _selectedState;
  bool _isDropdownOpen = false;
  List<String> _dynamicStates = [];
  bool _isLoading = false;
  
  static const List<String> fallbackStatesList = [
    "Andaman and Nicobar Islands", "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", 
    "Chandigarh", "Chhattisgarh", "Dadra and Nagar Haveli and Daman and Diu", "Delhi", 
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jammu and Kashmir", "Jharkhand", 
    "Karnataka", "Kerala", "Ladakh", "Lakshadweep", "Madhya Pradesh", "Maharashtra", 
    "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Puducherry", "Punjab", 
    "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", 
    "Uttarakhand", "West Bengal"
  ];

  @override
  void initState() {
    super.initState();
    _selectedState = widget.initialState.isEmpty ? 'Tamil Nadu' : widget.initialState;
    _fetchStatesForCountry(widget.selectedCountry);
  }
  
  @override
  void didUpdateWidget(CustomStateSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialState != widget.initialState && widget.initialState.isNotEmpty) {
      setState(() {
        _selectedState = widget.initialState;
      });
    }
    if (oldWidget.selectedCountry != widget.selectedCountry) {
      _fetchStatesForCountry(widget.selectedCountry);
      // Optional: reset state when country changes
      if (widget.selectedCountry != oldWidget.selectedCountry) {
        setState(() {
          _selectedState = 'Select State';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onStateSelect('');
        });
      }
    }
  }

  Future<void> _fetchStatesForCountry(String countryName) async {
    setState(() => _isLoading = true);
    try {
      final jsonString = await rootBundle.loadString('packages/csc_picker/lib/assets/country.json');
      final List<dynamic> data = json.decode(jsonString);
      
      final country = data.firstWhere((c) => c['name'] == countryName, orElse: () => null);
      if (country != null && country['state'] != null && (country['state'] as List).isNotEmpty) {
        final List<dynamic> statesData = country['state'];
        setState(() {
          _dynamicStates = statesData.map((s) => s['name'].toString()).toList();
          _dynamicStates.sort();
        });
      } else {
        setState(() {
          _dynamicStates = countryName == 'India' ? fallbackStatesList : [];
        });
      }
    } catch (e) {
      setState(() {
        _dynamicStates = countryName == 'India' ? fallbackStatesList : [];
      });
    }
    
    if (_dynamicStates.isEmpty && countryName.isNotEmpty && countryName != 'Select Country') {
      if (mounted) {
        setState(() {
          _selectedState = 'N/A';
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onStateSelect('N/A');
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate available space below and above the text field
    final availableHeightBelow = screenHeight - position.dy - size.height - 24;
    final availableHeightAbove = position.dy - 48; // Leave some space for status bar
    
    // If there's not enough space below, and more space above, open upwards
    final bool openUpwards = availableHeightBelow < 250 && availableHeightAbove > availableHeightBelow;
    
    // Set max height based on direction
    double dropdownHeight = 350.0;
    if (openUpwards && dropdownHeight > availableHeightAbove) {
      dropdownHeight = availableHeightAbove;
    } else if (!openUpwards && dropdownHeight > availableHeightBelow) {
      dropdownHeight = availableHeightBelow > 100 ? availableHeightBelow : 100;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, openUpwards ? -dropdownHeight - 4 : size.height + 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Container(
                width: size.width,
                height: dropdownHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE40000)))
                    : _dynamicStates.isEmpty
                        ? Center(child: Text(_translate("No states found for this country", widget.fontFamily), style: const TextStyle(color: Color(0xFF64748B))))
                        : _StateDropdownPanel(
                            initialState: _selectedState,
                            statesList: _dynamicStates,
                            fontFamily: widget.fontFamily,
                            onSelect: (state) {
                              setState(() => _selectedState = state);
                              widget.onStateSelect(state);
                              _removeOverlay();
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isDropdownOpen = false);
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: InputDecorator(
          decoration: InputDecoration(
            label: Text(_translate('State *', widget.fontFamily)),
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: widget.enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE40000), width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: Color(0xFF94A3B8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLoading 
                        ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE40000)))
                        : Text(
                            _selectedState,
                            style: TextStyle(
                              color: widget.enabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateDropdownPanel extends StatefulWidget {
  final String initialState;
  final List<String> statesList;
  final ValueChanged<String> onSelect;
  final String? fontFamily;

  const _StateDropdownPanel({
    required this.initialState,
    required this.statesList,
    required this.onSelect,
    this.fontFamily,
  });

  @override
  State<_StateDropdownPanel> createState() => _StateDropdownPanelState();
}

class _StateDropdownPanelState extends State<_StateDropdownPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.statesList;
    _searchCtrl.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.statesList.indexOf(widget.initialState);
      if (index != -1 && _scrollController.hasClients) {
        _scrollController.jumpTo(index * 48.0);
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.statesList;
      } else {
        _filtered = widget.statesList
            .where((s) => s.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: _translate('Search state...', widget.fontFamily),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final s = _filtered[index];
              final isSelected = s == widget.initialState;
              
              return InkWell(
                onTap: () => widget.onSelect(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isSelected ? const Color(0xFFFEE2E2) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? const Color(0xFFE40000) : const Color(0xFF1E293B),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, color: Color(0xFFE40000), size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HoverScaleWidget extends StatefulWidget {
  final Widget child;
  final double scale;

  const HoverScaleWidget({Key? key, required this.child, this.scale = 1.03}) : super(key: key);

  @override
  _HoverScaleWidgetState createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? widget.scale : 1.0),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

class _EventNameAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final List<String> options;
  final InputDecoration decoration;
  final String? Function(String?)? validator;

  const _EventNameAutocomplete({
    Key? key,
    required this.controller,
    required this.enabled,
    required this.options,
    required this.decoration,
    this.validator,
  }) : super(key: key);

  @override
  State<_EventNameAutocomplete> createState() => _EventNameAutocompleteState();
}

class _EventNameAutocompleteState extends State<_EventNameAutocomplete> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return widget.options;
        }
        return widget.options.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          style: const TextStyle(fontSize: 13),
          decoration: widget.decoration,
          enabled: widget.enabled,
          maxLength: 254,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200.0, maxWidth: 150.0),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Text(option, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
