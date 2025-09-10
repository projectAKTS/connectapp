// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connect_app/theme/tokens.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  String? _country;
  String? _language;
  String _role = 'seeker'; // seeker | helper | both
  final List<String> _allTopics = const [
    'Immigration',
    'Moving to Canada',
    'PR Pathways',
    'Quebec-specific help',
    'Job hunting',
    'Refugee claim process',
    'Student life',
    'Parenting support',
    'Language learning',
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
  String? _profilePhotoUrl; // optional

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _skillsCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  // ---------- LOAD PREVIOUS DATA ----------
  Future<void> _loadOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!snap.exists) {
      setState(() => _loading = false);
      return;
    }

    final d = snap.data()!;
    final bool isNewUser = !(d.containsKey('country') || d.containsKey('language'));

    setState(() {
      _country  = (d['country']?.toString().isNotEmpty ?? false) ? d['country'] : null;
      _language = (d['language']?.toString().isNotEmpty ?? false) ? d['language'] : null;
      _role     = d['role'] ?? 'seeker';

      _selectedTopics
        ..clear()
        ..addAll((d['interestTags'] is List) ? List<String>.from(d['interestTags']) : const []);

      _bioCtrl.text = (d['bio'] == null || d['bio'] == 'No bio available yet.') ? '' : (d['bio'] ?? '');
      _skillsCtrl.text = (d['skills'] is List)
          ? (d['skills'] as List).join(', ')
          : (d['skills'] ?? '');
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
      _profilePhotoUrl = (d['profilePicture']?.toString().isNotEmpty ?? false)
          ? d['profilePicture']
          : null;

      _currentStep = 0;
      if (!isNewUser) {
        if (_country != null && _language != null) _currentStep = 1;
        if (_role.isNotEmpty) _currentStep = 2;
        if (_selectedTopics.isNotEmpty || _bioCtrl.text.isNotEmpty) _currentStep = 3;
      }

      _loading = false;
    });
  }

  // ---------- SAVE PER STEP ----------
  Future<void> _saveStepData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': (_role == 'helper' || _role == 'both')
          ? _skillsCtrl.text
              .trim()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [],
      'experience': (_role == 'helper' || _role == 'both') ? _expCtrl.text.trim() : '',
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl?.isNotEmpty ?? false) ? _profilePhotoUrl : '',
      'onboardingComplete': false,
    }..removeWhere((k, v) => v == null);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  // ---------- COMPLETE ----------
  Future<void> _completeOnboarding({bool onboardingSkipped = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': (_role == 'helper' || _role == 'both')
          ? _skillsCtrl.text
              .trim()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [],
      'experience': (_role == 'helper' || _role == 'both') ? _expCtrl.text.trim() : '',
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl?.isNotEmpty ?? false) ? _profilePhotoUrl : '',
      'onboardingComplete': !onboardingSkipped,
    }..removeWhere((k, v) => v == null);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text('Onboarding'),
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await _completeOnboarding(onboardingSkipped: true);
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: _loading
          ? _buildSkeleton()
          : Theme(
              // Slightly tune Stepper colors to your palette
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  surface: AppColors.card,
                  onSurface: AppColors.text,
                ),
              ),
              child: Stepper(
                type: StepperType.vertical,
                physics: const ClampingScrollPhysics(),
                currentStep: _currentStep,
                onStepContinue: _next,
                onStepCancel: _back,
                onStepTapped: (i) => setState(() => _currentStep = i),
                controlsBuilder: (ctx, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(_currentStep < 3 ? 'Continue' : 'Finish'),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: details.onStepCancel,
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.button,
                              foregroundColor: AppColors.text,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Back'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Your profile'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    content: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: () {
                              // TODO: implement photo picker
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo picker coming soon')),
                              );
                            },
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

                          // Country
                          _LabeledField(
                            label: 'Country of residence',
                            child: DropdownButtonFormField<String>(
                              value: _country,
                              items: const ['Canada', 'USA', 'Other']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _country = v),
                              validator: (v) => v == null ? 'Required' : null,
                              decoration: _input(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Language
                          _LabeledField(
                            label: 'Language(s) spoken',
                            child: DropdownButtonFormField<String>(
                              value: _language,
                              items: const ['English', 'French', 'Other']
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                  .toList(),
                              onChanged: (v) => setState(() => _language = v),
                              validator: (v) => v == null ? 'Required' : null,
                              decoration: _input(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Step(
                    title: const Text('Role & availability'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How would you like to use the app?',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _roleChip('seeker', Icons.help_outline, 'I’m here to get help'),
                            _roleChip('helper', Icons.volunteer_activism_outlined, 'I’m here to give help'),
                            _roleChip('both', Icons.all_inclusive, 'I’m open to both'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Preferred mode', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['chat', 'call', 'video'].map((m) {
                            final sel = _mode == m;
                            return ChoiceChip(
                              label: Text(m.toUpperCase()),
                              selected: sel,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _mode = m);
                              },
                              selectedColor: AppColors.button,
                              backgroundColor: AppColors.card,
                              side: const BorderSide(color: AppColors.border),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: sel ? AppColors.text : AppColors.text.withOpacity(0.85),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            );
                          }).toList(),
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
                              setState(() {
                                _startTime = st;
                                _endTime = en;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  Step(
                    title: const Text('Interests & journeys'),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pick a few topics',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allTopics.map((t) {
                            final selected = _selectedTopics.contains(t);
                            return ChoiceChip(
                              label: Text(t),
                              selected: selected,
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
                        const Text('Journeys you’ve been through',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Refugee claim approved', 'Student', 'Worker'].map((j) {
                            final sel = _journeys.contains(j);
                            return FilterChip(
                              label: Text(j),
                              selected: sel,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  sel ? _journeys.remove(j) : _journeys.add(j);
                                });
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
                  ),

                  Step(
                    title: const Text('About you'),
                    isActive: _currentStep >= 3,
                    state: _currentStep == 3 ? StepState.indexed : StepState.complete,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _bioCtrl,
                          decoration: _input(label: 'Short bio', hint: 'Describe yourself briefly (optional)'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),

                        if (_role == 'helper' || _role == 'both') ...[
                          _SoftCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('If you plan to help others',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _skillsCtrl,
                                  decoration: _input(
                                    label: 'Skills (comma separated)',
                                    hint: 'e.g. law, taxes, ESL',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _expCtrl,
                                  decoration: _input(
                                    label: 'Relevant experience',
                                    hint: 'Help users trust your advice',
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- helpers ----------
  InputDecoration _input({String? label, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.button,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      );

  Widget _roleChip(String value, IconData icon, String label) {
    final sel = _role == value;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: sel ? AppColors.text : AppColors.muted),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: sel,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _role = value);
      },
      selectedColor: AppColors.button,
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: sel ? AppColors.text : AppColors.text.withOpacity(0.9),
      ),
    );
  }

  void _next() async {
    if (_currentStep == 0) {
      if ((_formKey.currentState?.validate() ?? false)) {
        await _saveStepData();
        setState(() => _currentStep++);
      }
      return;
    }

    if (_currentStep < 3) {
      await _saveStepData();
      setState(() => _currentStep++);
      return;
    }

    // finish
    setState(() => _loading = true);
    await _completeOnboarding(onboardingSkipped: false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // Parse "09:00 AM" -> TimeOfDay
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

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
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
    );
  }
}

// ===== small shared bits =====

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
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            )),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
