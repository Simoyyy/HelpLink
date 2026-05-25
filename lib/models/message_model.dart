import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, location, liveLocation }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String requestId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final MessageType messageType;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? liveLocationSessionId;
  final DateTime? liveLocationExpiry;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.requestId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.messageType = MessageType.text,
    this.latitude,
    this.longitude,
    this.locationName,
    this.liveLocationSessionId,
    this.liveLocationExpiry,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    MessageType type = MessageType.text;
    final typeStr = data['messageType'] as String?;
    if (typeStr == 'location') type = MessageType.location;
    if (typeStr == 'liveLocation') type = MessageType.liveLocation;

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      requestId: data['requestId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      messageType: type,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationName: data['locationName'] as String?,
      liveLocationSessionId: data['liveLocationSessionId'] as String?,
      liveLocationExpiry:
          (data['liveLocationExpiry'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'requestId': requestId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'messageType': messageType.name,
    };
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (locationName != null) map['locationName'] = locationName;
    if (liveLocationSessionId != null) {
      map['liveLocationSessionId'] = liveLocationSessionId;
    }
    if (liveLocationExpiry != null) {
      map['liveLocationExpiry'] = Timestamp.fromDate(liveLocationExpiry!);
    }
    return map;
  }
}
