import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../api_service.dart';

class MissingDataFormScreen extends StatefulWidget {
  final String token;

  const MissingDataFormScreen({super.key, required this.token});

  @override
  State<MissingDataFormScreen> createState() => _MissingDataFormScreenState();
}

class _MissingDataFormScreenState extends State<MissingDataFormScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _formData;
  bool _submitSuccess = false;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _dropdownValues = {};

  final Map<String, List<String>> _dropdownOptions = {
    'water_source': ['Borewell', 'Open Well', 'Canal', 'River', 'Tank/Pond', 'Rainwater'],
    'soil_type': ['Red Loam', 'Black Cotton', 'Alluvial Clay', 'Sandy Loam', 'Sandy', 'Clay'],
    'irrigation_type': ['Drip', 'Sprinkler', 'Micro Sprinkler', 'Flood', 'Furrow'],
    'power_supply_phase': ['Single Phase', 'Three Phase'],
    'land_unit': ['acres', 'hectares', 'cents'],
  };

  final Map<String, String> _tamilLabels = {
    'land_size': 'நிலப் பரப்பு (Land Area)',
    'land_unit': 'அலகு (Unit: acres/hectares)',
    'crop_types': 'பயிர் வகைகள் (Crops: Sugarcane, Banana, etc.)',
    'water_source': 'நீர் ஆதாரம் (Water Source)',
    'motor_hp': 'மோட்டார் திறன் (Motor HP)',
    'irrigation_type': 'பாசன முறை (Irrigation Type)',
    'soil_type': 'மண் வகை (Soil Type)',
    'borewell_depth_ft': 'போர்வெல் ஆழம் (Borewell Depth in feet)',
    'open_well_depth_ft': 'கிணறு ஆழம் (Well Depth in feet)',
    'power_supply_phase': 'மின் கட்டம் (Single / Three Phase)',
    'power_hours_per_day': 'மின்சாரம் கிடைக்கும் நேரம் (Hours/Day)',
    'district': 'மாவட்டம் (District)',
    'budget_inr': 'பட்ஜெட் (Budget in INR)',
  };

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getFormByToken(widget.token);
      final missing = (data['missing_fields'] as List? ?? []);

      for (var f in missing) {
        final key = f['field'] as String;
        if (_dropdownOptions.containsKey(key)) {
          _dropdownValues[key] = _dropdownOptions[key]!.first;
        } else {
          _controllers[key] = TextEditingController();
        }
      }

      setState(() {
        _formData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_formData == null) return;
    setState(() => _isSubmitting = true);

    final reqId = _formData!['requirement_id'] as int;
    final Map<String, dynamic> filled = {};

    for (var entry in _controllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        if (entry.key == 'land_size' || entry.key == 'motor_hp' || entry.key.contains('depth') || entry.key.contains('hours') || entry.key == 'budget_inr') {
          filled[entry.key] = double.tryParse(val) ?? val;
        } else if (entry.key == 'crop_types') {
          filled[entry.key] = val.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        } else {
          filled[entry.key] = val;
        }
      }
    }

    for (var entry in _dropdownValues.entries) {
      filled[entry.key] = entry.value;
    }

    try {
      await ApiService.fillMissingData(
        reqId: reqId,
        token: widget.token,
        filledData: filled,
      );

      setState(() {
        _isSubmitting = false;
        _submitSuccess = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🌿', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'AgriMind',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AgriColors.emerald900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Farmer Form', style: TextStyle(fontSize: 11, color: AgriColors.emerald300)),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AgriColors.emerald500))
              : _errorMessage != null
                  ? _buildErrorView()
                  : _submitSuccess
                      ? _buildSuccessView()
                      : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          Text('Invalid or Expired Link', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_errorMessage ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AgriColors.slate400)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            style: ElevatedButton.styleFrom(backgroundColor: AgriColors.emerald600),
            child: const Text('Go to Farmer Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final reqId = _formData?['requirement_id'] ?? 0;
    final pdfUrl = ApiService.getPdfUrl(reqId);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: AgriColors.emerald400, size: 64),
          const SizedBox(height: 16),
          Text(
            'Information Updated!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your additional details have been saved, and your official requirement report has been re-generated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AgriColors.slate300, fontSize: 14),
          ),
          const SizedBox(height: 24),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Updated PDF Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final farmerName = _formData?['farmer_name'] ?? 'Farmer';
    final reportId = _formData?['report_id'] ?? '';
    final missing = (_formData?['missing_fields'] as List? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AgriColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $farmerName!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please provide the missing details below to finalize your infrastructure report ($reportId).',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Required & Missing Information (${missing.length} fields)',
            style: const TextStyle(color: AgriColors.slate200, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),

          ...missing.map((field) {
            final key = field['field'] as String;
            final label = _tamilLabels[key] ?? field['label'] as String;
            final isDropdown = _dropdownOptions.containsKey(key);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AgriColors.slate800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: AgriColors.slate200, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (isDropdown)
                    DropdownButtonFormField<String>(
                      value: _dropdownValues[key],
                      dropdownColor: AgriColors.slate800,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AgriColors.slate900,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _dropdownOptions[key]!.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dropdownValues[key] = val);
                      },
                    )
                  else
                    TextField(
                      controller: _controllers[key],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter $key...',
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        filled: true,
                        fillColor: AgriColors.slate900,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriColors.emerald600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_isSubmitting ? 'Updating...' : 'Submit & Regenerate PDF Report'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
