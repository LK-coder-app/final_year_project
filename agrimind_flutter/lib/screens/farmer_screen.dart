// ═══════════════════════════════════════════════════════════════════
// AgriMind — Farmer Chat Screen
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

const _quickPrompts = [
  'Enakku 5 acre karuppu thottam, borewell 350 feet, 3 HP motor',
  '4 acre banana farm, borewell 280 ft, single phase, drip venum',
  '12 acres paddy, canal water, three phase, 5 HP, sprinkler',
  '2.5 acre turmeric ginger, open well 35 ft, 1.5 HP, drip system',
  '8 acres sugarcane Salem, borewell 420 ft, 3 HP motor',
];

const _slotMeta = {
  'land_size':           {'label': 'Land Area',       'emoji': '🌱', 'required': true},
  'land_unit':           {'label': 'Unit',             'emoji': '📏', 'required': true},
  'crop_types':          {'label': 'Crops',            'emoji': '🌾', 'required': true},
  'water_source':        {'label': 'Water Source',     'emoji': '💧', 'required': true},
  'motor_hp':            {'label': 'Motor HP',         'emoji': '⚡', 'required': true},
  'irrigation_type':     {'label': 'Irrigation',       'emoji': '🚿', 'required': true},
  'soil_type':           {'label': 'Soil Type',        'emoji': '🪨', 'required': false},
  'borewell_depth_ft':   {'label': 'Borewell Depth',  'emoji': '🕳', 'required': false},
  'power_supply_phase':  {'label': 'Power Phase',      'emoji': '🔌', 'required': false},
  'power_hours_per_day': {'label': 'Power Hours',      'emoji': '🕐', 'required': false},
  'district':            {'label': 'District',          'emoji': '📍', 'required': false},
  'budget_inr':          {'label': 'Budget',            'emoji': '💰', 'required': false},
};

class FarmerScreen extends StatefulWidget {
  const FarmerScreen({super.key});

