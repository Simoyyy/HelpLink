import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/message_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:helplink/utils/donor_badges.dart';
import 'package:helplink/utils/beneficiary_profile.dart';
import 'package:helplink/screens/location_view_screen.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  late FirestoreService _firestoreService;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploadingVoice = false;
  bool _isLocked = false;
  int _lastMessageCount = 0;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Offset _recordingStartOffset = Offset.zero;
  Offset _currentDragOffset = Offset.zero;

  // Live location state
  String? _activeLiveSessionId;
  Timer? _liveLocationTimer;
  bool _isSharingLive = false;

  static String get _mapsApiKey => dotenv.env['MAPS_API_KEY'] ?? '';

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;
  bool _isAudioPlaying = false;

  String _staticMapUrl(double lat, double lng, {bool isLive = false}) {
    final color = isLive ? '0xFF8800' : 'red';
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=15'
        '&size=600x300'
        '&maptype=roadmap'
        '&markers=color:$color%7C$lat,$lng'
        '&key=$_mapsApiKey';
  }

  bool get _isDonor => widget.currentUserId == widget.request.donorId;

  String get _otherUserName =>
      _isDonor ? widget.request.beneficiaryName : (widget.request.donorName ?? 'Donor');

  String get _otherUserId =>
      _isDonor ? widget.request.beneficiaryId : (widget.request.donorId ?? '');

  String get _otherUserRole => _isDonor ? 'Beneficiary' : 'Donor';
  String get _currentUserRole => _isDonor ? 'Donor' : 'Beneficiary';

  List<Color> get _headerGradient => const [Color(0xFF9333EA), Color(0xFF06B6D4)];

  bool _streamInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      _streamInitialized = true;
      _firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _messagesStream = _firestoreService.getMessages(
        widget.currentUserId,
        _otherUserId,
        widget.request.id,
      );
    }
  }

  @override
  void dispose() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    if (_activeLiveSessionId != null) {
      _firestoreService.stopLiveLocationSession(
        requestId: widget.request.id,
        sessionId: _activeLiveSessionId!,
      );
      _activeLiveSessionId = null;
    }
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Audio playback ─────────────────────────────────────────────────────────

  Future<void> _toggleAudio(ChatMessage msg) async {
    if (_playingMessageId == msg.id && _isAudioPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isAudioPlaying = false);
    } else {
      if (_playingMessageId != msg.id) {
        await _audioPlayer.setSourceUrl(msg.audioUrl!);
      }
      await _audioPlayer.resume();
      if (mounted) setState(() { _playingMessageId = msg.id; _isAudioPlaying = true; });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isAudioPlaying = false);
      });
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String get _recordingDuration {
    final m = _recordingSeconds ~/ 60;
    final s = _recordingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _stopRecordingTimer();
      if (mounted) {
        setState(() { _isRecording = false; _isLocked = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    final path =
        '${Directory.systemTemp.path}/helplink_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Widget _buildInputCenter() {
    if (_isRecording) {
      // Pressing state: show "slide left to cancel" indicator that drifts with finger
      final slideProgress = (_currentDragOffset.dx.clamp(-100.0, 0.0) / -100.0);
      final cancelOpacity = (1.0 - slideProgress).clamp(0.3, 1.0);
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 6),
                Text(_recordingDuration,
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          // "slide to cancel" label drifts left with drag
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(_currentDragOffset.dx.clamp(-80.0, 0.0), 0),
                  child: Opacity(
                    opacity: cancelOpacity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, color: Colors.red.shade400, size: 16),
                        Text('Slide to cancel',
                            style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Normal state: text field
    return TextField(
      controller: _messageController,
      maxLines: 5,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: _isUploadingVoice ? 'Sending voice note…' : 'Type a message…',
        filled: true,
        fillColor: AppTheme.backgroundGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _cancelRecording() async {
    final path = await _recorder.stop();
    _stopRecordingTimer();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _currentDragOffset = Offset.zero;
      });
    }
    if (path != null) try { await File(path).delete(); } catch (_) {}
  }

  Future<void> _stopAndSendVoice() async {
    final path = await _recorder.stop();
    _stopRecordingTimer();
    final duration = _recordingDuration;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _currentDragOffset = Offset.zero;
      });
    }
    if (path == null) return;

    if (mounted) setState(() => _isUploadingVoice = true);
    try {
      final url = await _firestoreService.uploadVoiceNote(
        requestId: widget.request.id,
        file: File(path),
      );
      if (url == null) throw Exception('Upload failed');
      if (!mounted) return;

      final receiverId = _isDonor
          ? widget.request.beneficiaryId
          : widget.request.donorId ?? '';
      final message = ChatMessage(
        id: '',
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        receiverId: receiverId,
        requestId: widget.request.id,
        content: duration,
        timestamp: DateTime.now(),
        messageType: MessageType.audio,
        audioUrl: url,
      );
      await _firestoreService.sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send voice note: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingVoice = false);
      try { await File(path).delete(); } catch (_) {}
    }
  }

  // ── Text message ───────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

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
      await _firestoreService.sendMessage(message);
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
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Location helpers ───────────────────────────────────────────────────────

  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permissions permanently denied. Enable in settings.')),
        );
      }
      return null;
    }
    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<String?> _getAddressName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return [p.street, p.subLocality, p.locality]
            .where((s) => s != null && s.isNotEmpty)
            .take(2)
            .join(', ');
      }
    } catch (_) {}
    return null;
  }

  // ── Share current location ─────────────────────────────────────────────────

  Future<void> _shareCurrentLocation() async {
    Navigator.pop(context);
    final position = await _getCurrentPosition();
    if (position == null) return;
    final address = await _getAddressName(position.latitude, position.longitude);

    final message = ChatMessage(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: _otherUserId,
      requestId: widget.request.id,
      content: address ?? 'Shared a location',
      timestamp: DateTime.now(),
      messageType: MessageType.location,
      latitude: position.latitude,
      longitude: position.longitude,
      locationName: address,
    );

    try {
      await _firestoreService.sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share location: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Live location ──────────────────────────────────────────────────────────

  Future<void> _startLiveLocation(int durationMinutes) async {
    Navigator.pop(context);
    final position = await _getCurrentPosition();
    if (position == null) return;

    final expiry = DateTime.now().add(Duration(minutes: durationMinutes));

    try {
      final sessionId = await _firestoreService.createLiveLocationSession(
        requestId: widget.request.id,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        latitude: position.latitude,
        longitude: position.longitude,
        expiryTime: expiry,
      );

      final address = await _getAddressName(position.latitude, position.longitude);

      final message = ChatMessage(
        id: '',
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        receiverId: _otherUserId,
        requestId: widget.request.id,
        content: 'Sharing live location for $durationMinutes min',
        timestamp: DateTime.now(),
        messageType: MessageType.liveLocation,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: address,
        liveLocationSessionId: sessionId,
        liveLocationExpiry: expiry,
      );

      await _firestoreService.sendMessage(message);

      if (mounted) {
        setState(() {
          _activeLiveSessionId = sessionId;
          _isSharingLive = true;
        });
      }

      _liveLocationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (!_isSharingLive || _activeLiveSessionId == null) return;
        if (DateTime.now().isAfter(expiry)) { _stopLiveLocation(); return; }
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium),
          );
          await _firestoreService.updateLiveLocation(
            requestId: widget.request.id,
            sessionId: _activeLiveSessionId!,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start live location: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopLiveLocation() async {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    if (_activeLiveSessionId == null) return;

    final sessionId = _activeLiveSessionId!;
    if (mounted) setState(() { _activeLiveSessionId = null; _isSharingLive = false; });

    try {
      await _firestoreService.stopLiveLocationSession(
        requestId: widget.request.id,
        sessionId: sessionId,
      );
    } catch (_) {}
  }

  // ── Sheet ──────────────────────────────────────────────────────────────────

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationPickerSheet(
        isSharingLive: _isSharingLive,
        onShareCurrent: _shareCurrentLocation,
        onStartLive: _startLiveLocation,
        onStopLive: () {
          Navigator.pop(ctx);
          _stopLiveLocation();
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Header
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
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.chat_bubble, size: 16, color: Colors.white),
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
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildHeaderRoleBadge(_otherUserRole),
                            if (_otherUserRole == 'Donor' && widget.request.donorId != null) ...[
                              const SizedBox(width: 6),
                              DonorBadgeChip(donorId: widget.request.donorId!),
                            ],
                            if (_isDonor) ...[
                              const SizedBox(width: 6),
                              BeneficiaryStatsChip(beneficiaryId: widget.request.beneficiaryId),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.request.title,
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live location active banner
          if (_isSharingLive) _LiveLocationBanner(onStop: _stopLiveLocation),

          // Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: Lottie.asset('assets/lottie/loading.json', width: 120, height: 120));
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
                          Lottie.asset('assets/lottie/chat_empty.json', width: 160, height: 160, repeat: true),
                          const SizedBox(height: 8),
                          const Text('Start the conversation!',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 8),
                          Text(
                            _isDonor
                                ? 'Send a message to ${widget.request.beneficiaryName} and coordinate how you can help.'
                                : 'Say hello to your donor and share more details about your need.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
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
                    if (msg.messageType == MessageType.audio) {
                      return _buildAudioBubble(msg, isMe);
                    }
                    if (msg.messageType != MessageType.text) {
                      return _buildLocationBubble(msg, isMe);
                    }
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // [0] Location button — hidden while recording
                Opacity(
                  opacity: _isRecording ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isRecording,
                    child: GestureDetector(
                      onTap: _showLocationSheet,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _isSharingLive ? Colors.red.shade100 : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSharingLive ? Icons.location_on : Icons.location_on_outlined,
                          color: _isSharingLive ? Colors.red : Colors.grey.shade600,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // [1] Center — text field OR recording indicator
                Expanded(child: _buildInputCenter()),
                const SizedBox(width: 8),
                // [2] Mic button — always in tree at fixed position (Listener needs stable position)
                Listener(
                  onPointerDown: (event) {
                    if (_isRecording || _isUploadingVoice) return;
                    _recordingStartOffset = event.position;
                    _currentDragOffset = Offset.zero;
                    setState(() {
                      _isRecording = true;
                      _isLocked = false;
                    });
                    _startRecordingTimer();
                    _startRecording();
                  },
                  onPointerMove: (event) {
                    if (!_isRecording || _isLocked) return;
                    final delta = event.position - _recordingStartOffset;
                    setState(() => _currentDragOffset = delta);
                    if (delta.dx < -100) {
                      setState(() => _isLocked = true);
                      _cancelRecording();
                    }
                  },
                  onPointerUp: (_) {
                    if (!_isRecording || _isLocked) return;
                    _stopAndSendVoice();
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : _isUploadingVoice
                              ? Colors.orange.shade100
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingVoice
                        ? Lottie.asset('assets/lottie/loading.json', width: 44, height: 44, fit: BoxFit.contain)
                        : Icon(
                            Icons.mic,
                            color: _isRecording ? Colors.white : Colors.grey.shade600,
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // [3] Send button — hidden while recording
                Opacity(
                  opacity: _isRecording ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isRecording,
                    child: Container(
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bubbles ────────────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final senderName = isMe ? 'Yourself' : message.senderName;
    final senderRole = isMe ? _currentUserRole : _otherUserRole;
    Color bubbleColor = isMe
        ? (_isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple)
        : (_isDonor ? AppTheme.primaryPurple : AppTheme.primaryBlue);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(senderName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  _buildInlineRoleBadge(senderRole),
                ],
              ),
            ),
            IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Text(message.content, style: const TextStyle(fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(DateFormat.jm().format(message.timestamp),
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
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

  Widget _buildAudioBubble(ChatMessage message, bool isMe) {
    final isPlaying = _playingMessageId == message.id && _isAudioPlaying;
    final senderName = isMe ? 'Yourself' : message.senderName;
    final senderRole = isMe ? _currentUserRole : _otherUserRole;
    final bubbleColor = isMe
        ? (_isDonor ? AppTheme.primaryBlue : AppTheme.primaryPurple)
        : (_isDonor ? AppTheme.primaryPurple : AppTheme.primaryBlue);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(senderName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  _buildInlineRoleBadge(senderRole),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _toggleAudio(message),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.graphic_eq, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('h:mm a').format(message.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBubble(ChatMessage message, bool isMe) {
    final isLive = message.messageType == MessageType.liveLocation;
    final senderName = isMe ? 'Yourself' : message.senderName;
    final senderRole = isMe ? _currentUserRole : _otherUserRole;
    final bubbleWidth = MediaQuery.of(context).size.width * 0.72;
    final isActiveSender = isMe && _isSharingLive &&
        _activeLiveSessionId == message.liveLocationSessionId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: bubbleWidth,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name + role badge
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(senderName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  _buildInlineRoleBadge(senderRole),
                ],
              ),
            ),

            // Bubble card
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LocationViewScreen(message: message)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // ── Map thumbnail ──────────────────────────────────
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: _staticMapUrl(
                            message.latitude!,
                            message.longitude!,
                            isLive: isLive,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(Icons.map_outlined,
                                  color: Colors.grey, size: 40),
                            ),
                          ),
                        ),
                      ),

                      // ── Info strip ─────────────────────────────────────
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(
                          children: [
                            Icon(
                              isLive ? Icons.wifi_tethering : Icons.location_on,
                              size: 16,
                              color: isLive ? const Color(0xFF00897B) : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isLive
                                    ? _liveUntilText(message)
                                    : (message.locationName ?? 'Shared location'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat.jm().format(message.timestamp),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),

                      // ── Stop sharing button (sender only) ──────────────
                      if (isActiveSender) ...[
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        GestureDetector(
                          onTap: _stopLiveLocation,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                'Stop sharing',
                                style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _liveUntilText(ChatMessage message) {
    final expiry = message.liveLocationExpiry;
    if (expiry == null) return 'Live location';
    if (DateTime.now().isAfter(expiry)) return 'Live location ended';
    return 'Live until ${DateFormat.jm().format(expiry)}';
  }

  Widget _buildHeaderRoleBadge(String role) {
    final color = role == 'Donor' ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(role,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildInlineRoleBadge(String role) {
    final color = role == 'Donor' ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(role,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _LiveLocationBanner extends StatelessWidget {
  final VoidCallback onStop;
  const _LiveLocationBanner({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('You are sharing your live location',
                style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Stop', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Location picker sheet ──────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final bool isSharingLive;
  final VoidCallback onShareCurrent;
  final Future<void> Function(int minutes) onStartLive;
  final VoidCallback onStopLive;

  const _LocationPickerSheet({
    required this.isSharingLive,
    required this.onShareCurrent,
    required this.onStartLive,
    required this.onStopLive,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _isLoadingPos = true;
  bool _showDurations = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    // Show cached position immediately for fast map render
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _currentPosition = LatLng(last.latitude, last.longitude);
          _isLoadingPos = false;
        });
      }
    } catch (_) {}

    // Then get accurate position
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { if (mounted) setState(() => _isLoadingPos = false); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingPos = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() { _currentPosition = latLng; _isLoadingPos = false; });
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    } catch (_) {
      if (mounted) setState(() => _isLoadingPos = false);
    }
  }

  String _coordText() {
    if (_currentPosition == null) return 'Getting location…';
    return '${_currentPosition!.latitude.toStringAsFixed(5)}, '
        '${_currentPosition!.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Send location',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 22),
                  onPressed: () { setState(() => _isLoadingPos = true); _loadPosition(); },
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Search or enter an address',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                _currentPosition == null
                    ? Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentPosition!,
                          zoom: 15,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (ctrl) => _mapController = ctrl,
                      ),
                // Loading spinner overlay
                if (_isLoadingPos)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                // My location button
                Positioned(
                  bottom: 12, right: 12,
                  child: GestureDetector(
                    onTap: () {
                      if (_currentPosition != null) {
                        _mapController?.animateCamera(
                            CameraUpdate.newLatLng(_currentPosition!));
                      }
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: const Icon(Icons.my_location, size: 20, color: Color(0xFF00897B)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Options
          Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, color: Color(0xFFE8E8E8)),

                if (widget.isSharingLive) ...[
                  _OptionTile(
                    icon: Icons.location_off_outlined,
                    iconColor: Colors.red,
                    title: 'Stop live location',
                    onTap: widget.onStopLive,
                  ),
                ] else ...[
                  // Share live location
                  _OptionTile(
                    icon: Icons.wifi_tethering,
                    iconColor: const Color(0xFF00897B),
                    title: 'Share live location',
                    trailing: Icon(
                      _showDurations ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade400, size: 20,
                    ),
                    onTap: () => setState(() => _showDurations = !_showDurations),
                  ),
                  if (_showDurations) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 60, right: 16),
                      child: Column(
                        children: [
                          _DurationTile(label: '15 minutes', onTap: () => widget.onStartLive(15)),
                          _DurationTile(label: '1 hour', onTap: () => widget.onStartLive(60)),
                          _DurationTile(label: '8 hours', onTap: () => widget.onStartLive(480)),
                        ],
                      ),
                    ),
                  ],
                ],

                const Divider(height: 1, color: Color(0xFFE8E8E8)),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 10, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nearby places',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.3)),
                  ),
                ),
                _OptionTile(
                  icon: Icons.location_on,
                  iconColor: const Color(0xFF00897B),
                  title: 'Send your current location',
                  subtitle: _coordText(),
                  onTap: widget.onShareCurrent,
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
      onTap: onTap,
    );
  }
}

class _DurationTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DurationTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}
