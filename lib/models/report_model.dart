import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { app, request }

enum ReportStatus { pending, reviewed, resolved, dismissed }

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterRole;
  final ReportType type;
  final String? targetId;
  final String category;
  final String description;
  final String? photoUrl;
  final ReportStatus status;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterRole,
    required this.type,
    this.targetId,
    required this.category,
    required this.description,
    this.photoUrl,
    this.status = ReportStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterRole': reporterRole,
      'type': type.name,
      'targetId': targetId,
      'category': category,
      'description': description,
      'photoUrl': photoUrl,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
