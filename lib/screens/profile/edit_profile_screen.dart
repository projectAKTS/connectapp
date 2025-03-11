import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController bioController;
  late TextEditingController interestTagsController;
  late TextEditingController locationController;
  late TextEditingController skillsController;
  bool _isLoading = false;
  File? _imageFile;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    interestTagsController = TextEditingController(text: widget.userData['interestTags']?.join(', ') ?? '');
    locationController = TextEditingController(text: widget.userData['location'] ?? '');
    skillsController = TextEditingController(text: widget.userData['skills']?.join(', ') ?? '');
    _profileImageUrl = widget.userData['profileImage'];
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_imageFile == null) return _profileImageUrl;
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance.ref().child('profile_pics/$userId.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _isLoading = true);

    String? uploadedImageUrl = await _uploadProfileImage();

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fullName': nameController.text.trim(),
        'bio': bioController.text.trim(),
        'interestTags': interestTagsController.text.trim().isNotEmpty
            ? interestTagsController.text.trim().split(', ')
            : [],
        'location': locationController.text.trim(),
        'skills': skillsController.text.trim().isNotEmpty ? skillsController.text.trim().split(', ') : [],
        'profileImage': uploadedImageUrl ?? _profileImageUrl,
      });

      Navigator.pop(context, {
        'fullName': nameController.text.trim(),
        'bio': bioController.text.trim(),
        'interestTags': interestTagsController.text.trim().isNotEmpty
            ? interestTagsController.text.trim().split(', ')
            : [],
        'location': locationController.text.trim(),
        'skills': skillsController.text.trim().isNotEmpty ? skillsController.text.trim().split(', ') : [],
        'profileImage': uploadedImageUrl ?? _profileImageUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (_profileImageUrl != null ? NetworkImage(_profileImageUrl!) : AssetImage('assets/default_profile.png')) as ImageProvider,
                child: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio')),
            TextField(controller: interestTagsController, decoration: const InputDecoration(labelText: 'Interest Tags')),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
            TextField(controller: skillsController, decoration: const InputDecoration(labelText: 'Skills')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _isLoading ? null : _saveProfile, child: _isLoading ? CircularProgressIndicator() : Text('Save Changes')),
          ],
        ),
      ),
    );
  }
}
