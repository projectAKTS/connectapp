import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/services/consultation_service.dart';

class ExpertDirectoryScreen extends StatelessWidget {
  const ExpertDirectoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect With Others')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            // Query all users except the current user.
            .where(FieldPath.documentId, isNotEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          final users = snapshot.data!.docs;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> userData =
                  users[index].data() as Map<String, dynamic>;
              final String userId = users[index].id;
              final String fullName = userData['fullName'] ?? 'User';
              final int rate = userData['ratePerMinute'] ?? 0;

              return ListTile(
                title: Text(fullName),
                subtitle: Text('Consultation Rate: $rate per minute'),
                trailing: ElevatedButton(
                  child: const Text('Book Consultation'),
                  onPressed: () async {
                    // For demonstration, use a fixed duration (e.g., 15 minutes).
                    const int minutesRequested = 15;
                    try {
                      await ConsultationService()
                          .bookConsultation(userId, minutesRequested);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Consultation booked successfully.'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error booking consultation: $e'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
