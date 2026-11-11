import 'dart:io';

import 'package:connect_app/models/help_topics.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/models/profile_languages.dart';
import 'package:connect_app/utils/availability_time.dart';
import 'package:connect_app/utils/profile_text.dart';
import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:connect_app/widgets/spoken_languages_field.dart';
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

  final List<String> _allExpertise = HelpTopics.expertise;

  bool _saving = false;
  File? _imageFile;
  String? _profileImageUrl;

  String _role = 'seeker';
  String _mode = 'chat';
  String? _country;

  /// Languages the person speaks (ISO codes); not the app language.
  List<String> _spoken = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<String> _selectedExpertise = {};

  bool get _isHelperRole => _role == 'helper' || _role == 'both';

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(
      text:
          (widget.userData['displayName'] ?? widget.userData['fullName'] ?? '')
              .toString(),
    );
    _bioCtrl = TextEditingController(
      // Old signups stored a placeholder sentence; show it as empty.
      text: placeholderBioToEmpty((widget.userData['bio'] ?? '').toString()),
    );
    _cityCtrl = TextEditingController(
      text: (widget.userData['city'] ?? '').toString(),
    );
    // Suggest the device's offset when empty; the field stays editable.
    final storedZone = (widget.userData['timeZone'] ?? '').toString().trim();
    _timeZoneCtrl = TextEditingController(
      text: storedZone.isNotEmpty
          ? storedZone
          : AvailabilityTime.deviceTimeZone(),
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
    _spoken = ProfileLanguages.read(widget.userData);
    _profileImageUrl = _asNullableString(widget.userData['profilePicture']);

    _selectedExpertise
      ..clear()
      ..addAll(
        (widget.userData['expertiseTags'] is List)
            ? List<String>.from(widget.userData['expertiseTags'])
            : const <String>[],
      );

    final range = AvailabilityTime.parse(
      '${widget.userData['availability'] ?? ''}',
    );
    if (range != null) {
      _startTime = range.$1;
      _endTime = range.$2;
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
          'users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
    await ref.putFile(_imageFile!, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Common hours, so most helpers pick with one tap; Custom opens clocks.
  static const _presets = <String, (TimeOfDay, TimeOfDay)>{
    'allDay': (TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)),
    'mornings': (TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 12, minute: 0)),
    'afternoons': (
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 17, minute: 0)
    ),
    'evenings': (
      TimeOfDay(hour: 17, minute: 0),
      TimeOfDay(hour: 21, minute: 0)
    ),
  };

  /// The preset matching the stored hours, 'custom', or null when not set.
  String? get _availabilityChoice {
    if (_startTime == null || _endTime == null) return null;
    for (final e in _presets.entries) {
      if (e.value.$1 == _startTime && e.value.$2 == _endTime) return e.key;
    }
    return 'custom';
  }

  void _choosePreset(String key) {
    final range = _presets[key]!;
    setState(() {
      // Tapping the chosen one again clears it.
      if (_availabilityChoice == key) {
        _startTime = _endTime = null;
      } else {
        _startTime = range.$1;
        _endTime = range.$2;
      }
    });
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
    // Profiles from older builds may hold only 'Other', which has no code;
    // they keep it until a language is picked.
    if (_spoken.isEmpty &&
        '${widget.userData['language'] ?? ''}'.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.spokenLanguagesRequired)),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    final availabilityValue =
        (_isHelperRole && _startTime != null && _endTime != null)
            ? AvailabilityTime.store(_startTime!, _endTime!)
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
        ...ProfileLanguages.fields(_spoken),
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
        SnackBar(content: Text(context.l10n.editProfileSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCountry() async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.canvas,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in const ['Canada', 'USA', 'Other'])
              ListTile(
                title: Text(ValueLabels.country(l10n, c)),
                trailing: _country == c
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _pickLanguages() async {
    final picked = await showSpokenLanguagesSheet(context, _spoken);
    if (picked != null) setState(() => _spoken = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final availability = (_startTime == null || _endTime == null)
        ? ''
        : '${_startTime!.format(context)} – ${_endTime!.format(context)}';
    final languages =
        _spoken.map((c) => ValueLabels.language(l10n, c)).join(', ');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.editProfileTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : TextButton(
                    key: const Key('edit_profile_save'),
                    onPressed: _saveProfile,
                    style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent),
                    child: Text(
                      l10n.commonSave,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        // Not a ListView: every field stays built, so the name check runs
        // even when the name is scrolled out of sight.
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PhotoHeader(
                file: _imageFile,
                url: _profileImageUrl ?? '',
                name: _displayNameCtrl.text,
                label: l10n.editProfileChangePhoto,
                onTap: _pickImage,
              ),
              _SectionLabel(l10n.editProfileBasics),
              _Group(
                children: [
                  _TextRow(
                    label: l10n.onboardingDisplayName,
                    controller: _displayNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.editProfileNameRequired
                        : null,
                  ),
                  _TextRow(
                    label: l10n.editProfileBio,
                    controller: _bioCtrl,
                    hint: l10n.editProfileBioHint,
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
              ),
              _SectionLabel(l10n.editProfileLocationLanguage),
              _Group(
                children: [
                  _TextRow(
                    label: l10n.onboardingCity,
                    controller: _cityCtrl,
                    hint: l10n.onboardingCityHint,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _PickerRow(
                    label: l10n.editProfileCountry,
                    value: _country == null
                        ? ''
                        : ValueLabels.country(l10n, _country!),
                    placeholder: l10n.editProfileAddCountry,
                    onTap: _pickCountry,
                  ),
                  _TextRow(
                    label: l10n.onboardingTimeZone,
                    controller: _timeZoneCtrl,
                    hint: l10n.onboardingTimeZoneHint,
                  ),
                  _PickerRow(
                    key: const Key('spoken_languages_field'),
                    label: l10n.spokenLanguagesLabel,
                    value: languages,
                    placeholder: l10n.spokenLanguagesHint,
                    onTap: _pickLanguages,
                  ),
                ],
              ),
              _SectionLabel(l10n.editProfileUseApp),
              _Group(
                children: [
                  _Labeled(
                    label: l10n.editProfileRole,
                    child: _Segmented(
                      selected: _role,
                      options: [
                        ('seeker', l10n.editProfileRoleGetHelp),
                        ('helper', l10n.editProfileRoleGiveHelp),
                        ('both', l10n.editProfileRoleBoth),
                      ],
                      onChanged: (v) => setState(() => _role = v),
                    ),
                  ),
                  _TextRow(
                    label: l10n.editProfileInterests,
                    controller: _interestTagsCtrl,
                    hint: l10n.editProfileTopicsHelper,
                  ),
                ],
              ),
              if (_isHelperRole) ...[
                _SectionLabel(l10n.editProfileHelperProfile),
                _Group(
                  children: [
                    _Labeled(
                      label: l10n.onboardingExpertise,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in _allExpertise)
                            _TopicChip(
                              label: ValueLabels.topic(l10n, e),
                              selected: _selectedExpertise.contains(e),
                              onTap: () => setState(() {
                                _selectedExpertise.contains(e)
                                    ? _selectedExpertise.remove(e)
                                    : _selectedExpertise.add(e);
                              }),
                            ),
                        ],
                      ),
                    ),
                    _TextRow(
                      label: l10n.editProfileSkills,
                      controller: _skillsCtrl,
                      hint: l10n.editProfileCommaSeparated,
                    ),
                    _TextRow(
                      label: l10n.editProfileExperience,
                      controller: _experienceCtrl,
                      hint: l10n.editProfileExperienceHint,
                      minLines: 2,
                      maxLines: 5,
                    ),
                    _Labeled(
                      label: l10n.onboardingPreferredMode,
                      child: _Segmented(
                        selected: _mode,
                        options: [
                          ('chat', l10n.editProfileModeChat),
                          ('call', l10n.editProfileModeCall),
                          ('video', l10n.editProfileModeVideo),
                        ],
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                    ),
                    _Labeled(
                      label: l10n.onboardingAvailability,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (key, label) in [
                                ('allDay', l10n.availabilityAllDay),
                                ('mornings', l10n.availabilityMornings),
                                ('afternoons', l10n.availabilityAfternoons),
                                ('evenings', l10n.availabilityEvenings),
                              ])
                                _TopicChip(
                                  label: label,
                                  selected: _availabilityChoice == key,
                                  onTap: () => _choosePreset(key),
                                ),
                              _TopicChip(
                                label: l10n.availabilityCustom,
                                selected: _availabilityChoice == 'custom',
                                onTap: _pickAvailability,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  availability.isEmpty
                                      ? l10n.editProfileAvailabilityHint
                                      : availability,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: AppColors.muted,
);
const _valueStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: AppColors.text,
  height: 1.35,
);
const _placeholderStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: Color(0xFFA9A6A2),
  height: 1.35,
);

class _PhotoHeader extends StatelessWidget {
  final File? file;
  final String url;
  final String name;
  final String label;
  final VoidCallback onTap;
  const _PhotoHeader({
    required this.file,
    required this.url,
    required this.name,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 48.0;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                file != null
                    ? CircleAvatar(
                        radius: radius,
                        backgroundImage: FileImage(file!),
                      )
                    : InitialsAvatar(url: url, name: name, radius: radius),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.canvas, width: 3),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(backgroundColor: Colors.transparent),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      );
}

/// Rows in one rounded card with hairlines between them, like iOS settings.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 14,
                color: AppColors.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _labelStyle),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// A label above a borderless field; the whole row focuses the field.
class _TextRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  const _TextRow({
    required this.label,
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    const none = InputBorder.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          TextFormField(
            controller: controller,
            style: _valueStyle,
            minLines: minLines,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            validator: validator,
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _placeholderStyle,
              hintMaxLines: 2,
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.only(top: 6, bottom: 6),
              border: none,
              enabledBorder: none,
              focusedBorder: none,
              errorBorder: none,
              focusedErrorBorder: none,
              errorStyle: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label and its current value; tapping opens a picker.
class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onTap;
  const _PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _labelStyle),
                  const SizedBox(height: 6),
                  Text(
                    value.isEmpty ? placeholder : value,
                    style: value.isEmpty ? _placeholderStyle : _valueStyle,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// iOS-style segmented control: one choice out of a few.
class _Segmented extends StatelessWidget {
  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _Segmented({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (value == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: value == selected
                          ? AppColors.canvas
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: value == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: value == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: value == selected
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.canvas,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 15, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
