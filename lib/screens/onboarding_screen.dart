// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connect_app/theme/tokens.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ---- flow ----
  final _pageCtrl = PageController();
  int _index = 0;

  // ---- form ----
  final _formKey = GlobalKey<FormState>();

  // Profile
  final _displayNameCtrl = TextEditingController();
  String? _profilePhotoUrl;

  // Country / Language (anchored dropdowns use controllers)
  final _countryCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  String? _country;
  String? _language;

  String _role = 'seeker'; // seeker | helper | both

  final List<String> _allTopics = const [
    'Immigration','Moving to Canada','PR Pathways','Quebec-specific help',
    'Job hunting','Refugee claim process','Student life','Parenting support','Language learning',
  ];
  final Set<String> _selectedTopics = {};

  final _bioCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  List<String> _journeys = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _mode = 'chat';
  bool _loading = true;

  // Booking parity (CTA + pills)
  static const _evergreen = Color(0xFF0F4C46);
  static const _evergreenPressed = Color(0xFF0C3D39);

  ButtonStyle _ctaStyle() => ButtonStyle(
        minimumSize: MaterialStateProperty.all(const Size.fromHeight(48)),
        backgroundColor: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.disabled)) return _evergreen.withOpacity(0.45);
          if (s.contains(MaterialState.pressed)) return _evergreenPressed;
          return _evergreen;
        }),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.06)),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        elevation: MaterialStateProperty.all(0),
      );

  // EXACT booking pill for Chat/Call/Video
  Widget _bookingPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected ? _evergreen.withOpacity(0.10) : AppColors.button;
    final border = selected ? _evergreen.withOpacity(0.45) : AppColors.border;
    final fg = selected ? _evergreen : AppColors.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: _evergreen.withOpacity(0.12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _displayNameCtrl.dispose();
    _countryCtrl.dispose();
    _languageCtrl.dispose();
    _bioCtrl.dispose();
    _skillsCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  // ---------- LOAD ----------
  Future<void> _loadOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!snap.exists) {
      setState(() => _loading = false);
      return;
    }

    final d = snap.data()!;
    setState(() {
      _displayNameCtrl.text = d['displayName'] ?? '';
      _profilePhotoUrl =
          (d['profilePicture']?.toString().isNotEmpty ?? false) ? d['profilePicture'] : null;

      _country  = (d['country']?.toString().isNotEmpty ?? false) ? d['country'] : null;
      _language = (d['language']?.toString().isNotEmpty ?? false) ? d['language'] : null;
      _countryCtrl.text = _country ?? '';
      _languageCtrl.text = _language ?? '';
      _role     = d['role'] ?? 'seeker';

      _selectedTopics
        ..clear()
        ..addAll((d['interestTags'] is List) ? List<String>.from(d['interestTags']) : const []);

      _bioCtrl.text = (d['bio'] == null || d['bio'] == 'No bio available yet.')
          ? '' : (d['bio'] ?? '');
      _skillsCtrl.text =
          (d['skills'] is List) ? (d['skills'] as List).join(', ') : (d['skills'] ?? '');
      _expCtrl.text = d['experience'] ?? '';

      _journeys = (d['journeys'] is List) ? List<String>.from(d['journeys']) : [];

      if (d['availability'] != null && d['availability'].toString().contains('–')) {
        final parts = d['availability'].toString().split('–');
        if (parts.length == 2) {
          _startTime = _parseTimeOfDay(parts[0].trim());
          _endTime   = _parseTimeOfDay(parts[1].trim());
        }
      }

      _mode = d['mode'] ?? 'chat';
      _loading = false;
    });
  }

  // ---------- SAVE / COMPLETE ----------
  Future<void> _savePartial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'displayName': _displayNameCtrl.text.trim(),
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': _skillsCtrl.text
          .trim()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'experience': _expCtrl.text.trim(),
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl?.isNotEmpty ?? false) ? _profilePhotoUrl : '',
      'onboardingComplete': false,
    }..removeWhere((k, v) => v == null);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t save right now: $e')),
      );
    }
  }

  Future<void> _complete({required bool skipped}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final data = {
      'displayName': _displayNameCtrl.text.trim(),
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': _skillsCtrl.text
          .trim()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'experience': _expCtrl.text.trim(),
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl?.isNotEmpty ?? false) ? _profilePhotoUrl : '',
      'onboardingComplete': !skipped,
    }..removeWhere((k, v) => v == null);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally. Sync later. ($e)')),
        );
      }
    }
  }

  // ---------- NAV ----------
  Future<void> _next() async {
    if (_index == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }

    await _savePartial();

    if (_index < 3) {
      setState(() => _index++);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _loading = true);
      await _complete(skipped: false);
      if (!mounted) return;
      // Always proceed to home; Firestore errors were handled with a snackbar.
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ---------- Photo picker ----------
  Future<void> _pickProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
      if (source == null) return;

      final XFile? xfile =
          await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 88);
      if (xfile == null) return;

      final file = File(xfile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final task = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await task.ref.getDownloadURL();

      setState(() => _profilePhotoUrl = url);
      await _savePartial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t upload photo: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // keyboard
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text('Onboarding'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await _complete(skipped: true);
                      if (!mounted) return;
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
      body: _loading
          ? _ExcludedSemanticsSkeleton()
          : SafeArea(
              child: Column(
                children: [
                  // Progress dots
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? _evergreen.withOpacity(.25) : AppColors.button,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? _evergreen.withOpacity(.5) : AppColors.border,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (i) => setState(() => _index = i),
                      children: [
                        _stepProfile(),
                        _stepRole(),
                        _stepInterests(),
                        _stepAbout(),
                      ],
                    ),
                  ),

                  // Bottom controls (same styling)
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + (bottomInset > 0 ? 8 : 0)),
                    child: Row(
                      children: [
                        if (_index > 0)
                          Expanded(
                            child: TextButton(
                              onPressed: _back,
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.button,
                                foregroundColor: AppColors.text,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_index > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: _ctaStyle(),
                            child: Text(_index < 3 ? 'Continue' : 'Finish'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- Steps (pages) ----------
  Widget _stepProfile() {
    // Stretch fields full-width of the content area.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Avatar with real picker
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.avatarBg,
                    foregroundColor: AppColors.avatarFg,
                    backgroundImage: (_profilePhotoUrl?.isNotEmpty ?? false)
                        ? NetworkImage(_profilePhotoUrl!)
                        : null,
                    child: (_profilePhotoUrl?.isEmpty ?? true)
                        ? const Icon(Icons.camera_alt, size: 30, color: AppColors.text)
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
                      child: const Icon(Icons.edit, size: 16, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: 'Display name',
                compact: true,
                child: TextFormField(
                  controller: _displayNameCtrl,
                  decoration: _compactInput(hint: 'Your name'),
                  style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Country (anchored dropdown) — full width
            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: 'Country of residence',
                compact: true,
                child: _anchoredDropdown(
                  controller: _countryCtrl,
                  value: _country,
                  hint: 'Select country',
                  options: const ['Canada','USA','Other'],
                  onChanged: (v) {
                    setState(() { _country = v; _countryCtrl.text = v ?? ''; });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Language (anchored dropdown) — full width
            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: 'Language(s) spoken',
                compact: true,
                child: _anchoredDropdown(
                  controller: _languageCtrl,
                  value: _language,
                  hint: 'Select language',
                  options: const ['English','French','Other'],
                  onChanged: (v) {
                    setState(() { _language = v; _languageCtrl.text = v ?? ''; });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRole() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How would you like to use the app?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // Keep tick + stable width
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _roleChip('seeker', Icons.help_outline, 'I’m here to get help'),
              _roleChip('helper', Icons.volunteer_activism_outlined, 'I’m here to give help'),
              _roleChip('both', Icons.all_inclusive, 'I’m open to both'),
            ],
          ),

          const SizedBox(height: 16),
          const Text('Preferred mode', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // Booking-style for chat/call/video
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _bookingPill(
                label: 'CHAT',
                selected: _mode == 'chat',
                onTap: () { HapticFeedback.selectionClick(); setState(() => _mode = 'chat'); },
              ),
              _bookingPill(
                label: 'CALL',
                selected: _mode == 'call',
                onTap: () { HapticFeedback.selectionClick(); setState(() => _mode = 'call'); },
              ),
              _bookingPill(
                label: 'VIDEO',
                selected: _mode == 'video',
                onTap: () { HapticFeedback.selectionClick(); setState(() => _mode = 'video'); },
              ),
            ],
          ),

          const SizedBox(height: 16),
          _SoftCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, color: AppColors.text),
              title: const Text('Availability'),
              subtitle: Text(
                _startTime == null || _endTime == null
                    ? 'Not set'
                    : '${_startTime!.format(context)} – ${_endTime!.format(context)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final st = await showTimePicker(
                  context: context,
                  initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                );
                if (st == null) return;
                final en = await showTimePicker(
                  context: context,
                  initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
                );
                if (en == null) return;
                setState(() { _startTime = st; _endTime = en; });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInterests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pick a few topics', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allTopics.map((t) {
              final selected = _selectedTopics.contains(t);
              return ChoiceChip(
                avatar: Icon(Icons.check,
                    size: 18,
                    color: selected ? AppColors.text : Colors.transparent), // tick kept
                label: Text(t),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selected ? _selectedTopics.remove(t) : _selectedTopics.add(t);
                  });
                },
                selectedColor: AppColors.button,
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.text : AppColors.text.withOpacity(0.9),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          const Text('Journeys you’ve been through', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8, runSpacing: 8,
            children: ['Refugee claim approved','Student','Worker'].map((j) {
              final sel = _journeys.contains(j);
              return FilterChip(
                avatar: Icon(Icons.check,
                    size: 18,
                    color: sel ? AppColors.text : Colors.transparent),
                label: Text(j),
                selected: sel,
                showCheckmark: false,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() { sel ? _journeys.remove(j) : _journeys.add(j); });
                },
                selectedColor: AppColors.button,
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _stepAbout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Short bio: hint-only, no floating label, clipped safely
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: TextFormField(
              controller: _bioCtrl,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              cursorColor: AppColors.primary,
              decoration: _textAreaDecoration(hint: 'Short bio'),
              minLines: 3,
              maxLines: 5,
            ),
          ),
          const SizedBox(height: 12),

          _SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('If you plan to help others',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: TextFormField(
                    controller: _skillsCtrl,
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                    cursorColor: AppColors.primary,
                    decoration: _compactInput(hint: 'Skills (comma separated)'),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: TextFormField(
                    controller: _expCtrl,
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                    cursorColor: AppColors.primary,
                    decoration: _textAreaDecoration(hint: 'Relevant experience'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- helpers ----------
  // Anchored M3 dropdown (opens directly below its field, and now stretches full width)
  Widget _anchoredDropdown({
    required TextEditingController controller,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? value,
    String? hint,
  }) {
    return DropdownMenu<String>(
      controller: controller,
      initialSelection: value,
      hintText: hint,
      dropdownMenuEntries: options
          .map((e) => DropdownMenuEntry<String>(value: e, label: e))
          .toList(),
      width: double.infinity,       // <- match field width exactly
      menuHeight: 240,
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.button,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
      onSelected: onChanged,
    );
  }

  InputDecoration _compactInput({String? label, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.button,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
      );

  InputDecoration _textAreaDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      );

  Widget _roleChip(String value, IconData icon, String label) {
    final sel = _role == value;
    return ChoiceChip(
      avatar: Icon(Icons.check,
          size: 18,
          color: sel ? AppColors.text : Colors.transparent), // tick kept + stable width
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: sel,
      showCheckmark: false,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _role = value);
      },
      selectedColor: AppColors.button,
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
    );
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
    } catch (_) { return null; }
  }
}

// === Skeleton with semantics excluded (safety) ===
class _ExcludedSemanticsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== shared bits =====
class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        boxShadow: const [AppShadows.soft],
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool compact;
  const _LabeledField({required this.label, required this.child, this.compact = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              fontSize: compact ? 13 : 14,
              height: 1.15,
            )),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
