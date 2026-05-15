import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/message_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════
  // HELP REQUESTS
  // ══════════════════════════════════════════════

  /// Create a new help request (Beneficiary)
  /// Returns null on success, error message on failure.
  Future<String?> createHelpRequest(HelpRequest request) async {
    try {
      final weekStart = _getWeekStart();
      final existingRequests = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('beneficiaryId', isEqualTo: request.beneficiaryId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      if (existingRequests.docs.length >= AppConstants.maxRequestsPerWeek) {
        return 'You have reached the weekly limit of ${AppConstants.maxRequestsPerWeek} requests.';
      }

      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .add(request.toFirestore());

      return null;
    } catch (e) {
      return 'Failed to submit request. Please try again.';
    }
  }

  /// Get remaining requests this week for a beneficiary
  Future<int> getRemainingRequests(String beneficiaryId) async {
    try {
      final weekStart = _getWeekStart();
      final existingRequests = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('beneficiaryId', isEqualTo: beneficiaryId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      return AppConstants.maxRequestsPerWeek - existingRequests.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Stream beneficiary's own requests
  Stream<List<HelpRequest>> getBeneficiaryRequests(String beneficiaryId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('beneficiaryId', isEqualTo: beneficiaryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream all available help requests for donors (pending only).
  /// Requests submitted by [excludeUserId] are filtered out client-side.
  Stream<List<HelpRequest>> getAvailableRequests({
    RequestCategory? category,
    String? excludeUserId,
  }) {
    Query query = _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('createdAt', descending: true);

    if (category != null) {
      query = _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('status', isEqualTo: RequestStatus.pending.name)
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => HelpRequest.fromFirestore(doc))
          .toList();
      if (excludeUserId == null) return requests;
      return requests.where((r) => r.beneficiaryId != excludeUserId).toList();
    });
  }

  /// Stream donor's active assistance
  Stream<List<HelpRequest>> getDonorActiveAssistance(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: [
          RequestStatus.matched.name,
          RequestStatus.active.name,
        ])
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream donor's ongoing (matched + active) and completed requests combined
  Stream<List<HelpRequest>> getDonorOngoingRequests(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: [
          RequestStatus.matched.name,
          RequestStatus.active.name,
          RequestStatus.completed.name,
        ])
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream donor's assistance history
  Stream<List<HelpRequest>> getDonorHistory(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', isEqualTo: RequestStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// One-time fetch of available (pending) requests for AI matching.
  /// Requests submitted by [excludeUserId] are filtered out.
  Future<List<HelpRequest>> getAvailableRequestsOnce({
    int limit = 20,
    String? excludeUserId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('status', isEqualTo: RequestStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final all = snapshot.docs
          .map((doc) => HelpRequest.fromFirestore(doc))
          .toList();
      if (excludeUserId == null) return all;
      return all.where((r) => r.beneficiaryId != excludeUserId).toList();
    } catch (e) {
      return [];
    }
  }

  /// One-time fetch of categories donor has previously helped with
  Future<List<String>> getDonorHistoryCategories(String donorId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('donorId', isEqualTo: donorId)
          .where('status', isEqualTo: RequestStatus.completed.name)
          .get();
      return snapshot.docs
          .map((doc) => doc.data()['category'] as String? ?? 'other')
          .toSet()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream ALL donor assistance (all statuses)
  Stream<List<HelpRequest>> getDonorAllAssistance(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Donor offers to help — returns null on success, error string on failure.
  Future<String?> offerHelp({
    required String requestId,
    required String donorId,
    required String donorName,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.matched.name,
        'donorId': donorId,
        'donorName': donorName,
        'matchedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Failed to offer help. Please try again.';
    }
  }

  /// Mark request as active
  Future<bool> markAsActive(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({'status': RequestStatus.active.name});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark request as completed
  Future<bool> markAsCompleted(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing help request (Beneficiary edit)
  Future<String?> updateHelpRequest({
    required String requestId,
    required String title,
    required String description,
    required RequestCategory category,
    required String location,
    required bool isAnonymous,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'title': title,
        'description': description,
        'category': category.name,
        'location': location,
        'isAnonymous': isAnonymous,
        'latitude': latitude,
        'longitude': longitude,
      });
      return null;
    } catch (e) {
      return 'Failed to update request. Please try again.';
    }
  }

  /// Permanently delete a help request
  Future<String?> deleteHelpRequest(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .delete();
      return null;
    } catch (e) {
      return 'Failed to delete request. Please try again.';
    }
  }

  /// Cancel a help request
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({'status': RequestStatus.cancelled.name});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════

  Future<Map<String, int>> getBeneficiaryStats(String beneficiaryId) async {
    try {
      final allRequests = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('beneficiaryId', isEqualTo: beneficiaryId)
          .get();

      int total = allRequests.docs.length;
      int active = 0;
      int completed = 0;

      for (var doc in allRequests.docs) {
        final status = doc.data()['status'] as String;
        if (status == AppConstants.statusPending ||
            status == AppConstants.statusMatched ||
            status == AppConstants.statusActive) {
          active++;
        } else if (status == AppConstants.statusCompleted) {
          completed++;
        }
      }

      return {'total': total, 'active': active, 'completed': completed};
    } catch (e) {
      return {'total': 0, 'active': 0, 'completed': 0};
    }
  }

  Future<Map<String, int>> getDonorStats(String donorId) async {
    try {
      final allAssistance = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('donorId', isEqualTo: donorId)
          .get();

      int active = 0;
      int completed = 0;

      for (var doc in allAssistance.docs) {
        final status = doc.data()['status'] as String;
        if (status == AppConstants.statusMatched ||
            status == AppConstants.statusActive) {
          active++;
        } else if (status == AppConstants.statusCompleted) {
          completed++;
        }
      }

      return {
        'active': active,
        'completed': completed,
        'total': allAssistance.docs.length,
      };
    } catch (e) {
      return {'active': 0, 'completed': 0, 'total': 0};
    }
  }

  // ══════════════════════════════════════════════
  // MESSAGING
  // ══════════════════════════════════════════════

  /// Send a message
  Future<void> sendMessage(ChatMessage message) async {
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(message.requestId)
        .collection(AppConstants.messagesCollection)
        .add(message.toMap());
  }

  /// Stream messages for a help request conversation
  Stream<List<ChatMessage>> getMessages(
      String userId, String otherUserId, String requestId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection(AppConstants.messagesCollection)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Stream help requests where a beneficiary has an active conversation
  Stream<List<HelpRequest>> getBeneficiaryConversations(String beneficiaryId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('beneficiaryId', isEqualTo: beneficiaryId)
        .where('status', whereIn: [
          RequestStatus.matched.name,
          RequestStatus.active.name,
          RequestStatus.completed.name,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream announcements ordered by newest first
  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _firestore
        .collection(AppConstants.announcementsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // ══════════════════════════════════════════════
  // USER
  // ══════════════════════════════════════════════

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserLocation({
    required String userId,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Update user profile fields
  Future<String?> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);
      return null;
    } catch (e) {
      return 'Failed to update profile. Please try again.';
    }
  }

  /// Upload profile image to Firebase Storage, save URL to Firestore.
  /// Returns the download URL on success, null on failure.
  Future<String?> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(imageFile, metadata);
      final url = await ref.getDownloadURL();
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'profileImageUrl': url});
      return url;
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('[Storage] upload failed — code: ${e.code}, message: ${e.message}');
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('[Storage] upload failed — $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════
  // FEEDBACK
  // ══════════════════════════════════════════════

  Future<bool> submitFeedback({
    required String requestId,
    required String reviewerId,
    required bool isDonor,
    required int experienceRating,
    int? appRating,
    String? comment,
  }) async {
    try {
      await _firestore.collection('feedbacks').add({
        'requestId': requestId,
        'reviewerId': reviewerId,
        'role': isDonor ? 'donor' : 'beneficiary',
        'experienceRating': experienceRating,
        if (appRating != null) 'appRating': appRating,
        if (comment != null) 'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Mark feedback as given on the request document
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        isDonor ? 'donorFeedbackGiven' : 'beneficiaryFeedbackGiven': true,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch feedback for a specific request and role (donor or beneficiary)
  Future<Map<String, dynamic>?> getFeedback({
    required String requestId,
    required bool isDonor,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('feedbacks')
          .where('requestId', isEqualTo: requestId)
          .where('role', isEqualTo: isDonor ? 'donor' : 'beneficiary')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (e) {
      return null;
    }
  }

  /// Stream a single help request document for real-time status updates
  Stream<HelpRequest?> getRequestStream(String requestId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists ? HelpRequest.fromFirestore(doc) : null);
  }

  // ── Helpers ──

  DateTime _getWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
