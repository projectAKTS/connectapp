import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connect_app/utils/time_utils.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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
  List<String> _journeys = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _mode = 'chat';

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final onboardingData = {
      // Required fields (from your rules)
      'activePerks': {},
      'badges': [],
      'bio': _bioCtrl.text.trim(),
      'categoryPosts': {},
      'Career': 0,
      'Finance': 0,
      'Health': 0,
      'Technology': 0,
      'Travel': 0,
      'commentBoost': null,
      'commentCount': 0,
      'country': _country ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'dailyLoginStreak': 0,
      'email': _emailCtrl.text.trim(),
      'followers': [],
      'following': [],
      'fullName': _nameCtrl.text.trim(),
      'helpfulMarks': 0,
      'interestTags': _selectedTopics.toList(),
      'journeys': _journeys,
      'lastLoginDate': null,
      'lastPostDate': null,
      'location': '',
      'mode': _mode,
      'name': _nameCtrl.text.trim(),
      'postCount': 0,
      'postingStreak': 0,
      'postsCount': 0,
      'premiumStatus': 'none',
      'priorityPostBoost': null,
      'profileHighlight': null,
      'profilePicture': '',
      'referralCount': 0,
      'role': _role,
      'skills': [],
      'streakDays': 0,
      'trialUsed': false,
      'xpPoints': 0,
      'helpfulVotesGiven': [],
      'premiumExpiresAt': null,
      'lastBoostDate': null,
      'availability': (_startTime != null && _endTime != null)
          ? '${_startTime!.format(context)}–${_endTime!.format(context)}'
          : '',
    };

    // Defensive: remove accidental nulls if any
    onboardingData.removeWhere((key, value) => value == null);

    print('DEBUG USER WRITE (onboarding): ${user.uid} DATA: $onboardingData');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(onboardingData, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up & Onboarding')),
      body: _loading
          ? _buildSkeleton()
          : Stepper(
              physics: const ClampingScrollPhysics(),
              currentStep: _currentStep,
              onStepContinue: _next,
              onStepCancel: _back,
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
                  title: const Text('Basic Info'),
                  isActive: _currentStep >= 0,
                  content: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        TextFormField(
                          controller: _passCtrl,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _country,
                          hint: const Text('Country of residence'),
                          items: ['Canada', 'USA', 'Other']
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _country = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _language,
                          hint: const Text('Language(s) spoken'),
                          items: ['English', 'French', 'Other']
                              .map((l) =>
                                  DropdownMenuItem(value: l, child: Text(l)))
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
                  title: const Text('Helper Profile Info'),
                  isActive: _currentStep >= 3,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _bioCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Short bio'),
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

  void _next() {
    if (_currentStep == 0) {
      if ((_formKey.currentState?.validate() ?? false)) {
        setState(() => _currentStep++);
      }
    } else if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      // Onboarding complete — write to Firestore
      _completeOnboarding().then((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
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
