import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

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
  final List<String> _allTopics = [
    'Immigration',
    'Moving to Canada',
    'PR Pathways',
    'Quebec-specific help',
    'Job hunting',
    'Refugee claim process',
    'Student life',
    'Parenting support',
    'Language learning'
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
  String? _profilePhotoUrl; // For optional profile pic

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

  // 1. LOAD PREVIOUS DATA IF EXISTS
  Future<void> _loadOnboardingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (snap.exists) {
      final d = snap.data()!;
      final bool isNewUser = !(d.containsKey('country') || d.containsKey('language'));
      setState(() {
        _country = d['country']?.isNotEmpty == true ? d['country'] : null;
        _language = d['language']?.isNotEmpty == true ? d['language'] : null;
        _role = d['role'] ?? 'seeker';
        _selectedTopics.clear();
        if (d['interestTags'] is List) {
          _selectedTopics.addAll(List<String>.from(d['interestTags']));
        }
        _bioCtrl.text = (d['bio'] == null || d['bio'] == 'No bio available yet.') ? '' : d['bio'];
        _skillsCtrl.text = (d['skills'] is List)
            ? (d['skills'] as List).join(', ')
            : (d['skills'] ?? '');
        _expCtrl.text = d['experience'] ?? '';
        _journeys = d['journeys'] is List
            ? List<String>.from(d['journeys'])
            : [];
        if (d['availability'] != null && d['availability'].contains('–')) {
          final parts = d['availability'].split('–');
          if (parts.length == 2) {
            _startTime = _parseTimeOfDay(parts[0].trim());
            _endTime = _parseTimeOfDay(parts[1].trim());
          }
        }
        _mode = d['mode'] ?? 'chat';
        _profilePhotoUrl = d['profilePicture']?.isNotEmpty == true ? d['profilePicture'] : null;

        if (isNewUser) {
          _currentStep = 0; // Always start at first step for new users
        } else {
          // Resume at first incomplete step for returning users
          _currentStep = 0;
          if (_country != null && _language != null) _currentStep = 1;
          if (_role.isNotEmpty) _currentStep = 2;
          if (_selectedTopics.isNotEmpty || _bioCtrl.text.isNotEmpty) _currentStep = 3;
        }
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  // 2. SAVE STEP DATA ON CONTINUE
  Future<void> _saveStepData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final onboardingData = {
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': (_role == 'helper' || _role == 'both')
          ? _skillsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : [],
      'experience': (_role == 'helper' || _role == 'both')
          ? _expCtrl.text.trim()
          : '',
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
          ? _profilePhotoUrl
          : '',
      'onboardingComplete': false,
    };
    onboardingData.removeWhere((k, v) => v == null);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(onboardingData, SetOptions(merge: true));
  }

  // 3. COMPLETE ONBOARDING OR SKIP
  Future<void> _completeOnboarding({bool onboardingSkipped = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final onboardingData = {
      'country': _country ?? '',
      'language': _language ?? '',
      'role': _role,
      'interestTags': _selectedTopics.toList(),
      'bio': _bioCtrl.text.trim(),
      'skills': (_role == 'helper' || _role == 'both')
          ? _skillsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : [],
      'experience': (_role == 'helper' || _role == 'both')
          ? _expCtrl.text.trim()
          : '',
      'journeys': _journeys,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
      'mode': _mode,
      'profilePicture': (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
          ? _profilePhotoUrl
          : '',
      'onboardingComplete': !onboardingSkipped,
    };
    onboardingData.removeWhere((k, v) => v == null);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(onboardingData, SetOptions(merge: true));
  }

  // 4. BUILD UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          : Stepper(
              physics: const ClampingScrollPhysics(),
              currentStep: _currentStep,
              onStepContinue: _next,
              onStepCancel: _back,
              // Allow users to tap any step to jump to it!
              onStepTapped: (step) => setState(() => _currentStep = step),
              controlsBuilder: (ctx, details) {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: const Text('Continue'),
                    ),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ],
                );
              },
              steps: [
                Step(
                  title: const Text('Your Profile'),
                  isActive: _currentStep >= 0,
                  content: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            // TODO: Implement photo picker
                          },
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                                ? NetworkImage(_profilePhotoUrl!)
                                : null,
                            child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                                ? const Icon(Icons.camera_alt, size: 40)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _country,
                          hint: const Text('Country of residence'),
                          items: ['Canada', 'USA', 'Other']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _country = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _language,
                          hint: const Text('Language(s) spoken'),
                          items: ['English', 'French', 'Other']
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (v) => setState(() => _language = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Role Selection'),
                  isActive: _currentStep >= 1,
                  content: Column(
                    children: [
                      _buildChoice('I’m here to get help', 'seeker'),
                      _buildChoice('I’m here to give help', 'helper'),
                      _buildChoice('I’m open to both', 'both'),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Interests / Topics'),
                  isActive: _currentStep >= 2,
                  content: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _allTopics.map((t) {
                      final selected = _selectedTopics.contains(t);
                      return ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selected
                                ? _selectedTopics.remove(t)
                                : _selectedTopics.add(t);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                Step(
                  title: const Text('About You'),
                  isActive: _currentStep >= 3,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _bioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Short bio',
                          hintText: 'Describe yourself briefly (optional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      const Text('Journeys you’ve been through'),
                      Wrap(
                        spacing: 8,
                        children: ['Refugee claim approved', 'Student', 'Worker']
                            .map((j) {
                          final sel = _journeys.contains(j);
                          return FilterChip(
                            label: Text(j),
                            selected: sel,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                sel
                                    ? _journeys.remove(j)
                                    : _journeys.add(j);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: const Text('Availability'),
                        subtitle: Text(
                          _startTime == null || _endTime == null
                              ? 'Not set'
                              : '${_startTime!.format(context)} – ${_endTime!.format(context)}',
                        ),
                        trailing: const Icon(Icons.access_time),
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
                      const SizedBox(height: 12),
                      const Text('Preferred help mode'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['chat', 'call', 'video'].map((m) {
                          return ChoiceChip(
                            label: Text(m.toUpperCase()),
                            selected: _mode == m,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _mode = m);
                            },
                          );
                        }).toList(),
                      ),
                      if (_role == 'helper' || _role == 'both') ...[
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _skillsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Skills (comma separated, e.g. "law, taxes, ESL")',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _expCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Relevant experience (help users trust your advice)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChoice(String label, String value) {
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _role = value);
      },
      leading: Radio<String>(
        value: value,
        groupValue: _role,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          setState(() => _role = v!);
        },
      ),
      title: Text(label),
    );
  }

  void _next() async {
    if (_currentStep == 0) {
      if ((_formKey.currentState?.validate() ?? false)) {
        await _saveStepData();
        setState(() => _currentStep++);
      }
    } else if (_currentStep < 3) {
      await _saveStepData();
      setState(() => _currentStep++);
    } else {
      setState(() => _loading = true);
      await _completeOnboarding(onboardingSkipped: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // Parse "09:00 AM" -> TimeOfDay
  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      final now = TimeOfDay.now();
      if (time.contains(':')) {
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        if (time.toLowerCase().contains('pm') && hour < 12) hour += 12;
        if (time.toLowerCase().contains('am') && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
      return now;
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
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
