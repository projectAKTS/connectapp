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

  List<String> suggestedHelpTopics = [];
  List<String> userSelectedHelpTopics = [];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    journeyController = TextEditingController(text: widget.userData['careerJourney'] ?? '');
    interestTagsController = TextEditingController(text: widget.userData['interestTags']?.join(', ') ?? '');

    userSelectedHelpTopics = List<String>.from(widget.userData['helpTopics'] ?? []);

    generateSuggestedHelpTopics();
  }

  /// 🔹 Dynamically generates help topics based on user input
  void generateSuggestedHelpTopics() {
    Set<String> topics = {};

    String journey = journeyController.text.toLowerCase();

    if (journey.contains("canada")) topics.add("Immigration to Canada");
    if (journey.contains("university") || journey.contains("study")) topics.add("Studying in Canada");
    if (journey.contains("job") || journey.contains("career")) topics.add("Job Search & Career Growth");
    if (journey.contains("developer") || journey.contains("tech")) topics.add("Career in Tech");
    if (journey.contains("family") || journey.contains("sponsorship")) topics.add("Family Sponsorship & Reunion");

    setState(() {
      suggestedHelpTopics = topics.toList();
    });
  }

  /// 🔹 Saves the updated profile to Firestore
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
        'helpTopics': userSelectedHelpTopics,
        'interestTags': interestTagsController.text.trim().isNotEmpty
            ? interestTagsController.text.trim().split(', ')
            : [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, {
        'fullName': nameController.text.trim(),
        'bio': bioController.text.trim(),
        'careerJourney': journeyController.text.trim(),
        'helpTopics': userSelectedHelpTopics,
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

  /// 🔹 Adds or removes help topics
  void toggleHelpTopic(String topic) {
    setState(() {
      if (userSelectedHelpTopics.contains(topic)) {
        userSelectedHelpTopics.remove(topic);
      } else {
        userSelectedHelpTopics.add(topic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/default_profile.png'),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
                onChanged: (_) => generateSuggestedHelpTopics(),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: journeyController,
                decoration: const InputDecoration(labelText: 'Your Life & Career Journey'),
                maxLines: 3,
                onChanged: (_) => generateSuggestedHelpTopics(),
              ),
              const SizedBox(height: 10),

              const Text('How You Can Help:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  ...suggestedHelpTopics.map((topic) => ChoiceChip(
                        label: Text(topic),
                        selected: userSelectedHelpTopics.contains(topic),
                        onSelected: (selected) => toggleHelpTopic(topic),
                      )),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: interestTagsController,
                decoration: const InputDecoration(labelText: 'Interest Tags (comma separated)'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
