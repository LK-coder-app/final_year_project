import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../api_service.dart';
import '../dialogs/pdf_review_dialog.dart';
import '../voice_helper.dart';

class FarmerChatScreen extends StatefulWidget {
  const FarmerChatScreen({super.key});

  @override
  State<FarmerChatScreen> createState() => _FarmerChatScreenState();
}

class _FarmerChatScreenState extends State<FarmerChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _sessionId;

  final List<ChatMessage> _messages = [];
  Map<String, dynamic> _slots = {};
  List<ConflictItem> _conflicts = [];
  double _completionPct = 0;
  bool _isComplete = false;
  bool _isSending = false;
  bool _isRecording = false;
  String _detectedLang = 'english';
  String _voiceMode = 'auto'; // 'auto', 'tamil', 'english'

  static const List<Map<String, dynamic>> _quickPrompts = [
    {
      'label': '🌾 3 Acre Sugarcane (Tanglish)',
      'text': 'enaku 3 acre karumbu irukku, borewell 280 feet, 5 HP motor, drip venum',
    },
    {
      'label': '🍌 5 ஏக்கர் வாழை (Tamil)',
      'text': '5 ஏக்கர் வாழை, கிணறு 40 அடி, 3 எச்பி மோட்டார், சொட்டு நீர் பாசனம்',
    },
    {
      'label': '🍅 2 Acres Tomato (English)',
      'text': '2 acres tomato farm in Coimbatore, borewell source, 3 HP motor, drip irrigation',
    },
  ];

  static const Map<String, Map<String, dynamic>> _slotMeta = {
    'land_size': {'label': 'Land Area', 'icon': '🌱', 'required': true},
    'crop_types': {'label': 'Crops', 'icon': '🌾', 'required': true},
    'water_source': {'label': 'Water Source', 'icon': '💧', 'required': true},
    'motor_hp': {'label': 'Motor HP', 'icon': '⚡', 'required': true},
    'irrigation_type': {'label': 'Irrigation Type', 'icon': '🚿', 'required': true},
    'soil_type': {'label': 'Soil Type', 'icon': '🪨', 'required': false},
    'borewell_depth_ft': {'label': 'Borewell Depth', 'icon': '🕳️', 'required': false},
    'open_well_depth_ft': {'label': 'Well Depth', 'icon': '🪣', 'required': false},
    'power_supply_phase': {'label': 'Power Phase', 'icon': '🔌', 'required': false},
    'power_hours_per_day': {'label': 'Power Hours/Day', 'icon': '🕐', 'required': false},
    'district': {'label': 'District', 'icon': '📍', 'required': false},
    'budget_inr': {'label': 'Budget', 'icon': '💰', 'required': false},
  };

  @override
  void initState() {
    super.initState();
    _startNewSession();
  }

  void _startNewSession() {
    _sessionId = 'agm-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _messages.clear();
    _slots = {};
    _conflicts = [];
    _completionPct = 0;
    _isComplete = false;

    _messages.add(ChatMessage(
      role: 'assistant',
      text: 'வணக்கம் / Welcome to AgriMind! 🌱\n\n'
          'I am your AI Agricultural Assistant. Tell me about your farm in Tamil, English, or Tanglish '
          '(e.g., "enaku 3 acre karumbu irukku, borewell 250 feet").\n\n'
          'I will extract your requirements, evaluate feasibility, and prepare a technical report for your irrigation project.',
    ));
    setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    VoiceHelper.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (presetText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendChat(
        sessionId: _sessionId,
        message: text,
      );

      setState(() {
        _messages.add(ChatMessage(role: 'assistant', text: res.reply));
        _slots = res.extractedSlots;
        _conflicts = res.conflicts;
        _completionPct = res.completionPct;
        _isComplete = res.isComplete;
        _detectedLang = res.languageDetected;
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          text: '⚠️ Could not connect to the backend server. Please verify the API is running.\n\nError: $e',
        ));
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _toggleVoice() {
    if (_isRecording) {
      VoiceHelper.stop();
      setState(() => _isRecording = false);
    } else {
      setState(() => _isRecording = true);
      VoiceHelper.start(
        mode: _voiceMode,
        onResult: (text, lang) {
          setState(() {
            _textController.text = text;
          });
        },
        onEnd: () {
          if (mounted) {
            setState(() => _isRecording = false);
            if (_textController.text.trim().isNotEmpty) {
              _sendMessage();
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() => _isRecording = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: Colors.amber.shade900),
            );
          }
        },
      );
    }
  }

  void _openReviewModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PdfReviewDialog(
        sessionId: _sessionId,
        slots: _slots,
        conflicts: _conflicts,
        completionPct: _completionPct,
        onSubmitted: (result) {
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              text: '✅ Requirement Report Submitted!\n\n'
                  '• Report ID: AGM-${result.requirementId.toString().padLeft(4, '0')}\n'
                  '• Feasibility Score: ${result.feasibilityScore.toStringAsFixed(1)} / 100\n'
                  '• PDF has been dispatched to the Admin Dashboard for engineering review.',
            ));
          });
          _scrollToBottom();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🌿', style: TextStyle(fontSize: 22)),
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
                color: AgriColors.emerald900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Farmer Portal', style: TextStyle(fontSize: 11, color: AgriColors.emerald300)),
            ),
            const Spacer(),
            // Detected Language badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AgriColors.slate800,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                _detectedLang == 'tamil'
                    ? '🇮🇳 தமிழ் (Tamil)'
                    : _detectedLang == 'tanglish'
                        ? '🔀 Tanglish'
                        : '🇬🇧 English',
                style: const TextStyle(fontSize: 12, color: AgriColors.slate200),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'New Conversation',
              icon: const Icon(Icons.refresh, color: AgriColors.slate400, size: 20),
              onPressed: _startNewSession,
            ),
          ],
        ),
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Chat panel (65%)
        Expanded(
          flex: 65,
          child: _buildChatPanel(),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF1e293b)),
        // Right: Tracker & Conflict panel (35%)
        Expanded(
          flex: 35,
          child: _buildTrackerPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AgriColors.slate900,
            child: const TabBar(
              indicatorColor: AgriColors.emerald500,
              labelColor: AgriColors.emerald400,
              unselectedLabelColor: AgriColors.slate400,
              tabs: [
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
                Tab(icon: Icon(Icons.pie_chart_outline), text: 'Parameters & Review'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildChatPanel(),
                _buildTrackerPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Column(
      children: [
        // Quick prompts bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AgriColors.slate900.withOpacity(0.5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPrompts.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AgriColors.slate800,
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: Text(
                      p['label']!,
                      style: const TextStyle(fontSize: 11, color: AgriColors.slate300),
                    ),
                    onPressed: () => _sendMessage(p['text']),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Message Feed
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final m = _messages[i];
              final isUser = m.role == 'user';

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AgriColors.emerald800 : AgriColors.slate800,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: isUser ? const Radius.circular(14) : const Radius.circular(2),
                      bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(14),
                    ),
                    border: Border.all(
                      color: isUser ? AgriColors.emerald600 : const Color(0xFF334155),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isUser ? '👤 You' : '🤖 AgriMind AI',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isUser ? AgriColors.emerald300 : AgriColors.slate400)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        m.text,
                        style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_isSending)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AgriColors.emerald500)),
                SizedBox(width: 8),
                Text('Analyzing input...', style: TextStyle(color: AgriColors.slate400, fontSize: 12)),
              ],
            ),
          ),

        // Voice Waveform & status banner when recording
        if (_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.withOpacity(0.12),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                const Text('Listening in Tamil + English... Speak your farm requirements.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _toggleVoice,
                  child: const Text('Done', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // Input Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AgriColors.slate900,
            border: Border(top: BorderSide(color: Color(0xFF1e293b))),
          ),
          child: Row(
            children: [
              // Voice Lang selector popup
              PopupMenuButton<String>(
                tooltip: 'Speech Language Mode',
                icon: const Icon(Icons.translate, color: AgriColors.slate400, size: 20),
                initialValue: _voiceMode,
                onSelected: (mode) => setState(() => _voiceMode = mode),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'auto', child: Text('Auto (Tamil + English)')),
                  const PopupMenuItem(value: 'tamil', child: Text('தமிழ் (Tamil Only)')),
                  const PopupMenuItem(value: 'english', child: Text('English Only')),
                ],
              ),
              // Mic Button
              IconButton(
                tooltip: _isRecording ? 'Stop Recording' : 'Voice Input',
                icon: Icon(
                  _isRecording ? Icons.mic_off : Icons.mic,
                  color: _isRecording ? Colors.redAccent : AgriColors.emerald400,
                ),
                onPressed: _toggleVoice,
              ),
              const SizedBox(width: 8),
              // Text Field
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Type in Tamil, English, or Tanglish...',
                    hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // Send Button
              IconButton(
                tooltip: 'Send',
                icon: const Icon(Icons.send_rounded, color: AgriColors.emerald500),
                onPressed: () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Circular Completion card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AgriColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _completionPct / 100.0,
                        backgroundColor: const Color(0xFF334155),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _completionPct >= 70 ? AgriColors.emerald500 : (_completionPct >= 40 ? Colors.amber : Colors.redAccent),
                        ),
                        strokeWidth: 6,
                      ),
                      Text(
                        '${_completionPct.round()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requirements Captured',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isComplete
                            ? '✅ All required specifications collected!'
                            : '${(_slots.keys.where((k) => !k.startsWith('_')).length)} parameter(s) recorded.',
                        style: const TextStyle(color: AgriColors.slate400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Parameter list
          const Text('Captured Parameters', style: TextStyle(color: AgriColors.slate200, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AgriColors.slate900,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1e293b)),
            ),
            child: Column(
              children: _slotMeta.entries.map((e) {
                final key = e.key;
                final meta = e.value;
                final isReq = meta['required'] as bool;
                final val = _slots[key];
                final hasVal = val != null && val != '' && (!(val is List) || val.isNotEmpty);

                String display = '-';
                if (hasVal) {
                  if (key == 'land_size') {
                    display = '$val ${_slots['land_unit'] ?? 'acres'}';
                  } else if (val is List) {
                    display = val.join(', ');
                  } else if (key == 'motor_hp') {
                    display = '$val HP';
                  } else if (key.contains('depth')) {
                    display = '$val ft';
                  } else {
                    display = '$val';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Text(meta['icon'] as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        meta['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isReq ? Colors.white : AgriColors.slate400,
                          fontWeight: isReq ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        display,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasVal ? AgriColors.emerald300 : AgriColors.slate500,
                          fontWeight: hasVal ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        hasVal ? Icons.check_circle : (isReq ? Icons.circle_outlined : Icons.remove),
                        size: 14,
                        color: hasVal ? AgriColors.emerald400 : (isReq ? Colors.redAccent.withOpacity(0.6) : Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Engineering Conflicts (if any)
          if (_conflicts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                      SizedBox(width: 6),
                      Text('Engineering Alerts', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._conflicts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${c.message}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // "Review Requirements & Generate PDF" button
          ElevatedButton.icon(
            onPressed: _openReviewModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriColors.emerald600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Review Requirements & Generate PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
