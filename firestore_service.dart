import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';
import 'package:helplink/utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════
  // HELP REQUESTS
  // ══════════════════════════════════════════════

  /// Create a new help request (Beneficiary)
  Future<String?> createHelpRequest(HelpRequest request) async {
    try {
      // Check weekly limit
      final weekStart = _getWeekStart();
      final existingRequests = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('beneficiaryId', isEqualTo: request.beneficiaryId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      if (existingRequests.docs.length >= AppConstants.maxRequestsPerWeek) {
        return null; // Limit reached
      }

      final docRef = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .add(request.toFirestore());

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Get remaining requests this week for a beneficiary
  Future<int> getRemainingRequests(String beneficiaryId) async {
    try {
      final weekStart = _getWeekStart();
      final existingRequests = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('beneficiaryId', isEqualTo: beneficiaryId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
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
        .map((snapshot) => snapshot.docs
            .map((doc) => HelpRequest.fromFirestore(doc))
            .toList());
  }

  /// Stream all available help requests for donors (pending only)
  Stream<List<HelpRequest>> getAvailableHelpRequests({String? category}) {
    Query query = _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'All') {
      query = _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('status', isEqualTo: AppConstants.statusPending)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream donor's active assistance
  Stream<List<HelpRequest>> getDonorActiveAssistance(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: [AppConstants.statusMatched, AppConstants.statusActive])
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HelpRequest.fromFirestore(doc))
            .toList());
  }

  /// Stream donor's assistance history
  Stream<List<HelpRequest>> getDonorHistory(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', isEqualTo: AppConstants.statusCompleted)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HelpRequest.fromFirestore(doc))
            .toList());
  }

  /// Donor offers to help (match with a request)
  Future<bool> offerAssistance({
    required String requestId,
    required String donorId,
    required String donorName,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': AppConstants.statusMatched,
        'donorId': donorId,
        'donorName': donorName,
        'matchedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark request as active (assistance in progress)
  Future<bool> markAsActive(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({'status': AppConstants.statusActive});
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
        'status': AppConstants.statusCompleted,
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel a help request
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({'status': AppConstants.statusCancelled});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════

  /// Get beneficiary stats
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

      return {
        'total': total,
        'active': active,
        'completed': completed,
      };
    } catch (e) {
      return {'total': 0, 'active': 0, 'completed': 0};
    }
  }

  /// Get donor stats
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

  /// Send a message in a help request conversation
  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection(AppConstants.messagesCollection)
        .add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream messages for a help request
  Stream<QuerySnapshot> getMessages(String requestId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ══════════════════════════════════════════════
  // USER
  // ══════════════════════════════════════════════

  /// Get user by ID
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

  /// Update user location
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

  // ── Helpers ──

  DateTime _getWeekStart() {
    final now = DateTime.now();
    // Find the most recent Monday at midnight
    final daysFromMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
