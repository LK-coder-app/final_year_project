// ═══════════════════════════════════════════════════════════════════
// AgriMind — Company Dashboard Screen
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = '';
  Requirement? _selectedReq;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Requirement> _filtered(List<Requirement> all) {
    final q = _searchCtrl.text.toLowerCase();
    return all.where((r) {
      final matchSearch = q.isEmpty ||
          (r.farmerName ?? '').toLowerCase().contains(q) ||
          (r.district ?? '').toLowerCase().contains(q) ||
          (r.irrigationType ?? '').toLowerCase().contains(q) ||
          (r.cropsLabel).toLowerCase().contains(q);
      final matchStatus = _statusFilter.isEmpty || r.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        if (state.dashboardLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AgriColors.emerald500),
          );
        }
        if (state.dashboardError.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(state.dashboardError,
                    style: GoogleFonts.inter(color: AgriColors.slate400)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => state.loadDashboard(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filtered = _filtered(state.requirements);

        return Row(
          children: [
            // ── Main panel ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiGrid(state),
                    const SizedBox(height: 20),
                    _buildControls(state),
                    const SizedBox(height: 16),
                    _buildTable(filtered, state),
                  ],
                ),
              ),
            ),

            // ── Detail panel ───────────────────────────────────────
            if (_selectedReq != null)
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: AgriColors.slate900,
                  border: Border(left: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: _buildDetailPanel(_selectedReq!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiGrid(AppState state) {
    final s = state.stats;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        KpiCard(
          value: '${s?.total ?? 0}',
          label: 'Total Requirements',
          emoji: '📋',
          accentColor: AgriColors.emerald500,
          onTap: () => setState(() => _statusFilter = ''),
        ),
        KpiCard(
          value: '${s?.pending ?? 0}',
          label: 'Pending Review',
          emoji: '⏳',
          accentColor: AgriColors.amber500,
          onTap: () => setState(() => _statusFilter = 'pending'),
        ),
        KpiCard(
          value: '${s?.underReview ?? 0}',
          label: 'Under Review',
          emoji: '🔍',
          accentColor: const Color(0xFF3b82f6),
          onTap: () => setState(() => _statusFilter = 'under_review'),
        ),
        KpiCard(
          value: '${s?.feasible ?? 0}',
          label: 'Feasible',
          emoji: '✅',
          accentColor: AgriColors.emerald500,
          onTap: () => setState(() => _statusFilter = 'feasible'),
        ),
        KpiCard(
          value: '${s?.quoted ?? 0}',
          label: 'Quoted',
          emoji: '💰',
          accentColor: const Color(0xFF7c3aed),
          onTap: () => setState(() => _statusFilter = 'quoted'),
        ),
        KpiCard(
          value: '${s?.avgScore.toStringAsFixed(1) ?? 0}%',
          label: 'Avg Feasibility',
          emoji: '📈',
          accentColor: AgriColors.emerald400,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildControls(AppState state) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search farmer, district, crop...',
              prefixIcon: const Icon(Icons.search, color: AgriColors.slate400, size: 18),
              isDense: true,
            ),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AgriColors.slate800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              dropdownColor: AgriColors.slate800,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              items: const [
                DropdownMenuItem(value: '', child: Text('All Statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'feasible', child: Text('Feasible')),
                DropdownMenuItem(value: 'quoted', child: Text('Quoted')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? ''),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => state.loadDashboard(),
          icon: const Icon(Icons.refresh_rounded, color: AgriColors.emerald400),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildTable(List<Requirement> items, AppState state) {
    if (items.isEmpty) {
      return AgriCard(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌾', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No requirements found.',
                    style: GoogleFonts.inter(color: AgriColors.slate400)),
              ],
            ),
          ),
        ),
      );
    }

    return AgriCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _th('ID', 70),
                _th('Farmer', 130),
                _th('Farm', 110),
                _th('Crops', 130),
                _th('Irrigation', 100),
                _th('Feasibility', 120),
                _th('Status', 100),
                _th('Actions', 100),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.map(
            (req) => _buildTableRow(req)
                .animate()
                .fadeIn(duration: 200.ms),
          ),
        ],
      ),
    );
  }

  Widget _th(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AgriColors.slate400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow(Requirement req) {
    final selected = _selectedReq?.id == req.id;
    return InkWell(
      onTap: () => setState(() => _selectedReq = selected ? null : req),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AgriColors.emerald900.withOpacity(0.2) : null,
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
            left: selected
                ? const BorderSide(color: AgriColors.emerald500, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AGM-${req.id.toString().padLeft(4, '0')}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AgriColors.emerald400,
                    ),
                  ),
                  if (req.createdAt != null)
                    Text(
                      _formatDate(req.createdAt!),
                      style: GoogleFonts.inter(fontSize: 9, color: AgriColors.slate500),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 130,
              child: Text(
                req.farmerName ?? 'N/A',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                req.landLabel,
                style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate200),
              ),
            ),
            SizedBox(
              width: 130,
              child: Text(
                req.cropsLabel,
                style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate200),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                req.irrigationType ?? 'N/A',
                style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate200),
              ),
            ),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeasibilityBar(score: req.feasibilityScore ?? 0),
                  if (req.conflictCount > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '⚠️ ${req.conflictCount} conflict${req.conflictCount > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(fontSize: 9, color: AgriColors.amber500),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: StatusBadge(status: req.status ?? 'pending'),
            ),
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.open_in_new,
                    color: AgriColors.emerald400,
                    tooltip: 'View Details',
                    onTap: () => setState(() => _selectedReq = req),
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.picture_as_pdf,
                    color: AgriColors.amber500,
                    tooltip: 'Download PDF',
                    onTap: () => _downloadPDF(req.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail Panel ─────────────────────────────────────────────────
  Widget _buildDetailPanel(Requirement req) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(gradient: AgriColors.headerGradient),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGM-${req.id.toString().padLeft(4, '0')}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AgriColors.emerald300,
                      ),
                    ),
                    Text(
                      '${req.farmerName ?? 'Unknown'} · ${req.district ?? 'N/A'}',
                      style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate400),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedReq = null),
                icon: const Icon(Icons.close, color: AgriColors.slate400),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailSection('FARMER PROFILE', [
                  DetailRow(label: 'Name', value: req.farmerName),
                  DetailRow(label: 'Phone', value: req.farmerPhone),
                  DetailRow(label: 'District', value: req.district),
                  DetailRow(label: 'Language', value: req.language, isLast: true),
                ]),
                const SizedBox(height: 14),
                _detailSection('FARM SPECIFICATIONS', [
                  DetailRow(label: 'Land Area', value: req.landLabel),
                  DetailRow(label: 'Crops', value: req.cropsLabel),
                  DetailRow(label: 'Soil Type', value: req.soilType),
                  DetailRow(
                    label: 'Budget',
                    value: req.budgetInr != null ? '₹${req.budgetInr!.toStringAsFixed(0)}' : null,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 14),
                _detailSection('WATER & POWER', [
                  DetailRow(label: 'Water Source', value: req.waterSource),
                  DetailRow(
                    label: 'Depth',
                    value: req.borewellDepthFt != null
                        ? '${req.borewellDepthFt} ft (Borewell)'
                        : 'N/A',
                  ),
                  DetailRow(label: 'Motor HP', value: req.motorHp != null ? '${req.motorHp} HP' : null),
                  DetailRow(label: 'Power Phase', value: req.powerSupplyPhase),
                  DetailRow(
                    label: 'Power Hours/Day',
                    value: req.powerHoursPerDay != null ? '${req.powerHoursPerDay}h' : null,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 14),
                _detailSection('FEASIBILITY', [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overall Score',
                                style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate400)),
                            Text(
                              '${(req.feasibilityScore ?? 0).toStringAsFixed(1)}/100',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _scoreColor(req.feasibilityScore ?? 0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FeasibilityBar(score: req.feasibilityScore ?? 0),
                      ],
                    ),
                  ),
                  if (req.feasibilityDetails != null)
                    ...req.feasibilityDetails!.entries.map(
                      (e) => DetailRow(
                        label: e.key.replaceAll('_', ' '),
                        value: e.value.toString(),
                      ),
                    ),
                ]),
                if ((req.conflicts ?? []).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _detailSection('CONFLICTS (${req.conflictCount})', [
                    ...?req.conflicts?.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: ConflictChip(conflict: Map<String, dynamic>.from(c)),
                        )),
                  ]),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Footer actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
          ),
          child: Column(
            children: [
              _StatusDropdown(req: req, onChanged: () => context.read<AppState>().loadDashboard()),
              const SizedBox(height: 10),
              GradientButton(
                label: 'Download PDF Report',
                emoji: '📄',
                onPressed: () => _downloadPDF(req.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AgriColors.emerald500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        AgriCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return AgriColors.emerald400;
    if (score >= 50) return AgriColors.amber500;
    return AgriColors.red600;
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _downloadPDF(int id) async {
    final url = ApiService.getPdfUrl(id);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatefulWidget {
  final Requirement req;
  final VoidCallback onChanged;

  const _StatusDropdown({required this.req, required this.onChanged});

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  late String _status;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _status = widget.req.status ?? 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AgriColors.slate800,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status,
                dropdownColor: AgriColors.slate800,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                  DropdownMenuItem(value: 'feasible', child: Text('Feasible')),
                  DropdownMenuItem(value: 'quoted', child: Text('Quoted')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _updating
              ? null
              : () async {
                  setState(() => _updating = true);
                  await ApiService.updateStatus(widget.req.id, _status);
                  setState(() => _updating = false);
                  widget.onChanged();
                },
          child: _updating
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
