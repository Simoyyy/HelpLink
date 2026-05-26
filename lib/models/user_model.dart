import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { donor, beneficiary }

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final UserRole role;
  final bool isEmailVerified;
  final DateTime createdAt;
  final String? profileImageUrl;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? icNumber;
  final String? phoneNumber;
  final bool isICVerified;
  final DateTime? icVerifiedAt;

  final bool icPendingVerification;

  // Donor moderation
  final int cancellationStrikes;
  final DateTime? strikeWindowStart;
  final DateTime? banUntil;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    this.isEmailVerified = false,
    required this.createdAt,
    this.profileImageUrl,
    this.location,
    this.latitude,
    this.longitude,
    this.icNumber,
    this.phoneNumber,
    this.isICVerified = false,
    this.icVerifiedAt,
    this.icPendingVerification = false,
    this.cancellationStrikes = 0,
    this.strikeWindowStart,
    this.banUntil,
  });

  bool get isBanned =>
      banUntil != null && banUntil!.isAfter(DateTime.now());

  Duration get banRemaining =>
      isBanned ? banUntil!.difference(DateTime.now()) : Duration.zero;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: (data['role'] as String?) == 'donor'
          ? UserRole.donor
          : UserRole.beneficiary,
      isEmailVerified: data['isEmailVerified'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      icNumber: data['icNumber'],
      phoneNumber: data['phoneNumber'],
      isICVerified: data['isICVerified'] == true,
      icVerifiedAt: (data['icVerifiedAt'] as Timestamp?)?.toDate(),
      icPendingVerification: data['icPendingVerification'] == true,
      cancellationStrikes: (data['cancellationStrikes'] as int?) ?? 0,
      strikeWindowStart: (data['strikeWindowStart'] as Timestamp?)?.toDate(),
      banUntil: (data['banUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'role': role.name,
      'isEmailVerified': isEmailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImageUrl': profileImageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'icNumber': icNumber,
      'phoneNumber': phoneNumber,
      'isICVerified': isICVerified,
      'icVerifiedAt':
          icVerifiedAt != null ? Timestamp.fromDate(icVerifiedAt!) : null,
      'icPendingVerification': icPendingVerification,
      'cancellationStrikes': cancellationStrikes,
      'strikeWindowStart': strikeWindowStart != null
          ? Timestamp.fromDate(strikeWindowStart!)
          : null,
      'banUntil': banUntil != null ? Timestamp.fromDate(banUntil!) : null,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    bool? isEmailVerified,
    String? profileImageUrl,
    String? location,
    double? latitude,
    double? longitude,
    String? icNumber,
    String? phoneNumber,
    bool? isICVerified,
    DateTime? icVerifiedAt,
    bool? icPendingVerification,
    int? cancellationStrikes,
    DateTime? strikeWindowStart,
    DateTime? banUntil,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      icNumber: icNumber ?? this.icNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isICVerified: isICVerified ?? this.isICVerified,
      icVerifiedAt: icVerifiedAt ?? this.icVerifiedAt,
      icPendingVerification: icPendingVerification ?? this.icPendingVerification,
      cancellationStrikes: cancellationStrikes ?? this.cancellationStrikes,
      strikeWindowStart: strikeWindowStart ?? this.strikeWindowStart,
      banUntil: banUntil ?? this.banUntil,
    );
  }
}
