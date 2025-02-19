import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController bioController;
  late TextEditingController journeyController;
  late TextEditingController interestTagsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    journeyController = TextEditingController(text: widget.userData['careerJourney'] ?? '');
    interestTagsController = TextEditingController(text: widget.userData['interestTags']?.join(', ') ?? '');
  }

  Future<void> _saveProfile() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fullName': nameController.text.trim(),
        'bio': bioController.text.trim(),
        'careerJourney': journeyController.text.trim(),
        'interestTags': interestTagsController.text.trim().isNotEmpty
            ? interestTagsController.text.trim().split(', ')
            : [],
      });

      Navigator.pop(context, {
        'fullName': nameController.text.trim(),
        'bio': bioController.text.trim(),
        'careerJourney': journeyController.text.trim(),
        'interestTags': interestTagsController.text.trim().isNotEmpty
            ? interestTagsController.text.trim().split(', ')
            : [],
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 10),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio')),
            const SizedBox(height: 10),
            TextField(controller: journeyController, decoration: const InputDecoration(labelText: 'Your Journey')),
            const SizedBox(height: 10),
            TextField(controller: interestTagsController, decoration: const InputDecoration(labelText: 'Interest Tags')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
