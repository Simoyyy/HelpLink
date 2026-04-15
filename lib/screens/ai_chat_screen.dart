import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/app_theme.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class _Msg {
  final bool isUser;
  final String text;
  final bool isStreaming;

  const _Msg(
      {required this.isUser, required this.text, this.isStreaming = false});

  _Msg copyWith({String? text, bool? isStreaming}) => _Msg(
        isUser: isUser,
        text: text ?? this.text,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

// ─── Public helper ────────────────────────────────────────────────────────────
// Returns the OverlayEntry so the caller can remove it on dispose.

/// Shows the floating chat and returns a [VoidCallback] that safely closes it.
/// Calling the returned function multiple times is safe — it only removes once.
VoidCallback showFloatingChat({
  required BuildContext context,
  required UserModel user,
  VoidCallback? onDismissed,
}) {
  late OverlayEntry entry;
  bool removed = false;

  void close() {
    if (!removed) {
      removed = true;
      entry.remove();
      onDismissed?.call();
    }
  }

  entry = OverlayEntry(
    builder: (_) => FloatingChatWidget(user: user, onClose: close),
  );
  Overlay.of(context).insert(entry);
  return close;
}

// ─── Floating draggable chat widget ──────────────────────────────────────────

class FloatingChatWidget extends StatefulWidget {
  final UserModel user;
  final VoidCallback onClose;

  const FloatingChatWidget({
    super.key,
    required this.user,
    required this.onClose,
  });

  @override
  State<FloatingChatWidget> createState() => _FloatingChatWidgetState();
}

class _FloatingChatWidgetState extends State<FloatingChatWidget>
    with TickerProviderStateMixin {
  // ── Layout ──────────────────────────────────────────────────────────────
  static const double _w = 310;
  static const double _headerH = 54.0;
  static const double _bodyH = 360.0;
  static const double _inputH = 58.0;
  static const double _expandedH = _headerH + _bodyH + _inputH;

  // ── Gemini ──────────────────────────────────────────────────────────────
  static const String _apiKey = 'AIzaSyDTvOw7FDqDIieopikqmc7NyTNuXThIbc8';

  // ── Position ────────────────────────────────────────────────────────────
  Offset _pos = Offset.zero;
  bool _posSet = false;

  // ── Minimize ────────────────────────────────────────────────────────────
  bool _minimized = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  // ── Chat ────────────────────────────────────────────────────────────────
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _msgs = [];
  GenerativeModel? _model;
  final List<Content> _history = [];
  bool _thinking = false;
  bool _showQuickReplies = true;
  late final AnimationController _dotCtrl;

  // ── Helpers ─────────────────────────────────────────────────────────────
  bool get _isDonor => widget.user.role == UserRole.donor;
  Color get _accent => _isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple;
  List<Color> get _grad => _isDonor
      ? [AppTheme.donorGradientStart, AppTheme.donorGradientEnd]
      : [AppTheme.beneficiaryGradientStart, AppTheme.beneficiaryGradientEnd];

  List<String> get _quickReplies => _isDonor
      ? [
          'How are requests matched to me?',
          'What to do after accepting?',
          'How does the rating work?',
        ]
      : [
          'How to write a better request?',
          'What do the status labels mean?',
          'How do I message my donor?',
        ];

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);
    _initChat();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotCtrl.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  // ── Chat init ────────────────────────────────────────────────────────────

  void _initChat() {
    final firstName = widget.user.fullName.split(' ').first;

    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);

    // Seed history with role context as a user→model exchange.
    // This avoids systemInstruction which is not supported by all models/versions.
    final contextMsg = _isDonor
        ? 'You are HelpBot, a friendly AI assistant in HelpLink — a humanitarian aid app connecting donors with people in need. I am a donor named ${widget.user.fullName}. Help me with: choosing requests, statuses (pending/matched/active/completed), contacting beneficiaries, feedback ratings, and how AI smart matching works. Keep responses concise (2-3 sentences) and warm.'
        : 'You are HelpBot, a friendly AI assistant in HelpLink — a humanitarian aid app connecting donors with people in need. I am a beneficiary named ${widget.user.fullName}. Help me with: writing good requests, choosing categories (Food/Medical/Education/Transportation/Housing/Other), understanding statuses, messaging donors (only after matching), and the 5 requests/week limit. Keep responses concise (2-3 sentences), warm, and encouraging.';

    _history.addAll([
      Content.text(contextMsg),
      Content.model([
        TextPart('Understood! I am HelpBot, your HelpLink assistant. I am ready to help you. What would you like to know?'),
      ]),
    ]);

    final greeting = _isDonor
        ? 'Hi $firstName! 👋 I\'m HelpBot.\nAsk me anything about finding requests, matching, or how the app works!'
        : 'Hi $firstName! 👋 I\'m HelpBot.\nAsk me anything about creating requests, statuses, or getting help faster!';

    _msgs.add(_Msg(isUser: false, text: greeting));
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking || _model == null) return;

    _inputCtrl.clear();
    _history.add(Content.text(trimmed));

    setState(() {
      _showQuickReplies = false;
      _msgs.add(_Msg(isUser: true, text: trimmed));
      _thinking = true;
      _msgs.add(const _Msg(isUser: false, text: '', isStreaming: true));
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    try {
      final stream = _model!.generateContentStream(_history);
      await for (final chunk in stream) {
        buffer.write(chunk.text ?? '');
        if (mounted) {
          setState(() {
            _msgs.last = _msgs.last.copyWith(text: buffer.toString());
          });
          _scrollToBottom();
        }
      }
      _history.add(Content.model([TextPart(buffer.toString())]));
    } catch (e) {
      _history.removeLast(); // undo failed user turn
      if (mounted) {
        setState(() {
          _msgs.last = _msgs.last.copyWith(text: 'Error: $e');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _msgs.last = _msgs.last.copyWith(isStreaming: false);
          _thinking = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleMinimize() {
    setState(() => _minimized = !_minimized);
    _minimized ? _expandCtrl.reverse() : _expandCtrl.forward();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    if (!_posSet) {
      _pos = Offset(
        screen.width - _w - 16,
        screen.height - _expandedH - 90,
      );
      _posSet = true;
    }

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: _w,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag on header only
                  GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        _pos += d.delta;
                        _pos = Offset(
                          _pos.dx.clamp(0.0, screen.width - _w),
                          _pos.dy.clamp(0.0, screen.height - _headerH - 24),
                        );
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _buildHeader(),
                  ),

                  // Collapsible body
                  SizeTransition(
                    sizeFactor: _expandAnim,
                    axisAlignment: -1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageArea(),
                        _buildInput(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: _headerH,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _grad,
        ),
      ),
      child: Row(
        children: [
          // Chibi robot avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HelpBot',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Row(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF34D399), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('AI Assistant',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ]),
              ],
            ),
          ),

          // Drag hint
          const Icon(Icons.drag_indicator, color: Colors.white38, size: 16),
          const SizedBox(width: 4),

          // Minimize
          _headerBtn(
            icon: _minimized
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            onTap: _toggleMinimize,
          ),
          const SizedBox(width: 6),

          // Close
          _headerBtn(icon: Icons.close_rounded, onTap: widget.onClose),
        ],
      ),
    );
  }

  Widget _headerBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }

  // ── Message area ─────────────────────────────────────────────────────────

  Widget _buildMessageArea() {
    final count =
        _msgs.length + (_showQuickReplies && _msgs.length == 1 ? 1 : 0);
    return Container(
      height: _bodyH,
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        itemCount: count,
        itemBuilder: (_, i) {
          if (_showQuickReplies && _msgs.length == 1 && i == 1) {
            return _buildQuickReplies();
          }
          return _buildBubble(_msgs[i]);
        },
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 5, bottom: 2),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _grad),
                  shape: BoxShape.circle),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 11))),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              constraints: BoxConstraints(maxWidth: _w * 0.70),
              decoration: BoxDecoration(
                color: msg.isUser ? _accent : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(msg.isUser ? 14 : 3),
                  bottomRight: Radius.circular(msg.isUser ? 3 : 14),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4),
                ],
              ),
              child: msg.isStreaming && msg.text.isEmpty
                  ? _buildDots()
                  : Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: msg.isUser ? Colors.white : AppTheme.textDark,
                        height: 1.45,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_dotCtrl.value + i * 0.33) % 1.0;
          final o = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: o),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _quickReplies
            .map((q) => GestureDetector(
                  onTap: () => _send(q),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 3),
                      ],
                    ),
                    child: Text(q,
                        style: TextStyle(
                            fontSize: 11,
                            color: _accent,
                            fontWeight: FontWeight.w500)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  Widget _buildInput() {
    return Container(
      height: _inputH,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(fontSize: 13),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ask HelpBot...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: _accent, width: 1.2),
                ),
              ),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _thinking ? null : () => _send(_inputCtrl.text),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: _thinking ? null : LinearGradient(colors: _grad),
                color: _thinking ? Colors.grey[200] : null,
                shape: BoxShape.circle,
              ),
              child: _thinking
                  ? const Center(
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.grey),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}
