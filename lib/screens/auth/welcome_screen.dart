import 'dart:async';

import 'package:connect_app/l10n/app_localizations.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/language_picker.dart';
import 'package:flutter/material.dart';

/// First screen for someone who is not signed in: what Kindupp is, in one
/// look, then sign up or sign in. Same message as the website's home page.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Example {
  final String ask;
  final List<String> people;
  const _Example(this.ask, this.people);
}

List<_Example> _examples(AppLocalizations l) => [
      _Example(l.welcomeEx1Ask, [l.welcomeEx1A, l.welcomeEx1B, l.welcomeEx1C]),
      _Example(l.welcomeEx2Ask, [l.welcomeEx2A, l.welcomeEx2B, l.welcomeEx2C]),
      _Example(l.welcomeEx3Ask, [l.welcomeEx3A, l.welcomeEx3B, l.welcomeEx3C]),
    ];

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _exampleCount = 3;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  // Question, arrow, then each person, one after another.
  late final List<Animation<double>> _parts = [
    for (final (start, end) in const [
      (0.0, 0.3),
      (0.25, 0.45),
      (0.4, 0.65),
      (0.55, 0.8),
      (0.7, 0.95),
    ])
      CurvedAnimation(
        parent: _reveal,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
  ];
  Timer? _cycle;
  int _example = 0;

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_still) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    });
    _cycle = Timer.periodic(const Duration(seconds: 7), (_) => _next());
  }

  Future<void> _next() async {
    if (!mounted) return;
    if (!_still) {
      await _reveal.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeIn);
    }
    if (!mounted) return;
    setState(() => _example = (_example + 1) % _exampleCount);
    if (_still) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  Widget _part(int i, Widget child) {
    final a = _parts[i];
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ex = _examples(l10n)[_example];
    const label = TextStyle(
      color: AppColors.accentText,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    final card = Container(
      key: const Key('welcome_example'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _part(
            0,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.welcomeYouAsk.toUpperCase(), style: label),
                const SizedBox(height: 6),
                Text(
                  '“${ex.ask}”',
                  style: const TextStyle(
                    fontFamily: AppFonts.serif,
                    fontFamilyFallback: AppFonts.serifFallback,
                    fontSize: 18,
                    height: 1.35,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          _part(
            1,
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.south, size: 20, color: AppColors.primary),
            ),
          ),
          _part(1, Text(l10n.welcomeYouMeet.toUpperCase(), style: label)),
          const SizedBox(height: 8),
          for (var i = 0; i < ex.people.length; i++)
            _part(
              2 + i,
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.selected,
                      child: Icon(Icons.person_outline,
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          ex.people[i],
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final dots = Row(
      children: [
        for (var i = 0; i < _exampleCount; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 6),
            width: i == _example ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _example ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const Spacer(),
        Text(
          l10n.welcomeExampleNote,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 20),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text.rich(
                          const TextSpan(
                            text: 'kindupp',
                            children: [
                              TextSpan(
                                text: '.',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontFamilyFallback: AppFonts.serifFallback,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        const LanguageButton(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.welcomeEyebrow.toUpperCase(),
                      style: label,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.welcomeTitle,
                      style: const TextStyle(
                        fontFamily: AppFonts.serif,
                        fontFamilyFallback: AppFonts.serifFallback,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.welcomeLede,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    card,
                    const SizedBox(height: 12),
                    dots,
                    const Spacer(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('welcome_start'),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: Text(l10n.welcomeStart),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: const Key('welcome_sign_in'),
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: Text(l10n.welcomeHaveAccount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
