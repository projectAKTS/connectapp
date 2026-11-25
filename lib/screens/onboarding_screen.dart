// lib/screens/onboarding_screen.dart
import 'package:connect_app/models/age_policy.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/models/profile_languages.dart';
import 'package:connect_app/utils/availability_time.dart';
import 'package:connect_app/widgets/spoken_languages_field.dart';
import 'package:connect_app/models/help_topics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connect_app/screens/settings/settings_screen.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
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
  final _cityCtrl = TextEditingController();
  final _timeZoneCtrl = TextEditingController();
  String? _profilePhotoUrl;

  String? _country;

  /// Languages the person speaks (ISO codes); not the app language.
  List<String> _spoken = [];

  /// 18+ self-declaration (AgePolicy); required to finish onboarding.
  bool _ageConfirmed = false;

  String _role = 'seeker'; // seeker | helper | both

  final List<String> _allTopics = HelpTopics.topics;
  final Set<String> _selectedTopics = {};
  final List<String> _allExpertise = HelpTopics.expertise;
  final Set<String> _selectedExpertise = {};

  bool _loading = true;
  bool get _needsHelperSetup => _role == 'helper' || _role == 'both';

  // Booking parity (CTA + pills)
  static const _evergreen = AppColors.primary;
  static const _evergreenPressed = Color(0xFF0C3D39);

  ButtonStyle _ctaStyle() => ButtonStyle(
        minimumSize: MaterialStateProperty.all(const Size.fromHeight(48)),
        backgroundColor: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.disabled))
            return _evergreen.withOpacity(0.45);
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

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _displayNameCtrl.dispose();
    _cityCtrl.dispose();
    _timeZoneCtrl.dispose();
    super.dispose();
  }

  // ---------- LOAD ----------
  Future<void> _loadOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    // Sign-up already asked for the name: start from it.
    final signUpName = (user.displayName ?? '').trim();
    _timeZoneCtrl.text = AvailabilityTime.deviceTimeZone();
    if (!snap.exists) {
      setState(() {
        _displayNameCtrl.text = signUpName;
        _loading = false;
      });
      return;
    }

    final d = snap.data()!;
    setState(() {
      final storedName = '${d['displayName'] ?? d['fullName'] ?? ''}'.trim();
      _displayNameCtrl.text = storedName.isNotEmpty ? storedName : signUpName;
      _profilePhotoUrl = (d['profilePicture']?.toString().isNotEmpty ?? false)
          ? d['profilePicture']
          : null;

      _cityCtrl.text = d['city'] ?? '';
      // Suggest the device's offset; the field stays editable.
      final storedZone = '${d['timeZone'] ?? ''}'.trim();
      _timeZoneCtrl.text = storedZone.isNotEmpty
          ? storedZone
          : AvailabilityTime.deviceTimeZone();

      _country =
          (d['country']?.toString().isNotEmpty ?? false) ? d['country'] : null;
      _spoken = ProfileLanguages.read(d);
      _ageConfirmed = AgePolicy.statusOf(d) == AgeStatus.adult;
      _role = d['role'] ?? 'seeker';

      _selectedTopics
        ..clear()
        ..addAll((d['interestTags'] is List)
            ? List<String>.from(d['interestTags'])
            : const []);

      _selectedExpertise
        ..clear()
        ..addAll((d['expertiseTags'] is List)
            ? List<String>.from(d['expertiseTags'])
            : const []);

      _loading = false;
    });
  }

  // ---------- SAVE / COMPLETE ----------
  Map<String, dynamic> _buildOnboardingPayload({required bool completed}) {
    final displayName = _displayNameCtrl.text.trim();
    return {
      'displayName': displayName,
      'displayName_lc': displayName.toLowerCase(),
      'fullName': displayName,
      'fullNameLower': displayName.toLowerCase(),
      'city': _cityCtrl.text.trim(),
      'timeZone': _timeZoneCtrl.text.trim(),
      'country': _country ?? '',
      ...ProfileLanguages.fields(_spoken),
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'expertiseTags': _selectedExpertise.toList(),
      'profilePicture':
          (_profilePhotoUrl?.isNotEmpty ?? false) ? _profilePhotoUrl : '',
      'onboardingComplete': completed,
    };
  }

  Future<void> _savePartial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final displayName = _displayNameCtrl.text.trim();
    final data = _buildOnboardingPayload(completed: false)
      ..removeWhere((k, v) => v == null);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      if (displayName.isNotEmpty && user.displayName != displayName) {
        await user.updateDisplayName(displayName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonSaveFailed)),
      );
    }
  }

  Future<void> _complete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final displayName = _displayNameCtrl.text.trim();
    final data = _buildOnboardingPayload(completed: true)
      ..removeWhere((k, v) => v == null)
      ..addAll(AgePolicy.declaration(adult: true));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      if (displayName.isNotEmpty && user.displayName != displayName) {
        await user.updateDisplayName(displayName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonSavedLocally)),
        );
      }
    }
  }

  // ---------- NAV ----------
  int get _totalSteps => _needsHelperSetup ? 3 : 2;
  int get _lastStepIndex => _totalSteps - 1;

  Future<void> _next() async {
    if (_index == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_spoken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.spokenLanguagesRequired)),
        );
        return;
      }
      if (!_ageConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ageRequired)),
        );
        return;
      }
    }
    if (_index == 1 && _selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.onboardingPickOneTopic)),
      );
      return;
    }

    await _savePartial();

    if (_index < _lastStepIndex) {
      setState(() => _index++);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _loading = true);
      await _complete();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _setRole(String value) {
    if (_role == value) return;
    setState(() => _role = value);
    final last = _lastStepIndex;
    if (_index > last) {
      setState(() => _index = last);
      _pageCtrl.jumpToPage(last);
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
                title: Text(context.l10n.commonTakePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.l10n.commonChooseFromLibrary),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
      if (source == null) return;

      final XFile? xfile = await picker.pickImage(
          source: source, maxWidth: 1024, imageQuality: 88);
      if (xfile == null) return;

      final file = File(xfile.path);
      final ref = FirebaseStorage.instance.ref().child(
          'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final task =
          await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await task.ref.getDownloadURL();

      setState(() => _profilePhotoUrl = url);
      await _savePartial();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonPhotoUploadFailed)),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // keyboard
    final pages = <Widget>[
      _stepProfile(),
      _stepInterests(),
      if (_needsHelperSetup) _stepRole(),
    ];
    return FullScreenBackGesture(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(context.l10n.onboardingTitle),
          actions: [
            // A way out for someone who signed up by mistake.
            TextButton(
              onPressed: () => SettingsScreen.signOut(context),
              style: TextButton.styleFrom(backgroundColor: Colors.transparent),
              child: Text(context.l10n.settingsLogOut),
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
                        children: List.generate(_totalSteps, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            width: active ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? _evergreen.withOpacity(.25)
                                  : AppColors.button,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active
                                    ? _evergreen.withOpacity(.5)
                                    : AppColors.border,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    Expanded(
                      child: PageView(
                        controller: _pageCtrl,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (i) => setState(() => _index = i),
                        children: pages,
                      ),
                    ),

                    // Bottom controls (same styling)
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, 16 + (bottomInset > 0 ? 8 : 0)),
                      child: Row(
                        children: [
                          if (_index > 0)
                            Expanded(
                              child: TextButton(
                                onPressed: _back,
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.button,
                                  foregroundColor: AppColors.text,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: AppColors.border),
                                  ),
                                ),
                                child: Text(context.l10n.commonBack),
                              ),
                            ),
                          if (_index > 0) const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _next,
                              style: _ctaStyle(),
                              child: Text(_index < _lastStepIndex
                                  ? context.l10n.commonContinue
                                  : context.l10n.commonFinish),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              title: context.l10n.onboardingProfileTitle,
              subtitle: context.l10n.onboardingProfileSubtitle,
            ),
            const SizedBox(height: 12),
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
                        ? const Icon(Icons.camera_alt,
                            size: 30, color: AppColors.text)
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
                      child: const Icon(Icons.edit,
                          size: 16, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: context.l10n.onboardingDisplayName,
                compact: true,
                child: TextFormField(
                  controller: _displayNameCtrl,
                  decoration: _compactInput(
                      hint: context.l10n.onboardingYourName,
                      fill: AppColors.card),
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.l10n.commonRequired
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: context.l10n.onboardingCity,
                compact: true,
                child: TextFormField(
                  controller: _cityCtrl,
                  decoration: _compactInput(
                      hint: context.l10n.onboardingCityHint,
                      fill: AppColors.card),
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Time zone comes from the device; no field to fill.
            // Three countries: one tap instead of a dropdown.
            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: context.l10n.onboardingCountry,
                compact: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in const ['Canada', 'USA', 'Other'])
                      ChoiceChip(
                        label: Text(ValueLabels.country(context.l10n, c)),
                        selected: _country == c,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _country = c);
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Spoken languages — full width
            Align(
              alignment: Alignment.centerLeft,
              child: _LabeledField(
                label: context.l10n.spokenLanguagesLabel,
                compact: true,
                child: SpokenLanguagesField(
                  codes: _spoken,
                  fill: AppColors.card,
                  onChanged: (codes) => setState(() => _spoken = codes),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile.adaptive(
              key: const Key('onboarding_age_18'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              value: _ageConfirmed,
              title: Text(context.l10n.ageCheckbox,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(context.l10n.ageRequired),
              onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
            ),
            const SizedBox(height: 16),
            _sectionLabel(context.l10n.onboardingHowUse),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _roleChip(
                    'seeker', Icons.help_outline, context.l10n.roleSeeker),
                _roleChip('helper', Icons.volunteer_activism_outlined,
                    context.l10n.roleHelper),
                _roleChip('both', Icons.all_inclusive, context.l10n.roleBoth),
              ],
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
          _stepHeader(
            title: context.l10n.onboardingHelperTitle,
            subtitle: context.l10n.onboardingHelperSubtitle,
          ),
          const SizedBox(height: 12),
          _sectionLabel(context.l10n.onboardingExpertise),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allExpertise.map((e) {
              final selected = _selectedExpertise.contains(e);
              return ChoiceChip(
                label: Text(ValueLabels.topic(context.l10n, e)),
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selected
                        ? _selectedExpertise.remove(e)
                        : _selectedExpertise.add(e);
                  });
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
          // Contact mode and availability were stored but used nowhere;
          // helpers can still be messaged or called.
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
          _stepHeader(
            title: context.l10n.onboardingTopicsTitle,
            subtitle: context.l10n.onboardingTopicsSubtitle,
          ),
          const SizedBox(height: 12),
          _sectionLabel(context.l10n.onboardingPickTopics),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTopics.map((t) {
              final selected = _selectedTopics.contains(t);
              return ChoiceChip(
                label: Text(ValueLabels.topic(context.l10n, t)),
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selected
                        ? _selectedTopics.remove(t)
                        : _selectedTopics.add(t);
                  });
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------- helpers ----------
  InputDecoration _compactInput({String? label, String? hint, Color? fill}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: fill ?? AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        labelStyle: const TextStyle(
            color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _roleChip(String value, IconData icon, String label) {
    final sel = _role == value;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 18, color: sel ? AppColors.primary : AppColors.muted),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: sel,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        _setRole(value);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
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
class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool compact;
  const _LabeledField(
      {required this.label, required this.child, this.compact = false});
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

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: textTheme.bodyMedium),
      ],
    );
  }
}

Widget _stepHeader({required String title, required String subtitle}) =>
    _StepHeader(title: title, subtitle: subtitle);

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        fontSize: 14,
      ),
    );
