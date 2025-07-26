import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connect_app/screens/consultation/consultation_call_screen.dart';
import 'package:connect_app/utils/time_utils.dart';

class MyConsultationsScreen extends StatelessWidget {
  const MyConsultationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view consultations.')),
      );
    }
    final currentUserId = currentUser.uid;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('My Consultations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading consultations.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No consultations found.'));
          }

          // Filter to only include upcoming consultations
          final allConsultations = snapshot.data!.docs;
          final upcomingConsultations = allConsultations.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final scheduledAt = parseFirestoreTimestamp(data['scheduledAt']);
            if (scheduledAt == null) return false;
            return scheduledAt.isAfter(now);
          }).toList();

          if (upcomingConsultations.isEmpty) {
            return const Center(child: Text('No upcoming consultations.'));
          }

          return ListView.builder(
            itemCount: upcomingConsultations.length,
            itemBuilder: (context, index) {
              final doc = upcomingConsultations[index];
              final data = doc.data() as Map<String, dynamic>;
              final consultationId = data['consultationId'] ?? doc.id;
              final scheduledAt = parseFirestoreTimestamp(data['scheduledAt']);
              final cost = data['cost'] ?? 0;
              final minutes = data['minutesRequested'] ?? 0;
              // Use roomId if stored, otherwise fall back to consultationId
              final roomId = data['roomId'] ?? consultationId;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Consultation: $consultationId'),
                  subtitle: Text(
                    'Scheduled At: ${scheduledAt != null ? DateFormat.yMMMd().add_jm().format(scheduledAt) : "Not set"}\n'
                    'Minutes: $minutes\nCost: \$$cost',
                  ),
                  trailing: ElevatedButton(
                    child: const Text('Join'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConsultationCallScreen(
                            roomId: roomId,
                            userName: currentUser.displayName ?? 'User',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
