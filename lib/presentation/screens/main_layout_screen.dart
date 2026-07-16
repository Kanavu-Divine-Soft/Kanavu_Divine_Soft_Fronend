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
            const CircleAvatar(
              backgroundColor: Color(0xFFE40000),
              child: Icon(Icons.person, color: Colors.white),
            ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.userData['name'] ?? 'User',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.userData['role'] ?? 'Member',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const CircleAvatar(
                  backgroundColor: Color(0xFFE40000),
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
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
