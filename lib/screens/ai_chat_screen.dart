import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
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
  static const double _bodyH = 308.0;
  static const double _suggestH = 52.0;
  static const double _inputH = 58.0;
  static const double _expandedH = _headerH + _bodyH + _suggestH + _inputH;

  // ── Groq ─────────────────────────────────────────────────────────────────
  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _groqModel = 'llama-3.1-8b-instant';
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

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
  final List<Map<String, dynamic>> _messages = [];
  bool _thinking = false;
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

    final systemPrompt = _isDonor
        ? 'You are HelpBot, a friendly AI assistant in HelpLink — a humanitarian aid app connecting donors with people in need. The user is a donor named ${widget.user.fullName}. Help with: choosing requests, statuses (pending/matched/active/completed), contacting beneficiaries, feedback ratings, and AI smart matching. Keep responses concise (2-3 sentences) and warm.'
        : 'You are HelpBot, a friendly AI assistant in HelpLink — a humanitarian aid app connecting donors with people in need. The user is a beneficiary named ${widget.user.fullName}. Help with: writing good requests, categories (Food/Medical/Education/Transportation/Housing/Other), understanding statuses, messaging donors (only after matching), and the 5 requests/week limit. Keep responses concise (2-3 sentences), warm, and encouraging.';

    _messages.add({'role': 'system', 'content': systemPrompt});

    final greeting = _isDonor
        ? 'Hi $firstName! 👋 I\'m HelpBot.\nAsk me anything about finding requests, matching, or how the app works!'
        : 'Hi $firstName! 👋 I\'m HelpBot.\nAsk me anything about creating requests, statuses, or getting help faster!';

    _msgs.add(_Msg(isUser: false, text: greeting));
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;

    _inputCtrl.clear();
    _messages.add({'role': 'user', 'content': trimmed});

    setState(() {
      _msgs.add(_Msg(isUser: true, text: trimmed));
      _thinking = true;
      _msgs.add(const _Msg(isUser: false, text: '', isStreaming: true));
    });
    _scrollToBottom();

    try {
      final success = await _streamGroqResponse();

      if (!success) {
        final local = _localResponse(trimmed);
        _messages.add({'role': 'assistant', 'content': local});
        if (mounted) {
          setState(() => _msgs.last = _msgs.last.copyWith(text: local));
        }
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

  // Streams a response from Groq into the last bubble.
  // Returns true on success, false on any error.
  Future<bool> _streamGroqResponse() async {
    final buffer = StringBuffer();
    try {
      final request = http.Request('POST', Uri.parse(_groqUrl));
      request.headers['Authorization'] = 'Bearer $_groqApiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _groqModel,
        'messages': _messages,
        'stream': true,
        'max_tokens': 350,
      });

      final streamed = await http.Client().send(request);
      if (streamed.statusCode != 200) {
        debugPrint('HelpBot Groq HTTP ${streamed.statusCode}');
        return false;
      }

      await for (final line in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final content = json['choices']?[0]?['delta']?['content'] as String?;
          if (content != null) {
            buffer.write(content);
            if (mounted) {
              setState(() =>
                  _msgs.last = _msgs.last.copyWith(text: buffer.toString()));
              _scrollToBottom();
            }
          }
        } catch (_) {}
      }

      if (buffer.isEmpty) return false;
      _messages.add({'role': 'assistant', 'content': buffer.toString()});
      return true;
    } catch (e) {
      debugPrint('HelpBot Groq error: $e');
      return false;
    }
  }

  // ── Local fallback responses (used when all AI models are unavailable) ────

  String _localResponse(String question) {
    final q = question.toLowerCase();

    if (_isDonor) {
      if (q.contains('match') ||
          q.contains('find') ||
          q.contains('accept') ||
          q.contains('request')) {
        return 'Browse the Available Requests section on your dashboard. Each card shows the category, location, and beneficiary details. Tap "Accept Request" to be matched — the request moves to Matched status and you can start chatting with the beneficiary!';
      }
      if (q.contains('after') ||
          q.contains('accepted') ||
          q.contains('what to do') ||
          q.contains('next')) {
        return 'Once you accept a request, go to Ongoing Requests to find it. Use the Message button to coordinate with the beneficiary. When the help has been given, tap "Mark Complete" and then leave feedback so the beneficiary knows you care!';
      }
      if (q.contains('rating') ||
          q.contains('feedback') ||
          q.contains('review') ||
          q.contains('star')) {
        return 'After a request is marked Completed, both you and the beneficiary can leave feedback. Your rating builds your reputation in the community and helps HelpLink match you with more requests that suit you.';
      }
      if (q.contains('ai') ||
          q.contains('smart') ||
          q.contains('recommend') ||
          q.contains('suggest')) {
        return 'The AI Smart Matching on your dashboard recommends requests based on the category, location, and urgency that best fit your giving history. Tap "Refresh" to get fresh suggestions anytime!';
      }
      if (q.contains('message') ||
          q.contains('chat') ||
          q.contains('contact') ||
          q.contains('talk')) {
        return 'You can message a beneficiary once you have accepted their request. Go to Ongoing Requests, tap the request card, and hit the Message button. You can also open chats from the Notifications screen under Messages.';
      }
      if (q.contains('complete') ||
          q.contains('finish') ||
          q.contains('done') ||
          q.contains('mark')) {
        return 'When you have finished helping, open the request in Ongoing Requests and tap "Mark Complete". This moves the request to the Pending Feedback stage so both sides can leave a review.';
      }
      if (q.contains('cancel') ||
          q.contains('withdraw') ||
          q.contains('undo')) {
        return 'If you need to withdraw from a request you already accepted, contact the beneficiary via chat first to let them know. Then reach out to HelpLink support so the request can be re-opened for another donor.';
      }
      return 'I\'m here to help! You can ask me about finding and accepting requests, what to do after accepting, how to message beneficiaries, how ratings work, or how the AI smart matching works.';
    } else {
      if (q.contains('better request') ||
          q.contains('write') ||
          q.contains('good request') ||
          q.contains('create')) {
        return 'Here are the keys to a great request:\n1. Write a clear, specific title (e.g. "Need groceries for 3 days")\n2. Describe exactly what you need and when\n3. Add your location so donors nearby can find you faster\n4. Pick the right category — Food, Medical, Education, Transportation, Housing, or Other.';
      }
      if (q.contains('status') ||
          q.contains('label') ||
          q.contains('pending') ||
          q.contains('matched') ||
          q.contains('active') ||
          q.contains('completed')) {
        return 'Here\'s what each status means:\n🕐 Pending — waiting for a donor to accept\n🤝 Matched — a donor accepted, coordinate via chat\n⚡ Active — help is actively in progress\n✅ Completed — help was given, please leave feedback!\n\nYou can track all this in Ongoing Requests.';
      }
      if (q.contains('message') ||
          q.contains('chat') ||
          q.contains('contact') ||
          q.contains('donor') ||
          q.contains('talk')) {
        return 'The Message button appears on your request card once a donor is Matched or Active. You can also find all your conversations in the Notifications screen under the Messages tab. You cannot message before a match — this protects both sides.';
      }
      if (q.contains('limit') ||
          q.contains('how many') ||
          q.contains('week') ||
          q.contains('5')) {
        return 'You can submit up to 5 requests per week. The counter resets every Monday at midnight. To make the most of your limit, try combining multiple needs into one well-described request when possible!';
      }
      if (q.contains('anonymous') ||
          q.contains('privacy') ||
          q.contains('name') ||
          q.contains('identity') ||
          q.contains('hide')) {
        return 'When creating a request, toggle "Submit anonymously" to hide your real name from donors. They will see "Anonymous" instead. Your identity is still securely verified by HelpLink behind the scenes for safety.';
      }
      if (q.contains('cancel') ||
          q.contains('delete') ||
          q.contains('remove') ||
          q.contains('withdraw')) {
        return 'You can cancel a Pending request from its Request Details screen. Once a donor is matched, the request cannot be cancelled on your own — please message the donor first, then contact HelpLink support if needed.';
      }
      if (q.contains('location') ||
          q.contains('map') ||
          q.contains('where') ||
          q.contains('address')) {
        return 'Adding your location helps donors nearby find your request faster. Tap the location field when creating a request and either type your area or use the map picker to pin your location accurately.';
      }
      if (q.contains('category') ||
          q.contains('type') ||
          q.contains('food') ||
          q.contains('medical') ||
          q.contains('education') ||
          q.contains('transport') ||
          q.contains('housing')) {
        return 'Choose the category that best fits your need:\n🍽 Food — meals, groceries\n🏥 Medical — medicines, appointments\n📚 Education — books, fees, tutoring\n🚗 Transportation — rides, bus fare\n🏠 Housing — rent, shelter\n📦 Other — anything else\n\nPicking the right one helps match you faster!';
      }
      if (q.contains('feedback') ||
          q.contains('rating') ||
          q.contains('review') ||
          q.contains('star')) {
        return 'After your request is Completed, you\'ll see a "Provide Feedback" button. Please take a moment to rate your experience — it helps donors feel appreciated and motivates them to keep helping!';
      }
      return 'I\'m here to help! Ask me about writing a good request, understanding status labels, messaging your donor, the weekly request limit, staying anonymous, or anything else about using HelpLink.';
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
                        _buildQuickReplies(),
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
    return Container(
      height: _bodyH,
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        itemCount: _msgs.length,
        itemBuilder: (_, i) => _buildBubble(_msgs[i]),
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
    return Container(
      height: _suggestH,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final q = _quickReplies[i];
          return GestureDetector(
            onTap: _thinking ? null : () => _send(q),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _thinking ? 0.4 : 1.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                child: Text(
                  q,
                  style: TextStyle(
                      fontSize: 11,
                      color: _accent,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          );
        },
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
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain),
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
