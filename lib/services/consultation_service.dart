import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsultationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Books a consultation with the given target user for a specified number of minutes.
  /// Applies free minutes and discount if the booking user is premium (trial or active).
  Future<void> bookConsultation(String targetUserId, int minutesRequested) async {
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

    // Fetch both user and target documents.
    final DocumentSnapshot userDoc = await userRef.get();
    final DocumentSnapshot targetDoc = await targetRef.get();

    if (!userDoc.exists || !targetDoc.exists) {
      throw Exception("User or target not found.");
    }

    final Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
    final Map<String, dynamic> targetData = targetDoc.data() as Map<String, dynamic>;

    // Get target user's rate per minute (for consultation). 
    // You may set a default value if not specified.
    final int ratePerMinute = targetData['ratePerMinute'] ?? 0;
    final int baseCost = ratePerMinute * minutesRequested;

    // Check user's premium status and consultation benefits.
    String premiumStatus = userData['premiumStatus'] ?? 'none';
    int freeMinutes = userData['freeConsultationMinutes'] ?? 0;
    int discountPercent = userData['discountPercent'] ?? 0;

    int cost = baseCost;
    int appliedFreeMinutes = 0;

    // For premium users (trial or active), apply free minutes and discount.
    if (premiumStatus == 'trial' || premiumStatus == 'active') {
      if (freeMinutes > 0) {
        appliedFreeMinutes = (minutesRequested <= freeMinutes)
            ? minutesRequested
            : freeMinutes;
        int reduction = ratePerMinute * appliedFreeMinutes;
        cost = cost - reduction;
      }
      if (cost > 0 && discountPercent > 0) {
        cost = cost - ((cost * discountPercent) ~/ 100);
      }
    }

    if (cost < 0) cost = 0;

    // Create a consultation record.
    final DocumentReference consultationRef =
        _firestore.collection('consultations').doc();

    await _firestore.runTransaction((transaction) async {
      // If free minutes were applied, update the user's free minutes.
      if (appliedFreeMinutes > 0) {
        int newFreeMinutes = freeMinutes - appliedFreeMinutes;
        transaction.update(userRef, {'freeConsultationMinutes': newFreeMinutes});
      }

      // Insert the consultation record.
      transaction.set(consultationRef, {
        'consultationId': consultationRef.id,
        'userId': userId,
        'targetUserId': targetUserId,
        'minutesRequested': minutesRequested,
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
