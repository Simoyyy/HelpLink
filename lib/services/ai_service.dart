import 'dart:convert';
import 'dart:math';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/models/user_model.dart';

class RecommendedRequest {
  final HelpRequest request;
  final String reason;
  final bool isUrgent;

  const RecommendedRequest({
    required this.request,
    required this.reason,
    this.isUrgent = false,
  });
}

class AIService {
  // Get your FREE Gemini API key at: https://aistudio.google.com/app/apikey
  // Replace 'YOUR_GEMINI_API_KEY' with your actual key.
  static const String _apiKey = 'AIzaSyDTvOw7FDqDIieopikqmc7NyTNuXThIbc8';
  static const int _maxRecommendations = 3;

  bool get _hasApiKey => _apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_');

  Future<List<RecommendedRequest>> getRecommendedRequests({
    required UserModel donor,
    required List<HelpRequest> availableRequests,
    required List<String> previousCategories,
  }) async {
    if (availableRequests.isEmpty) return [];

    if (_hasApiKey) {
      try {
        return await _getAIRecommendations(
          donor: donor,
          availableRequests: availableRequests,
          previousCategories: previousCategories,
        );
      } catch (_) {
        // Fall through to scoring algorithm on any error
      }
    }

    return _getScoredRecommendations(
      donor: donor,
      availableRequests: availableRequests,
      previousCategories: previousCategories,
    );
  }

  Future<List<RecommendedRequest>> _getAIRecommendations({
    required UserModel donor,
    required List<HelpRequest> availableRequests,
    required List<String> previousCategories,
  }) async {
    final isFirstTime = previousCategories.isEmpty;

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );

    final requestsJson = availableRequests
        .take(15)
        .map((r) => {
              'id': r.id,
              'title': r.title,
              'category': r.category.name,
              'description': r.description.length > 100
                  ? '${r.description.substring(0, 100)}...'
                  : r.description,
              'location': r.location ?? 'Unknown',
              'isEmergency': r.isEmergency,
              'postedHoursAgo': DateTime.now().difference(r.createdAt).inHours,
            })
        .toList();

    final donorContext = isFirstTime
        ? 'This is a first-time donor with no donation history. '
            'Prioritize requests CLOSEST to their location.'
        : 'Previously donated categories: ${previousCategories.join(', ')}.';

