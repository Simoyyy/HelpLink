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
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: (data['role'] as String?) == 'donor'
          ? UserRole.donor
          : UserRole.beneficiary,
      isEmailVerified: data['isEmailVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      icNumber: data['icNumber'],
      phoneNumber: data['phoneNumber'],
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
    );
  }
}
