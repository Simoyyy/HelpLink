import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, matched, active, completed, cancelled }

enum RequestCategory { food, medical, education, transportation, housing, other }

class HelpRequest {
  final String id;
  final String beneficiaryId;
  final String beneficiaryName;
  final String title;
  final String description;
  final RequestCategory category;
  final RequestStatus status;
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
  final bool donorFeedbackGiven;
  final bool beneficiaryFeedbackGiven;

  HelpRequest({
    required this.id,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.title,
    required this.description,
    required this.category,
    this.status = RequestStatus.pending,
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
    this.donorFeedbackGiven = false,
    this.beneficiaryFeedbackGiven = false,
  });

  factory HelpRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HelpRequest(
      id: doc.id,
      beneficiaryId: data['beneficiaryId'] ?? '',
      beneficiaryName: data['beneficiaryName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: _parseCategory(data['category'] as String? ?? 'other'),
      status: _parseStatus(data['status'] as String? ?? 'pending'),
      isAnonymous: data['isAnonymous'] == true,
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      donorId: data['donorId'],
      donorName: data['donorName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchedAt: (data['matchedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      isEmergency: data['isEmergency'] == true,
      donorFeedbackGiven: data['donorFeedbackGiven'] == true,
      beneficiaryFeedbackGiven: data['beneficiaryFeedbackGiven'] == true,
    );
  }

  static RequestStatus _parseStatus(String s) {
    switch (s) {
      case 'matched':
        return RequestStatus.matched;
      case 'active':
        return RequestStatus.active;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }

  static RequestCategory _parseCategory(String s) {
    switch (s) {
      case 'food':
        return RequestCategory.food;
      case 'medical':
        return RequestCategory.medical;
      case 'education':
        return RequestCategory.education;
      case 'transportation':
        return RequestCategory.transportation;
      case 'housing':
        return RequestCategory.housing;
      default:
        return RequestCategory.other;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'beneficiaryId': beneficiaryId,
      'beneficiaryName': isAnonymous ? 'Anonymous' : beneficiaryName,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
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

  String get categoryLabel =>
      category.name[0].toUpperCase() + category.name.substring(1);
}
