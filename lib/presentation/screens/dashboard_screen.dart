import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_onboarding/presentation/screens/login_screen.dart';
import 'package:temple_onboarding/presentation/screens/temple_member_details_screen.dart';
import 'package:temple_onboarding/presentation/screens/admin_list_screen.dart';
import 'package:temple_onboarding/presentation/screens/add_admin_screen.dart';
import 'package:temple_onboarding/core/api_constants.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  String _error = '';
  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  List<Map<String, dynamic>> get _searchFilteredTables {
    if (_searchQuery.isEmpty) return _tables;
    return _tables.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTables {
    var result = _searchFilteredTables;
    if (_selectedStatusFilter != 'All') {
      result = result.where((t) => (t['status'] ?? 'Active') == _selectedStatusFilter).toList();
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/admin/tables'));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _tables = List<Map<String, dynamic>>.from(data['tables'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load tables';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // ERP light background
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE40000)))
                      : _error.isNotEmpty
                          ? Center(child: Text(_error, style: const TextStyle(color: Colors.white)))
                          : RefreshIndicator(
                              onRefresh: _fetchTables,
                              color: const Color(0xFFE40000),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 16,
                                        runSpacing: 16,
                                      children: [
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width - 48 : 400,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Welcome to the Temple Portal',
                                                style: TextStyle(
                                                  color: const Color(0xFF111827),
                                                  fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 32,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                'Enterprise Multi-Temple Onboarding & Member Directory Management Portal',
                                                style: TextStyle(
                                                  color: Color(0xFF6B7280),
                                                  fontSize: 14,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Right Actions
                                        Container(
                                          width: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width - 48 : null,
                                          alignment: Alignment.centerRight,
                                          child: Wrap(
                                            spacing: 16,
                                            runSpacing: 16,
                                            alignment: WrapAlignment.end,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                               if (widget.userData['role'] == 'Super Admin')
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (context) => const AddAdminScreen()),
                                                  );
                                                  if (result == true) {
                                                    _fetchTables();
                                                  }
                                                },
                                                icon: const Icon(Icons.add, color: Colors.white),
                                                label: const Text('Add Temple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFE40000),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFD1D5DB)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.grid_view_rounded),
                                                    color: _isGridView ? const Color(0xFFE40000) : const Color(0xFF9CA3AF),
                                                    onPressed: () => setState(() => _isGridView = true),
                                                    tooltip: 'Grid View',
                                                  ),
                                                  Container(width: 1, height: 24, color: const Color(0xFFD1D5DB)),
                                                  IconButton(
                                                    icon: const Icon(Icons.table_rows_rounded),
                                                    color: !_isGridView ? const Color(0xFFE40000) : const Color(0xFF9CA3AF),
                                                    onPressed: () => setState(() => _isGridView = false),
                                                    tooltip: 'Table View',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                _buildTempleStatusOverview(context, _searchFilteredTables),
                                const SizedBox(height: 32),

                                if (_tables.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 40),
                                      child: Text(
                                        'No member tables found.',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                                      ),
                                    ),
                                  )
                                else if (_filteredTables.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 40),
                                      child: Text(
                                        'No temples match your search.',
                                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                                      ),
                                    ),
                                  )
                                else
                                  _isGridView
                                    ? _buildSeparatedGrids()
                                    : _buildTableView(),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(IconData icon, String title, String value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTempleStatusOverview(BuildContext context, List<Map<String, dynamic>> tables) {
    int activeCount = tables.where((t) => (t['status'] ?? 'Active') == 'Active').length;
    int inactiveCount = tables.where((t) => (t['status'] ?? 'Active') != 'Active').length;
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
          const Text('Temple Status Overview', style: TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              HoverScaleWidget(
                child: SizedBox(
                  height: 200,
                  width: isMobile ? double.infinity : 250,
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
                              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              width: 40,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: inactiveCount.toDouble(),
                              gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              width: 40,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMobile) const SizedBox(height: 32) else const SizedBox(width: 64),
              isMobile 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatCard('Total Temples', total.toString(), Icons.domain, const Color(0xFF60A5FA), const Color(0xFF2563EB), onTap: () => setState(() => _selectedStatusFilter = 'All'), isSelected: _selectedStatusFilter == 'All'),
                      const SizedBox(height: 16),
                      _buildStatCard('Active Temples', activeCount.toString(), Icons.check_circle_rounded, const Color(0xFF34D399), const Color(0xFF059669), onTap: () => setState(() => _selectedStatusFilter = 'Active'), isSelected: _selectedStatusFilter == 'Active'),
                      const SizedBox(height: 16),
                      _buildStatCard('Inactive Temples', inactiveCount.toString(), Icons.cancel_rounded, const Color(0xFFFB7185), const Color(0xFFE11D48), onTap: () => setState(() => _selectedStatusFilter = 'Inactive'), isSelected: _selectedStatusFilter == 'Inactive'),
                    ],
                  )
                : Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Temples', total.toString(), Icons.domain, const Color(0xFF60A5FA), const Color(0xFF2563EB), onTap: () => setState(() => _selectedStatusFilter = 'All'), isSelected: _selectedStatusFilter == 'All')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Active Temples', activeCount.toString(), Icons.check_circle_rounded, const Color(0xFF34D399), const Color(0xFF059669), onTap: () => setState(() => _selectedStatusFilter = 'Active'), isSelected: _selectedStatusFilter == 'Active')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Inactive Temples', inactiveCount.toString(), Icons.cancel_rounded, const Color(0xFFFB7185), const Color(0xFFE11D48), onTap: () => setState(() => _selectedStatusFilter = 'Inactive'), isSelected: _selectedStatusFilter == 'Inactive')),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color colorLight, Color colorDark, {VoidCallback? onTap, bool isSelected = false}) {
    return HoverScaleWidget(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSeparatedGrids() {
    final activeTables = _filteredTables.where((t) => (t['status'] ?? 'Active') == 'Active').toList();
    final inactiveTables = _filteredTables.where((t) => (t['status'] ?? 'Active') != 'Active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeTables.isNotEmpty) ...[
          Text('Active Temples (${activeTables.length})', style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              mainAxisExtent: 170,
            ),
            itemCount: activeTables.length,
            itemBuilder: (context, index) {
              return _buildTableCard(context, activeTables[index]);
            },
          ),
        ],
        if (inactiveTables.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Inactive Temples (${inactiveTables.length})', style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              mainAxisExtent: 170,
            ),
            itemCount: inactiveTables.length,
            itemBuilder: (context, index) {
              return _buildTableCard(context, inactiveTables[index]);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTableView() {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double targetWidth = constraints.maxWidth < 600 ? 600 : constraints.maxWidth;
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
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('Temple Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('Onboard Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Table Rows
                    if (_filteredTables.where((t) => (t['status'] ?? 'Active') == 'Active').isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
                        child: Text('Active Temples (${_filteredTables.where((t) => (t['status'] ?? 'Active') == 'Active').length})', style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      ..._filteredTables.where((t) => (t['status'] ?? 'Active') == 'Active').map((templeData) => _buildTableRowItem(templeData)),
                    ],

                    if (_filteredTables.where((t) => (t['status'] ?? 'Active') != 'Active').isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
                        child: Text('Inactive Temples (${_filteredTables.where((t) => (t['status'] ?? 'Active') != 'Active').length})', style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      ..._filteredTables.where((t) => (t['status'] ?? 'Active') != 'Active').map((templeData) => _buildTableRowItem(templeData)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableRowItem(Map<String, dynamic> templeData) {
    String table = templeData['table'];
    String displayTitle = templeData['name'];
    
    String onboardDate = 'N/A';
    if (templeData['created_at'] != null) {
      try {
        final dt = DateTime.parse(templeData['created_at'].toString());
        onboardDate = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
      } catch (e) {
        onboardDate = templeData['created_at'].toString().split('T')[0];
      }
    }

    Color iconColor = Colors.blue;
    IconData icon = Icons.business_center_rounded;
    
    if (displayTitle.toLowerCase().contains('kovil') || 
        displayTitle.toLowerCase().contains('gopuram') || 
        displayTitle.toLowerCase().contains('temple')) {
      iconColor = const Color(0xFFE40000);
      icon = Icons.temple_hindu_rounded;
    } else if (!displayTitle.toLowerCase().contains('ponsoft')) {
      iconColor = Colors.teal;
      icon = Icons.account_balance_rounded;
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TempleMemberDetailsScreen(
                  tableName: table,
                  templeName: displayTitle,
                ),
              ),
            );
          },
          hoverColor: const Color(0xFFF9FAFB),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
              // Temple Name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Onboard Date
              Expanded(
                flex: 2,
                child: Text(
                  onboardDate,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ((templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ((templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: (templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          templeData['status'] ?? 'Active',
                          style: TextStyle(
                            color: (templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red, 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Action
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TempleMemberDetailsScreen(
                            tableName: table,
                            templeName: displayTitle,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111827),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  Widget _buildTableCard(BuildContext context, Map<String, dynamic> templeData) {
    bool isHovered = false;
    String table = templeData['table'];
    String displayTitle = templeData['name'];

    Color iconColor = Colors.blue;
    IconData icon = Icons.business_center_rounded;

    if (displayTitle.toLowerCase().contains('kovil') ||
        displayTitle.toLowerCase().contains('gopuram') ||
        displayTitle.toLowerCase().contains('temple')) {
      iconColor = const Color(0xFFE40000);
      icon = Icons.temple_hindu_rounded;
    } else if (!displayTitle.toLowerCase().contains('ponsoft')) {
      iconColor = Colors.teal;
      icon = Icons.account_balance_rounded;
    }

    Color iconBg = iconColor.withOpacity(0.1);

    return StatefulBuilder(
      builder: (context, setHoverState) {
        return MouseRegion(
          onEnter: (_) => setHoverState(() => isHovered = true),
          onExit: (_) => setHoverState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: isHovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isHovered ? 0.1 : 0.05),
                    blurRadius: isHovered ? 15 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TempleMemberDetailsScreen(
                          tableName: table,
                          templeName: displayTitle,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: const Color(0xFFE40000).withOpacity(0.03),
                  splashColor: const Color(0xFFE40000).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: iconBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: iconColor.withOpacity(0.2)),
                              ),
                              child: Icon(icon, color: iconColor, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline_rounded, size: 14, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${templeData['total_members'] ?? 0} Members',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: ((templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: (templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sync ${templeData['status'] ?? 'Active'}',
                                    style: TextStyle(
                                      color: (templeData['status'] ?? 'Active') == 'Active' ? Colors.green : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE40000),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Text(
                                    'Open',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildHeader(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    Widget searchBar = SizedBox(
      height: 40,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search temples...',
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
          _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', true),
          _buildDrawerItem(Icons.people_rounded, 'Temple', false, onTap: () async {
            Navigator.pop(context); // Close drawer
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminListScreen(userData: widget.userData)),
            );
            _fetchTables();
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
