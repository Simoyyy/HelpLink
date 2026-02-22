import 'package:cloud_firestore/cloud_firestore.dart';

class HelpRequest {
  final String id;
  final String beneficiaryId;
  final String beneficiaryName;
  final String title;
  final String description;
  final String category;
  final String status; // pending, matched, active, completed, cancelled
  final bool isAnonymous;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? donorId;
  final String? donorName;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? completedAt;
  final bool isEmergency;

  HelpRequest({
    required this.id,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.title,
    required this.description,
    required this.category,
    this.status = 'pending',
    this.isAnonymous = false,
    this.location,
    this.latitude,
    this.longitude,
    this.donorId,
    this.donorName,
    required this.createdAt,
    this.matchedAt,
    this.completedAt,
    this.isEmergency = false,
  });

  factory HelpRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HelpRequest(
      id: doc.id,
      beneficiaryId: data['beneficiaryId'] ?? '',
      beneficiaryName: data['beneficiaryName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'Other',
      status: data['status'] ?? 'pending',
      isAnonymous: data['isAnonymous'] ?? false,
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      donorId: data['donorId'],
      donorName: data['donorName'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchedAt: (data['matchedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      isEmergency: data['isEmergency'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'beneficiaryId': beneficiaryId,
      'beneficiaryName': isAnonymous ? 'Anonymous' : beneficiaryName,
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'isAnonymous': isAnonymous,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'donorId': donorId,
      'donorName': donorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'matchedAt': matchedAt != null ? Timestamp.fromDate(matchedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'isEmergency': isEmergency,
    };
  }

  String get displayName => isAnonymous ? 'Anonymous' : beneficiaryName;
}
