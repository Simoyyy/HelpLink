import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/message_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/donor_badges.dart';
import 'package:helplink/utils/beneficiary_profile.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatScreen extends StatefulWidget {
  final HelpRequest request;
  final String currentUserId;
  final String currentUserName;

  const ChatScreen({
    super.key,
    required this.request,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _lastMessageCount = 0;

  static const String _geminiApiKey = 'AIzaSyDTvOw7FDqDIieopikqmc7NyTNuXThIbc8';

  bool get _isDonor => widget.currentUserId == widget.request.donorId;

  String get _otherUserName {
    if (_isDonor) {
      return widget.request.beneficiaryName;
    }
    return widget.request.donorName ?? 'Donor';
  }

  String get _otherUserId {
    if (_isDonor) {
      return widget.request.beneficiaryId;
    }
    return widget.request.donorId ?? '';
  }

  String get _otherUserRole => _isDonor ? 'Beneficiary' : 'Donor';
  String get _currentUserRole => _isDonor ? 'Donor' : 'Beneficiary';

  // Gradient colors — purple-to-teal for cross-role chat
  List<Color> get _headerGradient {
    return const [Color(0xFF9333EA), Color(0xFF06B6D4)];
  }

  bool _streamInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      _streamInitialized = true;
      final firestoreService =
          Provider.of<FirestoreService>(context, listen: false);
      _messagesStream = firestoreService.getMessages(
        widget.currentUserId,
        _otherUserId,
        widget.request.id,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    final path =
        '${Directory.systemTemp.path}/helplink_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav),
        path: path);
    setState(() => _isRecording = true);
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;

    setState(() => _isTranscribing = true);
    try {
      final bytes = await File(path).readAsBytes();
      final model =
          GenerativeModel(model: 'gemini-2.0-flash', apiKey: _geminiApiKey);
      final response = await model.generateContent([
        Content.multi([
          DataPart('audio/wav', bytes),
          TextPart(
              'Transcribe this audio exactly as spoken. Return only the transcribed text, nothing else.'),
        ]),
      ]);
      final transcribed = response.text?.trim() ?? '';
      if (transcribed.isNotEmpty && mounted) {
        _messageController.text = transcribed;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Transcription failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    final message = ChatMessage(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: _otherUserId,
      requestId: widget.request.id,
      content: text,
      timestamp: DateTime.now(),
    );

    try {
      await firestoreService.sendMessage(message);
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        _messageController.text = text; // restore the message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 48, 0, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _headerGradient,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  // Chat icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.chat_bubble,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Chat with $_otherUserName',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildHeaderRoleBadge(_otherUserRole),
                            if (_otherUserRole == 'Donor' &&
                                widget.request.donorId != null) ...[
                              const SizedBox(width: 6),
                              DonorBadgeChip(donorId: widget.request.donorId!),
                            ],
                            if (_isDonor) ...[
                              const SizedBox(width: 6),
                              BeneficiaryStatsChip(
                                  beneficiaryId: widget.request.beneficiaryId),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.request.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: Lottie.asset('assets/lottie/loading.json',
                          width: 120, height: 120));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.length > _lastMessageCount) {
                  _lastMessageCount = messages.length;
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

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset(
                            'assets/lottie/chat_empty.json',
                            width: 160,
                            height: 160,
                            repeat: true,
                          ),
                          const SizedBox(height: 8),
                          const Text('Start the conversation!',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark)),
                          const SizedBox(height: 8),
                          Text(
                            _isDonor
                                ? 'Send a message to ${widget.request.beneficiaryName} and coordinate how you can help.'
                                : 'Say hello to your donor and share more details about your need.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == widget.currentUserId;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Recording banner
          if (_isRecording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red.shade400, size: 16),
                  const SizedBox(width: 6),
                  Text('Recording… release to transcribe',
                      style:
                          TextStyle(color: Colors.red.shade400, fontSize: 13)),
                ],
              ),
            ),

          // Message input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _isTranscribing
                          ? 'Transcribing…'
                          : 'Type or hold mic to speak…',
                      filled: true,
                      fillColor: AppTheme.backgroundGrey,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mic button
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopAndTranscribe(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : _isTranscribing
                              ? Colors.orange.shade100
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: _isTranscribing
                        ? Lottie.asset('assets/lottie/loading.json',
                            width: 44, height: 44, fit: BoxFit.contain)
                        : Icon(
                            Icons.mic,
                            color: _isRecording
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.white,
                    iconSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final senderName = isMe ? 'Yourself' : message.senderName;
    final senderRole = isMe ? _currentUserRole : _otherUserRole;

    // Bubble colors — donor messages blue, beneficiary messages purple
    Color bubbleColor;
    if (isMe) {
      bubbleColor = _isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    } else {
      bubbleColor = _isDonor ? AppTheme.primaryPurple : AppTheme.primaryBlue;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name + role badge
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildInlineRoleBadge(senderRole),
                ],
              ),
            ),

            // Message bubble
            IntrinsicWidth(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        DateFormat.jm().format(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRoleBadge(String role) {
    final color =
        role == 'Donor' ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            role,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineRoleBadge(String role) {
    final color =
        role == 'Donor' ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            role,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