    final prompt = '''
You are a smart matching AI for HelpLink, a humanitarian aid app.
Analyze these help requests and recommend the top $_maxRecommendations most suitable ones for this donor.

Donor Profile:
- Location: ${donor.location ?? 'Not specified'}
- $donorContext

Available Requests (JSON):
${jsonEncode(requestsJson)}

Return ONLY a valid JSON array of the top $_maxRecommendations request IDs with a brief reason (max 12 words each).
Format: [{"id":"...","reason":"..."}]
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';

    final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(text);
    if (jsonMatch == null) throw Exception('No JSON in response');

    final List<dynamic> parsed = jsonDecode(jsonMatch.group(0)!);
    final results = <RecommendedRequest>[];

    for (final item in parsed) {
      final id = item['id'] as String?;
      final reason = item['reason'] as String? ?? 'Recommended for you';
      if (id == null) continue;

      final matchIdx = availableRequests.indexWhere((r) => r.id == id);
      if (matchIdx == -1) continue;

      results.add(RecommendedRequest(
        request: availableRequests[matchIdx],
        reason: reason,
        isUrgent: _detectUrgency(availableRequests[matchIdx].description),
      ));
      if (results.length >= _maxRecommendations) break;
    }

    return results;
  }

  List<RecommendedRequest> _getScoredRecommendations({
    required UserModel donor,
    required List<HelpRequest> availableRequests,
    required List<String> previousCategories,
  }) {
    final rng = Random();
    final isFirstTime = previousCategories.isEmpty;

    final scored = availableRequests.map((r) {
      int score = rng.nextInt(10);

      // ── Category match (returning donors) ──
      if (previousCategories.contains(r.category.name)) score += 35;

      // ── Emergency always gets a boost ──
      if (r.isEmergency) score += 25;

      // ── Urgency detected from description ──
      if (_detectUrgency(r.description)) score += 40;

      // ── Recency boost ──
      final ageHours = DateTime.now().difference(r.createdAt).inHours;
      if (ageHours <= 24) {
        score += 15;
      } else if (ageHours <= 72) {
        score += 8;
      }

      // ── Location proximity ──
      if (donor.latitude != null &&
          donor.longitude != null &&
          r.latitude != null &&
          r.longitude != null) {
        // Haversine distance — higher score for closer requests
        final km = _haversineKm(
          donor.latitude!,
          donor.longitude!,
          r.latitude!,
          r.longitude!,
        );
        // First-time donors: proximity is the primary signal (up to +50)
        // Returning donors: proximity is a secondary signal (up to +20)
        final maxProximityScore = isFirstTime ? 50 : 20;
        if (km <= 5) {
          score += maxProximityScore;
        } else if (km <= 10) {
          score += (maxProximityScore * 0.8).round();
        } else if (km <= 20) {
          score += (maxProximityScore * 0.6).round();
        } else if (km <= 50) {
          score += (maxProximityScore * 0.3).round();
        }
      } else if (donor.location != null && r.location != null) {
        // Fallback: text-based region match
        final donorParts = donor.location!.toLowerCase().split(',');
        for (final part in donorParts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty &&
              r.location!.toLowerCase().contains(trimmed)) {
            score += isFirstTime ? 40 : 20;
            break;
          }
        }
      }

      final urgent = _detectUrgency(r.description);
      return (
        request: r,
        score: score,
        km: _distanceKm(donor, r),
        isUrgent: urgent
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.take(_maxRecommendations).map((entry) {
      final r = entry.request;
      final String reason;

      if (entry.isUrgent) {
        reason = 'Critical need detected — immediate assistance required';
      } else if (isFirstTime) {
        // First-time donors: highlight proximity
        if (r.isEmergency) {
          reason = 'Emergency nearby — needs immediate help';
        } else if (entry.km != null && entry.km! <= 20) {
          final distStr = entry.km! < 1
              ? 'less than 1 km'
              : '${entry.km!.toStringAsFixed(1)} km';
          reason = 'Closest request near you — $distStr away';
        } else if (donor.location != null &&
            r.location != null &&
            r.location!
                .toLowerCase()
                .contains(donor.location!.split(',').first.toLowerCase())) {
          reason = 'In your area — great first request to help';
        } else {
          reason = 'Good starting request for a new donor';
        }
      } else {
        // Returning donors: highlight category match or location
        if (r.isEmergency) {
          reason = 'Urgent emergency request needing immediate help';
        } else if (previousCategories.contains(r.category.name)) {
          reason = 'Matches your previous ${r.category.name} donations';
        } else if (donor.location != null &&
            r.location != null &&
            r.location!
                .toLowerCase()
                .contains(donor.location!.split(',').first.toLowerCase())) {
          reason = 'Located in your area for easy assistance';
        } else {
          reason = 'New request that could use your support';
        }
      }

      return RecommendedRequest(
          request: r, reason: reason, isUrgent: entry.isUrgent);
    }).toList();
  }

  // ── Urgency detection from description text ──
  // Returns true if the description contains signals of critical deprivation
  // or life-threatening need (e.g. "haven't eaten for 2 days").
  bool _detectUrgency(String description) {
    final text = description.toLowerCase();

    // Time-based deprivation patterns: "X days without", "X days no food", etc.
    final deprivationDayPattern = RegExp(
        r"(\d+|two|three|four|five)\s*days?\s*(without|no|haven't|haven)");
    if (deprivationDayPattern.hasMatch(text)) return true;

    // Direct starvation / hunger phrases
    final hungerPhrases = [
      "haven't eaten",
      "have not eaten",
      "no food",
      "no water",
      "starving",
      "starvation",
      "going hungry",
      "days without food",
      "days without water",
      "days without eating",
    ];
    for (final phrase in hungerPhrases) {
      if (text.contains(phrase)) return true;
    }

    // Critical health / shelter phrases
    final criticalPhrases = [
      "can't breathe",
      "cannot breathe",
      "severe pain",
      "critical condition",
      "life threatening",
      "life-threatening",
      "no shelter",
      "sleeping on the street",
      "sleeping outside",
      "no medication",
      "out of medicine",
      "ran out of medicine",
      "dying",
      "unconscious",
    ];
    for (final phrase in criticalPhrases) {
      if (text.contains(phrase)) return true;
    }

    return false;
  }

  // ── Haversine formula (returns km) ──
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  // Returns null if either party lacks coordinates
  double? _distanceKm(UserModel donor, HelpRequest r) {
    if (donor.latitude == null ||
        donor.longitude == null ||
        r.latitude == null ||
        r.longitude == null) {
      return null;
    }
    return _haversineKm(
        donor.latitude!, donor.longitude!, r.latitude!, r.longitude!);
  }
}