  @override
  State<FarmerScreen> createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _showSubmit = false;
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final state = context.read<AppState>();
    await state.sendMessage(text);
    _scrollToBottom();
    if (state.isComplete && !_showSubmit) {
      setState(() => _showSubmit = true);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    setState(() => _submitting = true);
    final state = context.read<AppState>();
    await state.submitRequirement(name: name, phone: _phoneCtrl.text.trim());
    setState(() {
      _submitting = false;
      _showSubmit = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return isWide
        ? Row(children: [
            Expanded(flex: 3, child: _buildChatPanel()),
            const SizedBox(width: 16),
            SizedBox(width: 340, child: _buildSidePanel()),
          ])
        : _buildChatPanel();
  }

  // ── Chat Panel ───────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        _scrollToBottom();
        return Column(
          children: [
            _buildChatHeader(state),
            Expanded(child: _buildMessages(state)),
            _buildQuickPrompts(state),
            if (_showSubmit && state.isComplete) _buildSubmitForm(),
            _buildInputBar(state),
          ],
        );
      },
    );
  }

  Widget _buildChatHeader(AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(gradient: AgriColors.headerGradient),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AgriColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AgriMind Assistant',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AgriColors.emerald300)),
                Text('Tamil · English · Tanglish',
                    style: GoogleFonts.inter(fontSize: 11, color: AgriColors.emerald400)),
              ],
            ),
          ),
          // Language badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AgriColors.emerald500.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AgriColors.emerald700.withOpacity(0.5)),
            ),
            child: Text(
              _langLabel(state.detectedLanguage),
              style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w700, color: AgriColors.emerald400),
            ),
          ),
          const SizedBox(width: 8),
          // New chat button
          IconButton(
            onPressed: () => context.read<AppState>().startNewChat(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'New Conversation',
            color: AgriColors.slate400,
          ),
        ],
      ),
    );
  }

  String _langLabel(String lang) {
    switch (lang) {
      case 'tamil': return 'Tamil';
      case 'tanglish': return 'Tanglish';
      default: return 'English';
    }
  }

  Widget _buildMessages(AppState state) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length + (state.isSending ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == state.messages.length) {
          return _buildTypingIndicator();
        }
        final msg = state.messages[i];
        return _buildMessageBubble(msg).animate().fadeIn(duration: 300.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
            );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AgriColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 15))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AgriColors.emerald800
                    : AgriColors.slate800,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AgriColors.emerald600.withOpacity(0.4)
                      : Colors.white.withOpacity(0.07),
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isUser ? AgriColors.emerald50 : Colors.white,
                  height: 1.55,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AgriColors.slate700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('👤', style: TextStyle(fontSize: 15))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AgriColors.brandGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 15))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AgriColors.slate800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: AgriColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat()).move(
                      begin: const Offset(0, 0),
                      end: const Offset(0, -4),
                      delay: (i * 200).ms,
                      duration: 400.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(AppState state) {
    if (state.messages.length > 3) return const SizedBox.shrink();
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          return InkWell(
            onTap: () => context.read<AppState>().sendMessage(_quickPrompts[i]),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              alignment: Alignment.center,
              child: Text(
                _quickPrompts[i].length > 45
                    ? '${_quickPrompts[i].substring(0, 45)}...'
                    : _quickPrompts[i],
                style: GoogleFonts.inter(fontSize: 11, color: AgriColors.slate400),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AgriColors.emerald900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AgriColors.emerald700.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit Your Requirement',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AgriColors.emerald400)),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Your Full Name *'),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(hintText: 'Mobile Number (optional)'),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          GradientButton(
            label: 'Submit Requirement',
            emoji: '📤',
            onPressed: _submitting ? null : _submit,
            isLoading: _submitting,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildInputBar(AppState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AgriColors.slate900,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              decoration: InputDecoration(
                hintText: 'Type in Tamil, English, or Tanglish...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AgriColors.slate600),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          _buildSendButton(state),
        ],
      ),
    );
  }

  Widget _buildSendButton(AppState state) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: state.isSending ? null : AgriColors.brandGradient,
        color: state.isSending ? AgriColors.slate700 : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: state.isSending
            ? null
            : [
                BoxShadow(
                  color: AgriColors.emerald500.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: state.isSending ? null : _send,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: state.isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // ── Side Panel ───────────────────────────────────────────────────
  Widget _buildSidePanel() {
    return Consumer<AppState>(
      builder: (ctx, state, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(right: 0),
        child: Column(
          children: [
            _buildCompletionCard(state),
            const SizedBox(height: 12),
            if (state.conflicts.isNotEmpty) ...[
              _buildConflictsCard(state),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard(AppState state) {
    return AgriCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          const SizedBox(height: 0),
          const SectionHeader(title: '  SPECIFICATION TRACKER'),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildRingProgress(state.completionPct),
                const SizedBox(height: 14),
                ..._slotMeta.entries.map((e) {
                  final key = e.key;
                  final meta = e.value;
                  final val = state.slots[key];
                  final filled = val != null;
                  final displayVal = _formatSlotValue(key, val);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: filled
                            ? AgriColors.emerald500.withOpacity(0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: filled
                              ? AgriColors.emerald500.withOpacity(0.2)
                              : Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(meta['emoji'] as String,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${meta['label']}${meta['required'] == true ? ' *' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: filled
                                    ? AgriColors.emerald300
                                    : AgriColors.slate500,
                                fontWeight: filled
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (filled)
                            Text(
                              displayVal,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AgriColors.emerald400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingProgress(double pct) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 8,
              backgroundColor: AgriColors.slate700,
              valueColor: AlwaysStoppedAnimation(
                pct >= 100
                    ? AgriColors.emerald400
                    : pct >= 60
                        ? AgriColors.emerald500
                        : AgriColors.amber500,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AgriColors.emerald400,
                  height: 1,
                ),
              ),
              Text('done',
                  style: GoogleFonts.inter(fontSize: 9, color: AgriColors.slate500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictsCard(AppState state) {
    return AgriCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SectionHeader(
            title: '  ENGINEERING ALERTS',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AgriColors.amber600.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${state.conflicts.length}',
                style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.w800, color: AgriColors.amber500),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: state.conflicts
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ConflictChip(conflict: c),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSlotValue(String key, dynamic val) {
    if (val == null) return '';
    if (val is List) return val.join(', ');
    if (key == 'budget_inr') return '₹${_fmt(val as num)}';
    if (key == 'borewell_depth_ft' || key == 'open_well_depth_ft') return '${val}ft';
    if (key == 'motor_hp') return '${val}HP';
    if (key == 'power_hours_per_day') return '${val}h';
    return val.toString();
  }

  String _fmt(num n) {
    final s = n.toStringAsFixed(0);
    return s.length > 3
        ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}'
        : s;
  }
}
