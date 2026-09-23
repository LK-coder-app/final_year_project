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

  Future<void> _regeneratePdf() async {
    setState(() => _isRegenerating = true);
    try {
      await AdminApiService.regeneratePdf(widget.requirement.id);
      setState(() => _isRegenerating = false);
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF re-generated successfully! ✅'), backgroundColor: AdminColors.emerald600),
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
              const Text('Farmer Follow-up Link', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
              ElevatedButton.icon(
                onPressed: _isRequestingMissing ? null : _requestMissing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emerald600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                icon: _isRequestingMissing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_to_mobile, size: 14),
                label: Text(_isRequestingMissing ? 'Generating...' : 'Request Missing Data'),
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
                border: Border.all(color: AdminColors.emerald500.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _missingRequest!.smsSent ? Icons.check_circle : Icons.info_outline,
                        color: _missingRequest!.smsSent ? AdminColors.emerald400 : Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _missingRequest!.smsSent ? 'SMS Dispatched via Twilio' : 'Shareable Link Ready',
                        style: TextStyle(
                          color: _missingRequest!.smsSent ? AdminColors.emerald300 : Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _missingRequest!.formUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Form link copied to clipboard! ✅')),
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(_missingRequest!.formUrl);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.slate200,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('Open Form'),
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
