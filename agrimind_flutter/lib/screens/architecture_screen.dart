// ═══════════════════════════════════════════════════════════════════
// AgriMind — Architecture & Settings Screen
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class ArchitectureScreen extends StatelessWidget {
  const ArchitectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(),
          const SizedBox(height: 28),
          _flowSection(),
          const SizedBox(height: 28),
          _techStack(),
          const SizedBox(height: 28),
          _llmConfig(context),
          const SizedBox(height: 28),
          _researchSection(),
        ],
      ),
    );
  }

  Widget _hero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: double.infinity),
        Text(
          'AgriMind System Architecture',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [AgriColors.emerald400, AgriColors.emerald300],
              ).createShader(const Rect.fromLTWH(0, 0, 400, 40)),
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 12),
        Text(
          'AI-powered multilingual conversational pipeline that transforms unstructured farmer dialogue\n(Tamil · English · Tanglish) into verified engineering-validated irrigation requirement specifications.',
          style: GoogleFonts.inter(fontSize: 13, color: AgriColors.slate400, height: 1.6),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Sri Ramakrishna Engineering College · Dept. of AI & Data Science · Batch 22AD1010',
          style: GoogleFonts.inter(fontSize: 11, color: AgriColors.slate500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _flowSection() {
    final nodes = [
      _FlowNode('🧑‍🌾', 'Farmer Input', 'Voice/Text\nTamil · English · Tanglish'),
      _FlowNode('🧠', 'NLU Engine', 'Gemini/OpenAI\n/Local Extraction'),
      _FlowNode('🗂️', 'Dialogue Tracker', 'Session memory\n& slot completion'),
      _FlowNode('⚙️', 'Conflict Detector', '5 engineering\nrule checks'),
      _FlowNode('🎯', 'Adaptive Q&A', 'Targeted multilingual\nfollow-ups'),
      _FlowNode('📄', 'PDF Report', 'Verified technical\nspecification'),
      _FlowNode('🏢', 'Dashboard', 'Review, assess\n& quote'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Process Flow'),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: nodes.indexed
                .expand((entry) {
                  final (i, node) = entry;
                  return [
                    _buildFlowNode(node, i),
                    if (i < nodes.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: AgriColors.emerald600, size: 20),
                      ),
                  ];
                })
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowNode(_FlowNode node, int index) {
    return AgriCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AgriColors.headerGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AgriColors.emerald700.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(node.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              node.label,
              style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              node.desc,
              style: GoogleFonts.inter(fontSize: 9, color: AgriColors.slate400, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _techStack() {
    final techs = [
      _Tech('⚡', 'FastAPI', 'High-performance async Python API with OpenAPI docs'),
      _Tech('🌿', 'Google Gemini', 'Primary LLM for Tamil/English/Tanglish NLU'),
      _Tech('🤖', 'OpenAI GPT', 'Alternative LLM provider for slot extraction'),
      _Tech('🗄️', 'SQLAlchemy', 'ORM with zero-config SQLite database'),
      _Tech('📄', 'ReportLab', 'Publication-quality PDF report generation'),
      _Tech('🎙️', 'Web Speech API', 'Browser-native Tamil/English voice recognition'),
      _Tech('🔀', 'Hybrid NLU', 'Tamil agri dictionary + LLM with offline fallback'),
      _Tech('🦋', 'Flutter', 'Cross-platform desktop & web frontend'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Technology Stack'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: techs.indexed
              .map((entry) {
                final (i, t) = entry;
                return SizedBox(
                  width: 220,
                  child: AgriCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 8),
                        Text(t.name,
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(t.desc,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AgriColors.slate400, height: 1.4)),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 60).ms),
                );
              })
              .toList(),
        ),
      ],
    );
  }

  Widget _llmConfig(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('LLM Configuration'),
            const SizedBox(height: 14),
            AgriCard(
              borderColor: AgriColors.emerald700.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Provider: ${_providerLabel(state.llmProvider)}',
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AgriColors.emerald400),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Switch between Gemini, OpenAI, or the built-in Local Engine. Local Engine works offline with no API key.',
                    style: GoogleFonts.inter(fontSize: 12, color: AgriColors.slate400),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ProviderBtn(label: '🔧 Local Engine', value: 'local', current: state.llmProvider),
                      const SizedBox(width: 8),
                      _ProviderBtn(label: '🌿 Gemini', value: 'gemini', current: state.llmProvider),
                      const SizedBox(width: 8),
                      _ProviderBtn(label: '🤖 OpenAI', value: 'openai', current: state.llmProvider),
                    ],
                  ),
                  if (state.llmProvider != 'local') ...[
                    const SizedBox(height: 14),
                    _ApiKeyForm(provider: state.llmProvider),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _researchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Research Foundation'),
        const SizedBox(height: 14),
        AgriCard(
          borderColor: AgriColors.emerald800.withOpacity(0.5),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _refCard('Base Paper 1',
                  'Conversational AI for Agricultural Advisory Systems — multilingual slot filling approaches'),
              _refCard('Base Paper 2',
                  'Tamil NLU for low-resource settings: Rule-hybrid and LLM approaches for agricultural domains'),
              _refCard('Base Paper 3',
                  'Dialogue State Tracking for Task-Oriented Conversations in agri-advisory chatbots'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _refCard(String title, String desc) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(desc,
              style: GoogleFonts.inter(fontSize: 11, color: AgriColors.slate400, height: 1.4)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AgriColors.emerald500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AgriColors.emerald800, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _providerLabel(String p) {
    switch (p) {
      case 'gemini': return 'Google Gemini';
      case 'openai': return 'OpenAI GPT';
      default: return 'Local Rule-Based Engine';
    }
  }
}

class _ProviderBtn extends StatelessWidget {
  final String label;
  final String value;
  final String current;

  const _ProviderBtn({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return InkWell(
      onTap: () => context.read<AppState>().setLLMProvider(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AgriColors.emerald500.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AgriColors.emerald500.withOpacity(0.5) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AgriColors.emerald400 : AgriColors.slate400,
          ),
        ),
      ),
    );
  }
}

class _ApiKeyForm extends StatefulWidget {
  final String provider;
  const _ApiKeyForm({required this.provider});

  @override
  State<_ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends State<_ApiKeyForm> {
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _keyCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: widget.provider == 'gemini'
                ? 'AIza... (Google Gemini API Key)'
                : 'sk-... (OpenAI API Key)',
          ),
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _modelCtrl,
          decoration: InputDecoration(
            hintText: widget.provider == 'gemini'
                ? 'Model (e.g. gemini-1.5-flash)'
                : 'Model (e.g. gpt-4o-mini)',
          ),
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
        const SizedBox(height: 10),
        GradientButton(
          label: 'Apply Configuration',
          emoji: '✅',
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await context.read<AppState>().setLLMProvider(
                        widget.provider,
                        apiKey: _keyCtrl.text.trim(),
                        model: _modelCtrl.text.trim(),
                      );
                  setState(() => _saving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('LLM provider updated to ${widget.provider}'),
                        backgroundColor: AgriColors.emerald800,
                      ),
                    );
                  }
                },
          isLoading: _saving,
        ),
      ],
    );
  }
}

class _FlowNode {
  final String emoji;
  final String label;
  final String desc;
  _FlowNode(this.emoji, this.label, this.desc);
}

class _Tech {
  final String emoji;
  final String name;
  final String desc;
  _Tech(this.emoji, this.name, this.desc);
}
