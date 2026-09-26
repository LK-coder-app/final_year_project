import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models.dart';
import '../api_service.dart';

class RequirementDetailDrawer extends StatefulWidget {
  final RequirementSummary requirement;
  final VoidCallback onUpdated;

  const RequirementDetailDrawer({
    super.key,
    required this.requirement,
    required this.onUpdated,
  });

  @override
  State<RequirementDetailDrawer> createState() => _RequirementDetailDrawerState();
}

class _RequirementDetailDrawerState extends State<RequirementDetailDrawer> {
  bool _isAnalyzing = false;
  bool _isRequestingMissing = false;
  bool _isRegenerating = false;
  bool _isUpdatingStatus = false;

  AnalysisResult? _analysis;
  RequestMissingResult? _missingRequest;
  late String _currentStatus;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.requirement.status;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final res = await AdminApiService.analyzeRequirement(widget.requirement.id);
      setState(() {
        _analysis = res;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Audit failed: $e'), backgroundColor: AdminColors.red500),
        );
      }
    }
  }

  Future<void> _requestMissing() async {
    setState(() => _isRequestingMissing = true);
    try {
      final res = await AdminApiService.requestMissingData(widget.requirement.id);
      setState(() {
        _missingRequest = res;
        _isRequestingMissing = false;
      });
    } catch (e) {
      setState(() => _isRequestingMissing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate request: $e'), backgroundColor: AdminColors.red500),
        );
      }
    }
  }

  Future<void> _regeneratePdf({bool deliverToFarmer = true}) async {
    setState(() => _isRegenerating = true);
    try {
      await AdminApiService.regeneratePdf(widget.requirement.id, deliverToFarmer: deliverToFarmer);
      setState(() => _isRegenerating = false);
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF re-generated & delivered directly to the farmer\'s dashboard! ✅'), backgroundColor: AdminColors.emerald600),
        );
      }
    } catch (e) {
      setState(() => _isRegenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regeneration failed: $e'), backgroundColor: AdminColors.red500),
        );
      }
    }
  }

  Future<void> _saveStatus() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await AdminApiService.updateStatus(
        widget.requirement.id,
        _currentStatus,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      setState(() => _isUpdatingStatus = false);
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $_currentStatus ✅'), backgroundColor: AdminColors.emerald600),
        );
      }
    } catch (e) {
      setState(() => _isUpdatingStatus = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AdminColors.red500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.requirement;
    final pdfUrl = AdminApiService.getPdfUrl(req.id);

    return Container(
      width: 600,
      color: AdminColors.slate900,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AdminColors.slate950,
              border: Border(bottom: BorderSide(color: Color(0xFF1e293b))),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AGM-${req.id.toString().padLeft(4, '0')}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('PDF v${req.pdfVersion}', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                        ),
                      ],
                    ),
                    Text(
                      req.farmerName ?? 'Unnamed Farmer',
                      style: const TextStyle(color: AdminColors.slate400, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AdminColors.slate400),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Response Notification Banner (Google Form Submitted)
                  if (req.followUpFilledAt != null || req.lastSubmittedFormData != null)
                    _buildFormResponseNotificationCard(req),

                  // Farmer Summary Card
                  _buildFarmerCard(req),
                  const SizedBox(height: 16),

                  // Feasibility & Conflicts
                  _buildFeasibilityCard(req),
                  const SizedBox(height: 16),

                  // Extracted Parameters Table
                  _buildParametersCard(req),
                  const SizedBox(height: 20),

                  // AI Requirement & PDF Audit Section
                  _buildAiAuditSection(),
                  const SizedBox(height: 20),

                  // Request Missing Data (SMS & Link)
                  _buildMissingDataSection(),
                  const SizedBox(height: 20),

                  // PDF Actions
                  _buildPdfActions(pdfUrl),
                  const SizedBox(height: 20),

                  // Status Management
                  _buildStatusSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(RequirementSummary req) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Farmer Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          const SizedBox(height: 8),
          _detailRow('Phone', req.farmerPhone ?? 'Not provided'),
          _detailRow('District', req.district ?? 'Not specified'),
          _detailRow('Language', (req.language ?? 'English').toUpperCase()),
          if (req.followUpFilledAt != null)
            _detailRow('Follow-up Filled', '✅ ${req.followUpFilledAt}'),
        ],
      ),
    );
  }

  Widget _buildFeasibilityCard(RequirementSummary req) {
    final score = req.feasibilityScore ?? 0.0;
    final color = score >= 75 ? AdminColors.emerald500 : (score >= 50 ? AdminColors.amber500 : AdminColors.red500);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Engineering Feasibility', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
              Text(
                '${score.toStringAsFixed(1)} / 100',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          if (req.conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Detected Engineering Concerns:', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...req.conflicts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${c['message'] ?? ''}', style: const TextStyle(color: AdminColors.slate300, fontSize: 11)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildParametersCard(RequirementSummary req) {
    final slots = req.extractedSlots;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Captured Specifications', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          const SizedBox(height: 8),
          _detailRow('Land Area', '${slots['land_size'] ?? 'N/A'} ${slots['land_unit'] ?? 'acres'}'),
          _detailRow('Crops', (slots['crop_types'] as List?)?.join(', ') ?? 'N/A'),
          _detailRow('Water Source', slots['water_source'] ?? 'N/A'),
          _detailRow('Motor HP', '${slots['motor_hp'] ?? 'N/A'} HP'),
          _detailRow('Irrigation Type', slots['irrigation_type'] ?? 'N/A'),
          _detailRow('Soil Type', slots['soil_type'] ?? 'Not specified'),
          _detailRow('Borewell Depth', slots['borewell_depth_ft'] != null ? '${slots['borewell_depth_ft']} ft' : 'Not specified'),
          _detailRow('Power Phase', slots['power_supply_phase'] ?? 'Not specified'),
          _detailRow('Budget', slots['budget_inr'] != null ? '₹${slots['budget_inr']}' : 'Not specified'),
        ],
      ),
    );
  }

  Widget _buildAiAuditSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131c31),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.indigo600.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('AI Requirement & PDF Audit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _runAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                icon: _isAnalyzing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.analytics_outlined, size: 14),
                label: Text(_isAnalyzing ? 'Auditing...' : 'Run Audit'),
              ),
            ],
          ),

          if (_analysis != null) ...[
            const SizedBox(height: 12),
            // Missing Required
            if (_analysis!.missingRequired.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ Missing Required Fields (Highlighted in PDF):', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _analysis!.missingRequired.map((m) => m['label']).join(', '),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isRequestingMissing ? null : _requestMissing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673ab7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.send_to_mobile, size: 12),
                      label: const Text('Auto-Generate Google Form & Send to Farmer Account'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Analysis Narrative Text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.slate900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                _analysis!.analysisText,
                style: const TextStyle(color: AdminColors.slate300, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const Map<String, String> _fieldDisplayLabels = {
    'land_size': 'Farm Land Area',
    'land_unit': 'Land Unit',
    'crop_types': 'Target Crops',
    'water_source': 'Water Source',
    'motor_hp': 'Pump Motor HP',
    'irrigation_type': 'Irrigation Method',
    'soil_type': 'Soil Type',
    'borewell_depth_ft': 'Borewell Depth (feet)',
    'open_well_depth_ft': 'Open Well Depth (feet)',
    'power_supply_phase': 'Power Supply Phase',
    'power_hours_per_day': 'Power Hours / Day',
    'district': 'District',
    'budget_inr': 'Budget (₹ INR)',
  };

  Widget _buildFormResponseNotificationCard(RequirementSummary req) {
    final updatedKeys = req.lastSubmittedFormData?.keys.toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2e1065).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFc084fc), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFc084fc), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '🔔 Google Form Response Submitted!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Updated', style: TextStyle(color: Color(0xFFd8b4fe), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The farmer has submitted missing information via Google Form on ${req.followUpFilledAt ?? 'recently'}. ${updatedKeys.isNotEmpty ? '(${updatedKeys.length} parameter(s) updated)' : ''}',
            style: const TextStyle(color: AdminColors.slate300, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showReviewFormDialog(req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7c3aed),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.rate_review, size: 14),
                label: const Text('Review Submitted Form Data'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isRegenerating ? null : _regeneratePdf,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.emerald300,
                  side: const BorderSide(color: AdminColors.emerald500),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                icon: _isRegenerating
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.emerald400))
                    : const Icon(Icons.autorenew, size: 14),
                label: const Text('Regenerate PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReviewFormDialog(RequirementSummary req) {
    final submitted = req.lastSubmittedFormData ?? req.extractedSlots;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AdminColors.slate900,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Color(0xFFc084fc), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review Google Form Submission (AGM-${req.id.toString().padLeft(4, '0')})',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submitted by ${req.farmerName ?? 'Farmer'} (${req.farmerPhone ?? 'No Phone'}) on ${req.followUpFilledAt ?? 'recently'}',
                    style: const TextStyle(color: AdminColors.slate400, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AdminColors.slate950,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1e293b)),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.5),
                      },
                      border: const TableBorder(
                        horizontalInside: BorderSide(color: AdminColors.slate800, width: 1),
                      ),
                      children: submitted.entries.where((e) => !e.key.startsWith('_')).map((entry) {
                        final label = _fieldDisplayLabels[entry.key] ?? entry.key;
                        final valStr = entry.value is List ? (entry.value as List).join(', ') : '${entry.value}';
                        final isNewField = req.lastSubmittedFormData?.containsKey(entry.key) ?? false;

                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                label,
                                style: const TextStyle(color: AdminColors.slate300, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      valStr,
                                      style: TextStyle(
                                        color: isNewField ? AdminColors.emerald300 : Colors.white,
                                        fontWeight: isNewField ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (isNewField)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AdminColors.emerald500.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Updated', style: TextStyle(color: AdminColors.emerald400, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: AdminColors.slate400)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _regeneratePdf(deliverToFarmer: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.emerald600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.verified, size: 14),
              label: const Text('Approve, Regenerate PDF & Deliver to Farmer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMissingDataSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment, color: Color(0xFFc084fc), size: 16),
                  SizedBox(width: 6),
                  Text('Request Missing Data (Google Form)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isRequestingMissing ? null : _requestMissing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673ab7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                icon: _isRequestingMissing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_to_mobile, size: 14),
                label: Text(_isRequestingMissing ? 'Generating...' : 'Generate Google Form'),
              ),
            ],
          ),

          if (_missingRequest != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.slate900,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF673ab7).withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFc084fc),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Google Form Sent to Farmer Account & Dispatched',
                        style: TextStyle(
                          color: Color(0xFFd8b4fe),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Farmer Account Alert Active', style: TextStyle(color: Color(0xFFe9d5ff), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      if (_missingRequest!.smsSent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.emerald500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SMS Sent', style: TextStyle(color: AdminColors.emerald400, fontSize: 9)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _missingRequest!.formUrl,
                    style: const TextStyle(color: AdminColors.slate300, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(_missingRequest!.formUrl);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF673ab7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('Open Google Form'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _missingRequest!.formUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Google Form link copied to clipboard! ✅')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.slate200,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        icon: const Icon(Icons.copy, size: 12),
                        label: const Text('Copy Form Link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfActions(String pdfUrl) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(pdfUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.slate700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('View / Download PDF'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isRegenerating ? null : _regeneratePdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.emerald700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isRegenerating
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, size: 16),
            label: Text(_isRegenerating ? 'Regenerating...' : 'Regenerate PDF'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    const statuses = ['pending', 'under_review', 'feasible', 'quoted', 'rejected'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Update Submission Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _currentStatus,
            dropdownColor: AdminColors.slate800,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AdminColors.slate900,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase()))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _currentStatus = val);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add internal engineering note (optional)...',
              hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              filled: true,
              fillColor: AdminColors.slate900,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isUpdatingStatus ? null : _saveStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.indigo600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(_isUpdatingStatus ? 'Saving...' : 'Save Status Update'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AdminColors.slate400, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
