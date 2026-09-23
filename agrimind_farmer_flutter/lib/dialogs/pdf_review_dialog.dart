import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models.dart';
import '../api_service.dart';

class PdfReviewDialog extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic> slots;
  final List<ConflictItem> conflicts;
  final double completionPct;
  final Function(SubmitResult result) onSubmitted;

  const PdfReviewDialog({
    super.key,
    required this.sessionId,
    required this.slots,
    required this.conflicts,
    required this.completionPct,
    required this.onSubmitted,
  });

  @override
  State<PdfReviewDialog> createState() => _PdfReviewDialogState();
}

class _PdfReviewDialogState extends State<PdfReviewDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  SubmitResult? _submittedResult;
  String? _errorMessage;

  static const List<Map<String, dynamic>> _slotMeta = [
    {'key': 'land_size', 'label': 'Land Area', 'icon': '🌱', 'required': true},
    {'key': 'crop_types', 'label': 'Crop Types', 'icon': '🌾', 'required': true},
    {'key': 'water_source', 'label': 'Water Source', 'icon': '💧', 'required': true},
    {'key': 'motor_hp', 'label': 'Motor HP', 'icon': '⚡', 'required': true},
    {'key': 'irrigation_type', 'label': 'Irrigation Type', 'icon': '🚿', 'required': true},
    {'key': 'soil_type', 'label': 'Soil Type', 'icon': '🪨', 'required': false},
    {'key': 'borewell_depth_ft', 'label': 'Borewell Depth', 'icon': '🕳️', 'required': false},
    {'key': 'open_well_depth_ft', 'label': 'Well Depth', 'icon': '🪣', 'required': false},
    {'key': 'power_supply_phase', 'label': 'Power Phase', 'icon': '🔌', 'required': false},
    {'key': 'power_hours_per_day', 'label': 'Power Hours/Day', 'icon': '🕐', 'required': false},
    {'key': 'district', 'label': 'District', 'icon': '📍', 'required': false},
    {'key': 'budget_inr', 'label': 'Budget (₹)', 'icon': '💰', 'required': false},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter farmer name before generating PDF.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.submitRequirement(
        sessionId: widget.sessionId,
        farmerName: name,
        farmerPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      setState(() {
        _submittedResult = result;
        _isSubmitting = false;
      });

      widget.onSubmitted(result);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingRequired = _slotMeta.where((m) {
      if (m['required'] != true) return false;
      final val = widget.slots[m['key']];
      return val == null || val == '' || (val is List && val.isEmpty);
    }).map((m) => m['label'] as String).toList();

    return Dialog(
      backgroundColor: AgriColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submittedResult != null
              ? _buildSuccessView(_submittedResult!)
              : _buildReviewForm(missingRequired),
        ),
      ),
    );
  }

  Widget _buildReviewForm(List<String> missingRequired) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AgriColors.emerald900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('📋', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Before PDF Generation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const Text(
                      'Check extracted parameters before submitting to Admin',
                      style: TextStyle(color: AgriColors.slate400, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AgriColors.slate400),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF334155), height: 1),
        const SizedBox(height: 16),

        // Scrollable content
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Farmer Details
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Farmer Name *',
                          labelStyle: const TextStyle(color: AgriColors.slate400, fontSize: 13),
                          hintText: 'e.g. Murugan K.',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          filled: true,
                          fillColor: AgriColors.slate800,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(color: AgriColors.slate400, fontSize: 13),
                          hintText: '+91 XXXXX XXXXX',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          filled: true,
                          fillColor: AgriColors.slate800,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Extracted parameters table
                const Text(
                  'Extracted Specifications',
                  style: TextStyle(color: AgriColors.slate200, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AgriColors.slate800,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: _slotMeta.map((meta) {
                      final key = meta['key'] as String;
                      final label = meta['label'] as String;
                      final icon = meta['icon'] as String;
                      final isReq = meta['required'] as bool;
                      final val = widget.slots[key];
                      final hasVal = val != null && val != '' && (!(val is List) || val.isNotEmpty);

                      String displayVal = '-';
                      if (hasVal) {
                        if (key == 'land_size') {
                          displayVal = '$val ${widget.slots['land_unit'] ?? 'acres'}';
                        } else if (val is List) {
                          displayVal = val.join(', ');
                        } else if (key == 'budget_inr') {
                          displayVal = '₹$val';
                        } else if (key.contains('depth')) {
                          displayVal = '$val ft';
                        } else if (key == 'motor_hp') {
                          displayVal = '$val HP';
                        } else {
                          displayVal = '$val';
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFF1e293b), width: 1)),
                        ),
                        child: Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 140,
                              child: Text(
                                label + (isReq ? ' *' : ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isReq ? AgriColors.slate200 : AgriColors.slate400,
                                  fontWeight: isReq ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                displayVal,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasVal ? AgriColors.emerald300 : AgriColors.slate500,
                                  fontWeight: hasVal ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasVal
                                    ? Colors.green.withOpacity(0.15)
                                    : (isReq ? Colors.red.withOpacity(0.15) : Colors.grey.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hasVal
                                    ? 'Captured'
                                    : (isReq ? 'Missing' : 'Optional'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: hasVal
                                      ? AgriColors.emerald400
                                      : (isReq ? Colors.redAccent : AgriColors.slate400),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Missing fields warning banner
                if (missingRequired.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missing required fields: ${missingRequired.join(', ')}. '
                            'The generated PDF will highlight these fields in red. '
                            'You may still submit, and admin will follow up.',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: Color(0xFF334155), height: 1),
        const SizedBox(height: 16),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AgriColors.slate400)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriColors.emerald600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(_isSubmitting ? 'Generating & Submitting...' : 'Generate Report & Submit'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView(SubmitResult result) {
    final pdfUrl = ApiService.getPdfUrl(result.requirementId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AgriColors.emerald400, size: 64),
        const SizedBox(height: 16),
        Text(
          'Report Submitted Successfully!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Report ID: AGM-${result.requirementId.toString().padLeft(4, '0')}',
          style: const TextStyle(color: AgriColors.emerald300, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Feasibility Score: ${result.feasibilityScore.toStringAsFixed(1)} / 100',
          style: const TextStyle(color: AgriColors.slate300, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AgriColors.slate800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'The PDF report has been generated and dispatched to the Admin Dashboard for engineering review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AgriColors.slate400, fontSize: 12),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(pdfUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriColors.emerald600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Generated PDF'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AgriColors.slate200,
                side: const BorderSide(color: Color(0xFF475569)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }
}
