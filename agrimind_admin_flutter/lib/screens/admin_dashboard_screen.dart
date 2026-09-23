import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models.dart';
import '../api_service.dart';
import '../drawers/requirement_detail_drawer.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  int _activeTabIndex = 0; // 0: Submissions & Audit, 1: Farmer Accounts
  DashboardStats? _stats;
  List<RequirementSummary> _allRequirements = [];
  List<RequirementSummary> _filtered = [];

  List<FarmerAccount> _farmers = [];
  List<FarmerAccount> _filteredFarmers = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _farmerSearchController = TextEditingController();
  String _selectedStatus = '';
  String _selectedDistrict = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _farmerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await AdminApiService.getStats();
      final reqs = await AdminApiService.getRequirements();
      List<FarmerAccount> farmers = [];
      try {
        farmers = await AdminApiService.getFarmers();
      } catch (_) {}

      setState(() {
        _stats = stats;
        _allRequirements = reqs;
        _farmers = farmers;
        _applyFilters();
        _applyFarmerFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard data: $e'), backgroundColor: AdminColors.red500),
        );
      }
    }
  }

  void _applyFarmerFilter() {
    final query = _farmerSearchController.text.toLowerCase().trim();
    setState(() {
      _filteredFarmers = _farmers.where((f) {
        if (query.isEmpty) return true;
        return f.fullName.toLowerCase().contains(query) ||
            f.email.toLowerCase().contains(query) ||
            (f.phone?.toLowerCase().contains(query) ?? false) ||
            '${f.id}'.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleFarmerStatus(FarmerAccount farmer) async {
    try {
      final updated = await AdminApiService.toggleFarmerStatus(farmer.id, !farmer.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated.fullName} is now ${updated.isActive ? "Active" : "Suspended"} ✅'),
            backgroundColor: updated.isActive ? AdminColors.emerald600 : Colors.amber.shade900,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update farmer: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = _allRequirements.where((r) {
        final matchesQuery = query.isEmpty ||
            (r.farmerName?.toLowerCase().contains(query) ?? false) ||
            (r.district?.toLowerCase().contains(query) ?? false) ||
            (r.cropTypes?.any((c) => c.toLowerCase().contains(query)) ?? false) ||
            'agm-${r.id}'.contains(query);

        final matchesStatus = _selectedStatus.isEmpty || r.status == _selectedStatus;
        final matchesDistrict = _selectedDistrict.isEmpty || (r.district == _selectedDistrict);

        return matchesQuery && matchesStatus && matchesDistrict;
      }).toList();
    });
  }

  void _openDetailDrawer(RequirementSummary req) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: RequirementDetailDrawer(
              requirement: req,
              onUpdated: _loadData,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'AgriMind',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AdminColors.violet600, AdminColors.indigo600]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Admin Console', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 20),

            // Navigation Tabs
            Container(
              decoration: BoxDecoration(
                color: AdminColors.slate900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _activeTabIndex = 0),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 0 ? AdminColors.indigo600 : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dashboard_outlined, size: 14, color: _activeTabIndex == 0 ? Colors.white : AdminColors.slate400),
                          const SizedBox(width: 6),
                          Text(
                            'Submissions & Audit (${_allRequirements.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _activeTabIndex == 0 ? Colors.white : AdminColors.slate300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _activeTabIndex = 1),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 1 ? AdminColors.indigo600 : Colors.transparent,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_alt_outlined, size: 14, color: _activeTabIndex == 1 ? Colors.white : AdminColors.slate400),
                          const SizedBox(width: 6),
                          Text(
                            'Farmer Accounts (${_farmers.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _activeTabIndex == 1 ? Colors.white : AdminColors.slate300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Admin Profile Pill
          if (AdminApiService.currentUser != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminColors.slate800,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 13, color: AdminColors.violet400),
                  const SizedBox(width: 5),
                  Text(
                    AdminApiService.currentUser!.fullName,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh, color: AdminColors.slate400),
            onPressed: _loadData,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
            onPressed: () {
              AdminApiService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.emerald500))
          : _activeTabIndex == 0
              ? _buildSubmissionsView()
              : _buildFarmerAccountsView(),
    );
  }

  Widget _buildSubmissionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Row
          _buildKpiRow(),
          const SizedBox(height: 24),

          // Filter & Search Toolbar
          _buildFilterBar(),
          const SizedBox(height: 16),

          // Submissions Table
          _buildTable(),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final s = _stats;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        return GridView.count(
          crossAxisCount: isNarrow ? 3 : 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isNarrow ? 1.4 : 1.7,
          children: [
            _kpiCard('Total Submissions', '${s?.total ?? 0}', Colors.white),
            _kpiCard('Pending', '${s?.pending ?? 0}', AdminColors.amber500),
            _kpiCard('Under Review', '${s?.underReview ?? 0}', Colors.lightBlueAccent),
            _kpiCard('Feasible', '${s?.feasible ?? 0}', AdminColors.emerald400),
            _kpiCard('Quoted', '${s?.quoted ?? 0}', Colors.indigoAccent),
            _kpiCard('Avg Feasibility', '${s?.avgScore.toStringAsFixed(1) ?? '0.0'}%', AdminColors.emerald300),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AdminColors.slate400, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final districts = _allRequirements.map((r) => r.district).where((d) => d != null && d.isNotEmpty).toSet().toList();

    return Row(
      children: [
        // Search Input
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search farmer, crop, district, or ID...',
              hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AdminColors.slate400, size: 18),
              filled: true,
              fillColor: AdminColors.slate800,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        const SizedBox(width: 12),

        // Status Filter
        DropdownButton<String>(
          value: _selectedStatus,
          dropdownColor: AdminColors.slate800,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: '', child: Text('All Statuses')),
            DropdownMenuItem(value: 'updated', child: Text('🔔 Form Updated')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
            DropdownMenuItem(value: 'feasible', child: Text('Feasible')),
            DropdownMenuItem(value: 'quoted', child: Text('Quoted')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: (val) {
            setState(() => _selectedStatus = val ?? '');
            _applyFilters();
          },
        ),
        const SizedBox(width: 12),

        // District Filter
        if (districts.isNotEmpty)
          DropdownButton<String>(
            value: _selectedDistrict,
            dropdownColor: AdminColors.slate800,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Districts')),
              ...districts.map((d) => DropdownMenuItem(value: d, child: Text(d!))),
            ],
            onChanged: (val) {
              setState(() => _selectedDistrict = val ?? '');
              _applyFilters();
            },
          ),
      ],
    );
  }

  Widget _buildTable() {
    if (_filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Text('No submissions found matching criteria.', style: TextStyle(color: AdminColors.slate500)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AdminColors.slate900),
            headingTextStyle: const TextStyle(color: AdminColors.slate400, fontSize: 12, fontWeight: FontWeight.bold),
            dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('REPORT ID')),
              DataColumn(label: Text('FARMER')),
              DataColumn(label: Text('DISTRICT / CROPS')),
              DataColumn(label: Text('LAND AREA')),
              DataColumn(label: Text('FEASIBILITY')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: _filtered.map((r) {
              final score = r.feasibilityScore ?? 0.0;
              final scoreColor = score >= 75 ? AdminColors.emerald500 : (score >= 50 ? AdminColors.amber500 : AdminColors.red500);

              return DataRow(
                cells: [
                  // ID
                  DataCell(
                    Text('AGM-${r.id.toString().padLeft(4, '0')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  // Farmer
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(r.farmerName ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (r.followUpFilledAt != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purpleAccent, width: 0.8),
                                ),
                                child: const Text(
                                  '🔔 Form Updated',
                                  style: TextStyle(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (r.farmerPhone != null)
                          Text(r.farmerPhone!, style: const TextStyle(color: AdminColors.slate400, fontSize: 10)),
                      ],
                    ),
                  ),
                  // District / Crop
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.district ?? 'Not set', style: const TextStyle(color: AdminColors.slate200)),
                        Text((r.cropTypes ?? []).join(', '), style: const TextStyle(color: AdminColors.slate400, fontSize: 10)),
                      ],
                    ),
                  ),
                  // Land Area
                  DataCell(
                    Text('${r.landSize ?? '-'} ${r.landUnit ?? 'acres'}'),
                  ),
                  // Feasibility
                  DataCell(
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              backgroundColor: const Color(0xFF334155),
                              valueColor: AlwaysStoppedAnimation(scoreColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${score.toStringAsFixed(0)}%', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Status
                  DataCell(_statusBadge(r.status)),
                  // Actions
                  DataCell(
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openDetailDrawer(r),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.indigo600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          icon: const Icon(Icons.manage_search, size: 14),
                          label: const Text('Audit / Inspect'),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Open PDF',
                          icon: const Icon(Icons.picture_as_pdf, color: AdminColors.emerald400, size: 18),
                          onPressed: () async {
                            final uri = Uri.parse(AdminApiService.getPdfUrl(r.id));
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color text;

    switch (status) {
      case 'updated':
        bg = Colors.purple.withValues(alpha: 0.2);
        text = const Color(0xFFc084fc);
        break;
      case 'pending':
        bg = Colors.amber.withValues(alpha: 0.15);
        text = Colors.amber;
        break;
      case 'under_review':
        bg = Colors.blue.withValues(alpha: 0.15);
        text = Colors.lightBlueAccent;
        break;
      case 'feasible':
        bg = Colors.green.withValues(alpha: 0.15);
        text = AdminColors.emerald400;
        break;
      case 'quoted':
        bg = Colors.purple.withValues(alpha: 0.15);
        text = Colors.purpleAccent;
        break;
      default:
        bg = Colors.red.withValues(alpha: 0.15);
        text = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Farmer Accounts Management View ──────────────────────────────────────────

  Widget _buildFarmerAccountsView() {
    final activeCount = _farmers.where((f) => f.isActive).length;
    final suspendedCount = _farmers.where((f) => !f.isActive).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Farmer KPIs
          Row(
            children: [
              Expanded(
                child: _kpiCard('Total Farmers Registered', '${_farmers.length}', Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard('Active Accounts', '$activeCount', AdminColors.emerald400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard('Suspended / Inactive', '$suspendedCount', Colors.amberAccent),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _farmerSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search farmer by name, email, or mobile number...',
                    hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AdminColors.slate400, size: 18),
                    filled: true,
                    fillColor: AdminColors.slate800,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                  onChanged: (_) => _applyFarmerFilter(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Accounts'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Farmers Table
          if (_filteredFarmers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AdminColors.slate800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Center(
                child: Text('No farmer accounts found matching query.', style: TextStyle(color: AdminColors.slate400)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AdminColors.slate800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AdminColors.slate900),
                    headingTextStyle: const TextStyle(color: AdminColors.slate400, fontSize: 12, fontWeight: FontWeight.bold),
                    dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    horizontalMargin: 16,
                    columnSpacing: 22,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('FARMER NAME')),
                      DataColumn(label: Text('LOGIN EMAIL')),
                      DataColumn(label: Text('MOBILE NUMBER')),
                      DataColumn(label: Text('REGISTERED ON')),
                      DataColumn(label: Text('ACCOUNT STATUS')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: _filteredFarmers.map((f) {
                      return DataRow(
                        cells: [
                          DataCell(Text('#FARM-${f.id.toString().padLeft(4, '0')}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: AdminColors.indigo600,
                                  child: Text(
                                    f.fullName.isNotEmpty ? f.fullName[0].toUpperCase() : 'F',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(f.email, style: const TextStyle(color: AdminColors.slate300))),
                          DataCell(Text(f.phone ?? 'Not provided', style: const TextStyle(color: AdminColors.slate400))),
                          DataCell(Text(f.createdAt != null ? f.createdAt!.split('T').first : 'Recent', style: const TextStyle(color: AdminColors.slate400, fontSize: 11))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: f.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                f.isActive ? 'ACTIVE' : 'SUSPENDED',
                                style: TextStyle(
                                  color: f.isActive ? AdminColors.emerald400 : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _toggleFarmerStatus(f),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: f.isActive ? Colors.redAccent : AdminColors.emerald400,
                                    side: BorderSide(color: f.isActive ? Colors.redAccent.withValues(alpha: 0.5) : AdminColors.emerald500.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                  icon: Icon(f.isActive ? Icons.block : Icons.check_circle, size: 13),
                                  label: Text(f.isActive ? 'Suspend' : 'Activate'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _activeTabIndex = 0;
                                      _searchController.text = f.fullName;
                                      _applyFilters();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminColors.slate700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 11),
                                  ),
                                  icon: const Icon(Icons.description_outlined, size: 13),
                                  label: const Text('Applications'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
