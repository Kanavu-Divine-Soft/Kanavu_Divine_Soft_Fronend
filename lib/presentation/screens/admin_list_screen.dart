import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:temple_onboarding/presentation/screens/add_admin_screen.dart';
import 'package:temple_onboarding/presentation/screens/edit_admin_screen.dart';
import 'package:temple_onboarding/presentation/widgets/custom_notification_dialog.dart';
import 'package:temple_onboarding/core/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/screens/login_screen.dart';

class AdminListScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AdminListScreen({super.key, required this.userData});

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  List<dynamic> _admins = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  String _selectedTab = 'Active';

  List<dynamic> get _filteredAdmins {
    if (_searchQuery.isEmpty) return _admins;
    return _admins.where((admin) {
      final name = (admin['name'] ?? '').toString().toLowerCase();
      final email = (admin['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/admin/list'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _admins = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load admins';
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

  Future<void> _deleteAdmin(int adminId) async {
    try {
      final response = await http.delete(Uri.parse('${ApiConstants.baseUrl}/api/admin/delete/$adminId'));
      if (response.statusCode == 200) {
        CustomNotificationDialog.show(
          context,
          type: NotificationType.success,
          title: 'Deleted',
          message: 'Temple deleted successfully!',
        );
        _fetchAdmins();
      } else {
        CustomNotificationDialog.show(
          context,
          type: NotificationType.error,
          title: 'Error',
          message: 'Failed to delete temple',
        );
      }
    } catch (e) {
      CustomNotificationDialog.show(
        context,
        type: NotificationType.error,
        title: 'Error',
        message: 'Connection error: $e',
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Confirm Delete',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete temple "${admin['name']}"?',
            style: const TextStyle(color: Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAdmin(admin['id']);
              },
              child: const Text('DELETE', style: TextStyle(color: Color(0xFFE40000), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String tabName) {
    bool isSelected = _selectedTab == tabName;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE40000).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isSelected ? const Color(0xFFE40000) : const Color(0xFF6B7280),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    Widget searchBar = SizedBox(
      height: 40,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search logins...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE40000))),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );

    if (isMobile) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        height: 72,
        child: Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827), size: 30),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827), size: 30),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
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
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE40000)))
                : _error.isNotEmpty
                  ? Center(child: Text(_error, style: const TextStyle(color: Color(0xFF111827))))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MediaQuery.of(context).size.width < 600
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Temple Management', style: TextStyle(color: Color(0xFF111827), fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddAdminScreen()),
                                      );
                                      _fetchAdmins();
                                    },
                                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                                    label: const Text('Add Temple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE40000),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Temple Management', style: TextStyle(color: Color(0xFF111827), fontSize: 24, fontWeight: FontWeight.bold)),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AddAdminScreen()),
                                      );
                                      _fetchAdmins();
                                    },
                                    icon: const Icon(Icons.add, size: 20, color: Colors.white),
                                    label: const Text('Add Temple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE40000),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                          const SizedBox(height: 32),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTabButton('Active'),
                                Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
                                _buildTabButton('Inactive'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_selectedTab == 'Active')
                            PaginatedTempleTable(
                              title: 'Active Logins (${_filteredAdmins.where((a) => a['status'] == 'Active').length})', 
                              tableAdmins: _filteredAdmins.where((a) => a['status'] == 'Active').toList(),
                              onFetchAdmins: _fetchAdmins,
                              onDeleteConfirmation: _showDeleteConfirmation,
                            )
                          else
                            PaginatedTempleTable(
                              title: 'Inactive Logins (${_filteredAdmins.where((a) => a['status'] == 'Inactive').length})', 
                              tableAdmins: _filteredAdmins.where((a) => a['status'] == 'Inactive').toList(),
                              onFetchAdmins: _fetchAdmins,
                              onDeleteConfirmation: _showDeleteConfirmation,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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
          _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', false, onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.pop(context); // Return to Dashboard
          }),
          _buildDrawerItem(Icons.people_rounded, 'Temple', true, onTap: () {
            Navigator.pop(context); // Just close the drawer, we are already here
          }),
          const Spacer(),
          const Divider(color: Colors.white24),
          _buildDrawerItem(Icons.logout_rounded, 'Logout', false, onTap: () async {
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

  Widget _buildPieChart(BuildContext context, List<dynamic> admins) {
    int activeCount = admins.where((a) => a['status'] == 'Active').length;
    int inactiveCount = admins.where((a) => a['status'] == 'Inactive').length;
    int total = activeCount + inactiveCount;
    
    if (total == 0) return const SizedBox();

    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
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
          const Text('Login Status Overview', style: TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                width: isMobile ? double.infinity : 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: total.toDouble() > 0 ? (total.toDouble() * 1.2) : 1,
                    barTouchData: BarTouchData(enabled: false),
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
                          BarChartRodData(
                            toY: activeCount.toDouble(),
                            color: const Color(0xFF22C55E),
                            width: 50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: inactiveCount.toDouble(),
                            color: const Color(0xFFEF4444),
                            width: 50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isMobile) const SizedBox(height: 32) else const SizedBox(width: 48),
              isMobile 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatCard('Total Logins', total.toString(), Icons.people_alt_rounded, const Color(0xFF3B82F6)),
                      const SizedBox(height: 16),
                      _buildStatCard('Active', activeCount.toString(), Icons.check_circle_rounded, const Color(0xFF22C55E)),
                      const SizedBox(height: 16),
                      _buildStatCard('Inactive', inactiveCount.toString(), Icons.cancel_rounded, const Color(0xFFEF4444)),
                    ],
                  )
                : Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Logins', total.toString(), Icons.people_alt_rounded, const Color(0xFF3B82F6))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Active', activeCount.toString(), Icons.check_circle_rounded, const Color(0xFF22C55E))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Inactive', inactiveCount.toString(), Icons.cancel_rounded, const Color(0xFFEF4444))),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
        ]
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 28)),
        ],
      ),
    );
  }
}

