import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class ConsultationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Books a consultation with the given target user for a specified number of minutes.
  /// Optionally takes a scheduledAt DateTime for future appointments.
  /// Applies discount if the booking user is premium (trial or active).
  Future<void> bookConsultation(
    String targetUserId,
    int minutesRequested, {
    DateTime? scheduledAt,
    double? costOverride,
    String? paymentIntentId,
    String? currency,
  }) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User not logged in.");
    }

    final String userId = currentUser.uid;
    if (targetUserId == userId) {
      throw Exception("You cannot book a consultation with yourself.");
    }

    final DocumentReference userRef = _firestore.collection('users').doc(userId);
    final DocumentReference targetRef = _firestore.collection('users').doc(targetUserId);

    final DocumentSnapshot userDoc = await userRef.get();
    final DocumentSnapshot targetDoc = await targetRef.get();

    if (!userDoc.exists || !targetDoc.exists) {
      throw Exception("User or target not found.");
    }

    final Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
    final Map<String, dynamic> targetData = targetDoc.data() as Map<String, dynamic>;

    // Rate per minute for the target user (default 0 if not set).
    final int ratePerMinute = targetData['ratePerMinute'] ?? 0;
    final int baseCost = ratePerMinute * minutesRequested;

    // Check booking user's premium status and benefits.
    final String premiumStatus = userData['premiumStatus'] ?? 'none';
    int discountPercent = userData['discountPercent'] ?? 0;

    double cost = costOverride ?? baseCost.toDouble();
    // If user is trial or active premium, apply discount.
    if (premiumStatus == 'trial' || premiumStatus == 'active') {
      if (cost > 0 && discountPercent > 0) {
        cost -= (cost * discountPercent / 100);
      }
    }

    if (cost < 0) cost = 0;

    // If no scheduledAt is provided, default to now.
    final DateTime finalScheduledAt = scheduledAt ?? DateTime.now();

    final DocumentReference consultationRef =
        _firestore.collection('consultations').doc();

    // Generate a unique room ID for the consultation
    final String roomId = const Uuid().v4();

    await _firestore.runTransaction((transaction) async {
      // Create the consultation document with extra fields.
      transaction.set(consultationRef, {
        'consultationId': consultationRef.id,
        'userId': userId,
        'targetUserId': targetUserId,
        'participants': [userId, targetUserId], // Enables queries for both users.
        'roomId': roomId, // Unique room ID for joining the call.
        'minutesRequested': minutesRequested,
        'cost': cost,
        'currency': currency ?? 'cad',
        'paymentIntentId': paymentIntentId,
        'status': 'scheduled',
        'timestamp': FieldValue.serverTimestamp(),
        'scheduledAt': finalScheduledAt,
      });
    });
  }
}
