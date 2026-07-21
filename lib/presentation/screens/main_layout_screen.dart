import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/screens/dashboard_screen.dart';
import 'package:temple_onboarding/presentation/screens/admin_list_screen.dart';
import 'package:temple_onboarding/presentation/screens/login_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MainLayoutScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  String _dashboardSearchQuery = '';
  String _templeSearchQuery = '';
  bool _isProfileMenuOpen = false;
  String _selectedLanguage = 'English';

  Widget _buildHeader(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    String currentHint = _selectedIndex == 0 ? 'Search temples...' : 'Search logins...';
    
    Widget searchBar = SizedBox(
      height: 40,
      child: TextField(
        decoration: InputDecoration(
          hintText: currentHint,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE40000))),
        ),
        onChanged: (value) {
          setState(() {
            if (_selectedIndex == 0) {
              _dashboardSearchQuery = value.toLowerCase();
            } else {
              _templeSearchQuery = value.toLowerCase();
            }
          });
        },
      ),
    );

    if (isMobile) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        width: double.infinity,
        height: 85,
        child: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827), size: 30),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset('assets/images/kanavu-logo-1.png', height: 80, fit: BoxFit.contain),
            const SizedBox(width: 8),
            Expanded(child: searchBar),
            const SizedBox(width: 16),
            _buildLanguageSelector(isMobile: true),
            const SizedBox(width: 16),
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE40000),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280), size: 20),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity,
      height: 85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827), size: 30),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 16),
                Image.asset('assets/images/kanavu-logo-1.png', height: 80, fit: BoxFit.contain),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 400,
              child: searchBar,
            ),
          ),
          Positioned(
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageSelector(isMobile: false),
                const SizedBox(width: 16),
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: _isProfileMenuOpen ? 'Hide menu' : 'Show menu',
                    offset: const Offset(0, 56),
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    elevation: 4,
                    constraints: const BoxConstraints(minWidth: 160),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onOpened: () => setState(() => _isProfileMenuOpen = true),
                    onCanceled: () => setState(() => _isProfileMenuOpen = false),
                    onSelected: (value) async {
                      setState(() => _isProfileMenuOpen = false);
                      if (value == 'logout') {
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
                      } else if (value == 'profile') {
                        final String contactPerson = widget.userData['contact_person']?.toString() ?? widget.userData['name']?.toString() ?? 'Administrator';
                        final String role = widget.userData['role']?.toString() ?? 'Administrator';
                        final String emailRaw = widget.userData['email']?.toString() ?? '';
                        final String email = emailRaw.isNotEmpty ? emailRaw : 'N/A';
                        final String mobileRaw = widget.userData['mobile']?.toString() ?? '';
                        final String mobile = mobileRaw.isNotEmpty ? mobileRaw : 'N/A';
                        
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.account_circle, color: Color(0xFFE40000), size: 28),
                                SizedBox(width: 12),
                                Text('Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_outline, color: Color(0xFF6B7280)),
                                  title: const Text('Contact Person Name', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  subtitle: Text(contactPerson, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF6B7280)),
                                  title: const Text('Role', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  subtitle: Text(role, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.phone_outlined, color: Color(0xFF6B7280)),
                                  title: const Text('Contact Number', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  subtitle: Text(mobile, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.email_outlined, color: Color(0xFF6B7280)),
                                  title: const Text('Email ID', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  subtitle: Text(email, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                                ),
                              ],
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
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.blueAccent, size: 20),
                            SizedBox(width: 12),
                            Text('Profile', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.userData['name']?.toString() ?? 'Administrator',
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                widget.userData['role']?.toString() ?? 'Administrator',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE40000),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Icon(_isProfileMenuOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF6B7280), size: 20),
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

  Widget _buildLanguageSelector({required bool isMobile}) {
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
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
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
              if (!isMobile) ...[
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
              ] else ...[
                const SizedBox(width: 4),
                Text(
                  isEnglish ? 'EN' : 'TA',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFE40000) : Colors.white60),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFFE40000) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE40000), Color(0xFFB30000)],
              ),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFFE40000), size: 40),
            ),
            accountName: Text(widget.userData['name'] ?? 'User'),
            accountEmail: null,
          ),
          _buildDrawerItem(
            Icons.dashboard_rounded, 
            'Dashboard', 
            _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context); // Close drawer
            }
          ),
          _buildDrawerItem(
            Icons.people_rounded, 
            'Temple', 
            _selectedIndex == 1, 
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context); // Close drawer
            }
          ),
          const Spacer(),
          const Divider(color: Colors.white24),
          _buildDrawerItem(Icons.logout_rounded, 'Logout', false, onTap: () async {
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
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  DashboardScreen(
                    userData: widget.userData,
                    searchQuery: _dashboardSearchQuery,
                    language: _selectedLanguage,
                  ),
                  AdminListScreen(
                    userData: widget.userData,
                    searchQuery: _templeSearchQuery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
