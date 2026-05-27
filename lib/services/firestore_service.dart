import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/message_model.dart';
import 'package:helplink/models/report_model.dart';
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
      final col = _firestore.collection(AppConstants.helpRequestsCollection);

      // ── Weekly limit (unchanged) ───────────────────────────────────────────
      final weekStart = _getWeekStart();
      final thisWeek = await col
          .where('beneficiaryId', isEqualTo: request.beneficiaryId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();
      if (thisWeek.docs.length >= AppConstants.maxRequestsPerWeek) {
        return 'You have reached the weekly limit of ${AppConstants.maxRequestsPerWeek} requests.';
      }

      // ── Concurrency: max 1 active (matched/active/pendingConfirmation) ───────
      final active = await col
          .where('beneficiaryId', isEqualTo: request.beneficiaryId)
          .where('status', whereIn: [
            RequestStatus.matched.name,
            RequestStatus.active.name,
            RequestStatus.pendingConfirmation.name,
          ])
          .get();
      if (active.docs.isNotEmpty) {
        return 'You already have an active request being helped. '
            'Please wait for it to complete or cancel it first.';
      }

      // ── Concurrency: max 2 pending ─────────────────────────────────────────
      final pending = await col
          .where('beneficiaryId', isEqualTo: request.beneficiaryId)
          .where('status', isEqualTo: RequestStatus.pending.name)
          .get();
      if (pending.docs.length >= 2) {
        return 'You already have 2 pending requests. '
            'Wait for a donor to accept one, or cancel a request first.';
      }

      await col.add(request.toFirestore());
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
          RequestStatus.pendingConfirmation.name,
        ])
        .orderBy('matchedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => HelpRequest.fromFirestore(doc)).toList());
  }

  /// Stream donor's ongoing (matched + active + pendingConfirmation) and completed requests combined
  Stream<List<HelpRequest>> getDonorOngoingRequests(String donorId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: [
          RequestStatus.matched.name,
          RequestStatus.active.name,
          RequestStatus.pendingConfirmation.name,
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

  /// One-time fetch of pending emergency requests (for nearby donor alert).
  Future<List<HelpRequest>> getEmergencyRequestsOnce() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('isEmergency', isEqualTo: true)
          .where('status', isEqualTo: RequestStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      return snapshot.docs.map((d) => HelpRequest.fromFirestore(d)).toList();
    } catch (_) {
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
      // Check if donor is currently banned
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(donorId)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        final banUntil = (userData['banUntil'] as Timestamp?)?.toDate();
        if (banUntil != null && banUntil.isAfter(DateTime.now())) {
          final remaining = banUntil.difference(DateTime.now());
          final h = remaining.inHours;
          final m = remaining.inMinutes % 60;
          return 'You are temporarily banned from accepting requests. '
              'Ban lifts in ${h}h ${m}m.';
        }
      }

      // Check donor concurrency limit (max 3 active)
      final activeSnap = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('donorId', isEqualTo: donorId)
          .where('status', whereIn: [
            RequestStatus.matched.name,
            RequestStatus.active.name,
            RequestStatus.pendingConfirmation.name,
          ])
          .get();
      if (activeSnap.docs.length >= 3) {
        return 'You already have 3 active requests. '
            'Complete or cancel one before accepting another.';
      }

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

  /// Get number of active requests a donor currently holds
  Future<int> getDonorActiveCount(String donorId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .where('donorId', isEqualTo: donorId)
          .where('status', whereIn: [
            RequestStatus.matched.name,
            RequestStatus.active.name,
            RequestStatus.pendingConfirmation.name,
          ])
          .get();
      return snap.docs.length;
    } catch (e) {
      return 0;
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

  /// Cancel a help request (sets status to cancelled)
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

  /// Donor withdraws from a request — resets it to pending so another donor can help
  Future<bool> withdrawFromRequest(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.pending.name,
        'donorId': null,
        'donorName': null,
        'matchedAt': null,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Donor withdraws after acceptance with a reason — applies a strike.
  /// Returns: 'warning' (1st strike), 'banned' (2nd strike → 24h ban), null = error.
  Future<String?> withdrawWithReason({
    required String requestId,
    required String donorId,
    required String reason,
  }) async {
    try {
      final strikeResult = await _applyDonorStrike(donorId);
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.pending.name,
        'donorId': null,
        'donorName': null,
        'matchedAt': null,
        'cancellationReason': reason,
        'cancelledBy': 'donor',
      });
      return strikeResult;
    } catch (e) {
      return null;
    }
  }

  /// Cancel a request with a required reason.
  /// If [cancelledBy] == 'donor', applies a strike to [donorId].
  /// Returns: 'success' (no strike), 'warning' (1st strike), 'banned' (2nd → ban), null = error.
  Future<String?> cancelRequestWithReason({
    required String requestId,
    required String reason,
    required String cancelledBy,
    String? donorId,
  }) async {
    try {
      String result = 'success';
      if (cancelledBy == 'donor' && donorId != null) {
        result = await _applyDonorStrike(donorId);
      }
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.cancelled.name,
        'cancellationReason': reason,
        'cancelledBy': cancelledBy,
      });
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Fetch current strike info for a donor.
  Future<Map<String, dynamic>> getDonorStrikeInfo(String donorId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(donorId)
          .get();
      final data = doc.data() ?? {};
      return {
        'strikes': (data['cancellationStrikes'] as int?) ?? 0,
        'banUntil': (data['banUntil'] as Timestamp?)?.toDate(),
        'strikeWindowStart': (data['strikeWindowStart'] as Timestamp?)?.toDate(),
      };
    } catch (e) {
      return {'strikes': 0, 'banUntil': null, 'strikeWindowStart': null};
    }
  }

  /// Increments donor's cancellation strike counter within a 30-day rolling window.
  /// Resets counter if window has expired. On 2nd strike, applies a 24h ban.
  /// Returns 'warning' (1st strike) or 'banned' (2nd strike).
  Future<String> _applyDonorStrike(String donorId) async {
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(donorId);
    return _firestore.runTransaction<String>((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};

      int strikes = (data['cancellationStrikes'] as int?) ?? 0;
      final windowStart = (data['strikeWindowStart'] as Timestamp?)?.toDate();
      final now = DateTime.now();

      // Reset if 30-day window has expired
      if (windowStart != null && now.difference(windowStart).inDays >= 30) {
        strikes = 0;
      }

      strikes += 1;

      if (strikes >= 2) {
        final banUntil = now.add(const Duration(hours: 24));
        tx.update(userRef, {
          'cancellationStrikes': 0,
          'strikeWindowStart': null,
          'banUntil': Timestamp.fromDate(banUntil),
        });
        return 'banned';
      } else {
        tx.update(userRef, {
          'cancellationStrikes': strikes,
          'strikeWindowStart': windowStart == null
              ? Timestamp.fromDate(now)
              : data['strikeWindowStart'],
        });
        return 'warning';
      }
    });
  }

  // ══════════════════════════════════════════════
  // COMPLETION VALIDATION
  // ══════════════════════════════════════════════

  /// Generate (or replace) the completion verification token for a request.
  Future<String> generateCompletionToken(String requestId) async {
    final token = _randomToken();
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .update({'completionToken': token});
    return token;
  }

  /// Clear the completion token (beneficiary hides QR).
  Future<void> revokeCompletionToken(String requestId) async {
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .update({'completionToken': null});
  }

  /// Donor submits delivery (optional photo) → status becomes pendingConfirmation.
  Future<bool> submitDelivery({
    required String requestId,
    String? photoUrl,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.pendingConfirmation.name,
        'deliveredAt': FieldValue.serverTimestamp(),
        if (photoUrl != null) 'completionPhotoUrl': photoUrl,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Beneficiary confirms receipt → request completed (mutual method).
  Future<bool> confirmDelivery(String requestId) async {
    try {
      await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .update({
        'status': RequestStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'completionMethod': 'mutual',
        'completionToken': null,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Donor scans QR — verify token then immediately complete the request.
  Future<bool> verifyQrAndComplete({
    required String requestId,
    required String token,
    String? photoUrl,
  }) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.helpRequestsCollection)
          .doc(requestId)
          .get();
      if (!doc.exists) return false;
      final stored = doc.data()?['completionToken'] as String?;
      if (stored == null || stored != token) return false;

      await doc.reference.update({
        'status': RequestStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'completionMethod': 'qr',
        'completionToken': null,
        if (photoUrl != null) 'completionPhotoUrl': photoUrl,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload a voice note to Firebase Storage and return the download URL.
  Future<String?> uploadVoiceNote({
    required String requestId,
    required File file,
  }) async {
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance
          .ref()
          .child('voice_notes')
          .child(requestId)
          .child(name);
      await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Upload a delivery proof photo to Firebase Storage.
  Future<String?> uploadCompletionPhoto({
    required String requestId,
    required File photoFile,
  }) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('completion_photos')
          .child('$requestId.jpg');
      await ref.putFile(photoFile, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Cryptographically random 32-character alphanumeric token.
  String _randomToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
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

  // ── Live location ──────────────────────────────────────────────────────────

  Future<String> createLiveLocationSession({
    required String requestId,
    required String senderId,
    required String senderName,
    required double latitude,
    required double longitude,
    required DateTime expiryTime,
  }) async {
    final doc = await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection('liveLocations')
        .add({
      'senderId': senderId,
      'senderName': senderName,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': FieldValue.serverTimestamp(),
      'expiryTime': Timestamp.fromDate(expiryTime),
      'isActive': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateLiveLocation({
    required String requestId,
    required String sessionId,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection('liveLocations')
        .doc(sessionId)
        .update({
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopLiveLocationSession({
    required String requestId,
    required String sessionId,
  }) async {
    await _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection('liveLocations')
        .doc(sessionId)
        .update({'isActive': false});
  }

  Stream<Map<String, dynamic>?> getLiveLocationStream(
      String requestId, String sessionId) {
    return _firestore
        .collection(AppConstants.helpRequestsCollection)
        .doc(requestId)
        .collection('liveLocations')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // ── Conversations ──────────────────────────────────────────────────────────

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

  // ══════════════════════════════════════════════
  // REPORTS
  // ══════════════════════════════════════════════

  Future<bool> submitReport(ReportModel report) async {
    try {
      await _firestore
          .collection(AppConstants.reportsCollection)
          .add(report.toFirestore());
      return true;
    } catch (e) {
      debugPrint('[Reports] submit failed: $e');
      return false;
    }
  }

  Future<bool> uploadICPhoto({
    required String userId,
    required File file,
  }) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('ic_photos')
          .child('$userId.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return true;
    } catch (e) {
      debugPrint('[IC] photo upload failed: $e');
      return false;
    }
  }

  Future<String?> uploadReportPhoto({
    required String reporterId,
    required File file,
  }) async {
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('report_photos')
          .child(reporterId)
          .child(name);
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ── Helpers ──

  DateTime _getWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - DateTime.monday;
    final monday = now.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }
}
