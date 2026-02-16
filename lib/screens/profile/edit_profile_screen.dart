import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/tokens.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _timeZoneCtrl;
  late final TextEditingController _interestTagsCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _experienceCtrl;

  final List<String> _allExpertise = const [
    'Resume review',
    'Interview prep',
    'PR guidance',
    'School applications',
    'Language practice',
    'Settlement tips',
    'Mental health support',
    'Career transitions',
  ];

  bool _saving = false;
  File? _imageFile;
  String? _profileImageUrl;

  String _role = 'seeker';
  String _mode = 'chat';
  String? _country;
  String? _language;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<String> _selectedExpertise = {};

  bool get _isHelperRole => _role == 'helper' || _role == 'both';

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const TextStyle _subLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
  );
  static const TextStyle _chipLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
  static const TextStyle _inputTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(
      text:
          (widget.userData['displayName'] ?? widget.userData['fullName'] ?? '')
              .toString(),
    );
    _bioCtrl =
        TextEditingController(text: (widget.userData['bio'] ?? '').toString());
    _cityCtrl =
        TextEditingController(text: (widget.userData['city'] ?? '').toString());
    _timeZoneCtrl = TextEditingController(
      text: (widget.userData['timeZone'] ?? '').toString(),
    );
    _interestTagsCtrl = TextEditingController(
      text: (widget.userData['interestTags'] is List)
          ? (widget.userData['interestTags'] as List).join(', ')
          : '',
    );
    _skillsCtrl = TextEditingController(
      text: (widget.userData['skills'] is List)
          ? (widget.userData['skills'] as List).join(', ')
          : (widget.userData['skills'] ?? '').toString(),
    );
    _experienceCtrl = TextEditingController(
      text: (widget.userData['experience'] ?? '').toString(),
    );

    _role = (widget.userData['role'] ?? 'seeker').toString();
    _mode = (widget.userData['mode'] ?? 'chat').toString();
    _country = _asNullableString(widget.userData['country']);
    _language = _asNullableString(widget.userData['language']);
    _profileImageUrl = _asNullableString(widget.userData['profilePicture']);

    _selectedExpertise
      ..clear()
      ..addAll(
        (widget.userData['expertiseTags'] is List)
            ? List<String>.from(widget.userData['expertiseTags'])
            : const <String>[],
      );

    final availability = (widget.userData['availability'] ?? '').toString();
    if (availability.contains('–')) {
      final parts = availability.split('–');
      if (parts.length == 2) {
        _startTime = _parseTimeOfDay(parts[0].trim());
        _endTime = _parseTimeOfDay(parts[1].trim());
      }
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _timeZoneCtrl.dispose();
    _interestTagsCtrl.dispose();
    _skillsCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  String? _asNullableString(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _parseCsv(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
      int minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      final lower = time.toLowerCase();
      if (lower.contains('pm') && hour < 12) hour += 12;
      if (lower.contains('am') && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_imageFile == null) return _profileImageUrl;
    final ref = FirebaseStorage.instance.ref().child(
        'users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_imageFile!, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _pickAvailability() async {
    final st = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (st == null || !mounted) return;
    final en = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (en == null) return;
    setState(() {
      _startTime = st;
      _endTime = en;
    });
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_language == null || _language!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a language.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    final availabilityValue =
        (_isHelperRole && _startTime != null && _endTime != null)
            ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
            : '';

    setState(() => _saving = true);
    try {
      final displayName = _displayNameCtrl.text.trim();
      final uploadedImageUrl = await _uploadProfileImage(user.uid);

      final payload = <String, dynamic>{
        'displayName': displayName,
        'displayName_lc': displayName.toLowerCase(),
        'fullName': displayName,
        'fullNameLower': displayName.toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'timeZone': _timeZoneCtrl.text.trim(),
        'country': _country ?? '',
        'language': _language ?? '',
        'role': _role,
        'interestTags': _parseCsv(_interestTagsCtrl.text.trim()),
        'skills': _parseCsv(_skillsCtrl.text.trim()),
        'experience': _experienceCtrl.text.trim(),
        'expertiseTags':
            _isHelperRole ? _selectedExpertise.toList() : <String>[],
        'mode': _isHelperRole ? _mode : 'chat',
        'availability': availabilityValue,
        'profilePicture': (uploadedImageUrl ?? '').trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (user.displayName != displayName) {
        await user.updateDisplayName(displayName);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.muted, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: _sectionTitleStyle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      labelStyle: _subLabelStyle,
      floatingLabelStyle: _subLabelStyle,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      helperStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      hintStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      filled: true,
      fillColor: AppColors.button,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _role == value;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        selected ? Icons.check : icon,
        size: 18,
        color: selected ? AppColors.text : AppColors.muted,
      ),
      label: Text(label),
      selectedColor: AppColors.button,
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: _chipLabelStyle,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _role = value);
      },
    );
  }

  Widget _modePill(String value, String label) {
    final selected = _mode == value;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      selectedColor: AppColors.button,
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: _chipLabelStyle,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _mode = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availabilityLabel = (_startTime == null || _endTime == null)
        ? 'Not set'
        : '${_startTime!.format(context)} – ${_endTime!.format(context)}';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                icon: Icons.account_circle_outlined,
                title: 'Profile',
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.avatarBg,
                            foregroundColor: AppColors.avatarFg,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : ((_profileImageUrl ?? '').isNotEmpty
                                    ? NetworkImage(_profileImageUrl!)
                                    : null),
                            child: (_imageFile == null &&
                                    (_profileImageUrl ?? '').isEmpty)
                                ? const Icon(Icons.camera_alt, size: 26)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.button,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.edit, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _displayNameCtrl,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(label: 'Display name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Display name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bioCtrl,
                    style: _inputTextStyle,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _fieldDecoration(
                      label: 'Bio',
                      hint: 'Write a short intro about yourself',
                    ),
                  ),
                ],
              ),
              _section(
                icon: Icons.public_outlined,
                title: 'Location & Language',
                children: [
                  TextFormField(
                    controller: _cityCtrl,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(label: 'City'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _timeZoneCtrl,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Time zone',
                      hint: 'e.g. GMT-5',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('country_${_country ?? ''}'),
                    initialValue: _country,
                    decoration: _fieldDecoration(label: 'Country'),
                    style: _inputTextStyle,
                    isDense: true,
                    dropdownColor: AppColors.card,
                    iconEnabledColor: AppColors.muted,
                    items: const ['Canada', 'USA', 'Other']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _country = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('language_${_language ?? ''}'),
                    initialValue: _language,
                    decoration: _fieldDecoration(label: 'Language'),
                    style: _inputTextStyle,
                    isDense: true,
                    dropdownColor: AppColors.card,
                    iconEnabledColor: AppColors.muted,
                    items: const ['English', 'French', 'Other']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _language = v),
                  ),
                ],
              ),
              _section(
                icon: Icons.tune_outlined,
                title: 'Preferences',
                children: [
                  const Text(
                    'Role',
                    style: _subLabelStyle,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _roleChip('seeker', 'Get Help', Icons.help_outline),
                      _roleChip('helper', 'Give Help',
                          Icons.volunteer_activism_outlined),
                      _roleChip('both', 'Both', Icons.all_inclusive),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _interestTagsCtrl,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Topics',
                      helperText:
                          'Comma separated (e.g. PR Pathways, Student life)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _skillsCtrl,
                    style: _inputTextStyle,
                    decoration: _fieldDecoration(
                      label: 'Skills',
                      helperText: 'Comma separated',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _experienceCtrl,
                    style: _inputTextStyle,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _fieldDecoration(label: 'Experience'),
                  ),
                ],
              ),
              if (_isHelperRole)
                _section(
                  icon: Icons.handshake_outlined,
                  title: 'Helper Profile',
                  children: [
                    const Text(
                      'Areas of expertise',
                      style: _subLabelStyle,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allExpertise.map((e) {
                        final selected = _selectedExpertise.contains(e);
                        return ChoiceChip(
                          selected: selected,
                          showCheckmark: false,
                          label: Text(e),
                          avatar: Icon(
                            Icons.check,
                            size: 18,
                            color:
                                selected ? AppColors.text : Colors.transparent,
                          ),
                          selectedColor: AppColors.button,
                          backgroundColor: AppColors.card,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.45)
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              selected
                                  ? _selectedExpertise.remove(e)
                                  : _selectedExpertise.add(e);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Preferred mode',
                      style: _subLabelStyle,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _modePill('chat', 'Chat'),
                        _modePill('call', 'Call'),
                        _modePill('video', 'Video'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time, size: 20),
                      title: const Text(
                        'Availability',
                        style: _subLabelStyle,
                      ),
                      subtitle: Text(availabilityLabel),
                      trailing: TextButton(
                        onPressed: _pickAvailability,
                        child: const Text('Set'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ElevatedButton(
          onPressed: _saving ? null : _saveProfile,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ),
    );
  }
}