class PaginatedTempleTable extends StatefulWidget {
  final String title;
  final List<dynamic> tableAdmins;
  final VoidCallback onFetchAdmins;
  final void Function(Map<String, dynamic>) onDeleteConfirmation;

  const PaginatedTempleTable({
    super.key,
    required this.title,
    required this.tableAdmins,
    required this.onFetchAdmins,
    required this.onDeleteConfirmation,
  });

  @override
  State<PaginatedTempleTable> createState() => _PaginatedTempleTableState();
}

class _PaginatedTempleTableState extends State<PaginatedTempleTable> {
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void didUpdateWidget(PaginatedTempleTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tableAdmins.length != oldWidget.tableAdmins.length) {
      int maxPage = (widget.tableAdmins.length / _itemsPerPage).ceil();
      if (maxPage == 0) maxPage = 1;
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tableAdmins.isEmpty) {
      return const SizedBox.shrink();
    }
    
    int totalItems = widget.tableAdmins.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > totalItems) endIndex = totalItems;
    
    List<dynamic> currentItems = widget.tableAdmins.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(color: Color(0xFF111827), fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              double targetWidth = constraints.maxWidth < 800 ? 800 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: targetWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              const Expanded(flex: 1, child: Text('S.No', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                              const Expanded(flex: 2, child: Text('Onboard Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                              const Expanded(flex: 3, child: Text('Temple Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                              const Expanded(flex: 3, child: Text('Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                              const Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                              const Expanded(flex: 2, child: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Table Rows
                      ...currentItems.asMap().entries.map((entry) {
                        final index = startIndex + entry.key; // Global index
                        final admin = entry.value;

                        String onboardDate = '';
                        if (admin['created_at'] != null) {
                          try {
                            final dt = DateTime.parse(admin['created_at'].toString());
                            onboardDate = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
                          } catch (e) {
                            onboardDate = admin['created_at'].toString().split('T')[0];
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600))),
                                Container(width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12)),
                                Expanded(flex: 2, child: Text(onboardDate, style: const TextStyle(color: Color(0xFF4B5563)))),
                                Container(width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12)),
                                Expanded(flex: 3, child: Text(admin['name'] ?? '', style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold))),
                                Container(width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12)),
                                Expanded(flex: 3, child: Text(admin['email'] ?? '', style: const TextStyle(color: Color(0xFF4B5563)))),
                                Container(width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12)),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (admin['status'] == 'Active' ? Colors.green : Colors.red).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: (admin['status'] == 'Active' ? Colors.green : Colors.red).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: BoxDecoration(
                                              color: admin['status'] == 'Active' ? Colors.green : Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            admin['status'] ?? '',
                                            style: TextStyle(
                                              color: admin['status'] == 'Active' ? Colors.green : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1, color: Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12)),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => EditAdminScreen(adminData: admin)),
                                            );
                                            if (result == true) widget.onFetchAdmins();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                          onPressed: () => widget.onDeleteConfirmation(admin as Map<String, dynamic>),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      // Pagination Controls
                      if (totalPages > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${startIndex + 1} to $endIndex of $totalItems entries',
                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                              ),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF374151),
                                      elevation: 0,
                                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text('Previous'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF374151),
                                      elevation: 0,
                                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text('Next'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

