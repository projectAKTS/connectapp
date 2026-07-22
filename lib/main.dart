import 'dart:async';
import 'package:flutter/material.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';

// Payments
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/posts/edit_post_screen.dart';
import 'screens/posts/post_detail_screen.dart';
import 'screens/consultation/consultation_booking_screen.dart';
import 'screens/consultation/my_consultation_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/payment/payment_setup_screen.dart';
import 'screens/premium/premium_screen.dart';

// Core
import 'widgets/main_scaffold.dart';
import 'widgets/full_screen_back_gesture.dart';
import 'services/firebase_options.dart';
import 'services/firestore_read_helper.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'theme/theme.dart';
import 'call_v2/integration/call_v2_app_integration.dart';
import 'call_v2/integration/call_v2_disabled_runtime_preflight_boundary.dart';
import 'call_v2/integration/call_v2_disabled_startup_execution_boundary.dart';
import 'call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';
import 'call_v2/integration/call_v2_route_registry.dart';
import 'call_v2/integration/call_v2_rollout_policy.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final NotificationService notificationService;

class _RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint(
      '[Route] push: ${route.settings.name ?? route.runtimeType} <- ${previousRoute?.settings.name ?? previousRoute?.runtimeType}',
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint(
      '[Route] pop: ${route.settings.name ?? route.runtimeType} -> ${previousRoute?.settings.name ?? previousRoute?.runtimeType}',
    );
    super.didPop(route, previousRoute);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  unawaited(
    FirestoreReadHelper.ensureNetworkEnabled(reason: 'app_start'),
  );

  const useDebugAppCheck =
      bool.fromEnvironment('APP_CHECK_DEBUG', defaultValue: false);
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: useDebugAppCheck
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
      androidProvider: useDebugAppCheck
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
    if (useDebugAppCheck) {
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token != null && token.isNotEmpty) {
        debugPrint('🧪 AppCheck debug token: $token');
      }
    } else if (kDebugMode) {
      debugPrint(
        'ℹ️ AppCheck running with real attestation in debug build. '
        'Set --dart-define=APP_CHECK_DEBUG=true only when you intentionally use debug tokens.',
      );
    }
  } catch (e) {
    debugPrint('⚠️ AppCheck failed: $e');
    if (useDebugAppCheck &&
        e.toString().contains('exchangeDebugToken') &&
        e.toString().contains('403')) {
      debugPrint(
        '⚠️ AppCheck debug token was rejected by Firebase (403 PERMISSION_DENIED). '
        'Add this device debug token in Firebase Console -> App Check -> '
        'Manage debug tokens, then reinstall and run again.',
      );
    }
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  notificationService = NotificationService(navigatorKey: navigatorKey);
  unawaited(initializeCallV2AppIntegrationShellSafely());
  initializeCallV2FirstActualAppWiringTouchpointSafely();
  executeCallV2DisabledStartupBoundarySafely();
  executeCallV2DisabledRuntimePreflightBoundarySafely();

  runApp(const MyApp());
}

void _handlePurchaseUpdates(List<PurchaseDetails> details) {
  for (final pd in details) {
    if (pd.status == PurchaseStatus.purchased ||
        pd.status == PurchaseStatus.restored) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) continue;

      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (pd.productID == 'premium_monthly' ||
          pd.productID == 'premium_yearly') {
        final isMonthly = pd.productID == 'premium_monthly';
        final expires = DateTime.now().add(
          isMonthly ? const Duration(days: 30) : const Duration(days: 365),
        );

        doc.set({
          'premiumStatus': isMonthly ? 'Monthly' : 'Yearly',
          'premiumExpiresAt': Timestamp.fromDate(expires),
        }, SetOptions(merge: true));
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _foregroundBootstrapDone = false;
  bool _foregroundBootstrapRunning = false;
  bool _dynamicLinksInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ensureForegroundBootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _ensureForegroundBootstrap() async {
    if (_foregroundBootstrapDone || _foregroundBootstrapRunning) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    _foregroundBootstrapRunning = true;
    try {
      Stripe.publishableKey =
          'pk_live_51Kke4CFsXOZFrRZs9EBuzMeKRdmsrWdHEqx7oEBzbZm3kygcvNboaQkuTu2EXZQ87DDVmTvN4cu2QKkrw8hKxlMr00NHQfAdAp';
      Stripe.merchantIdentifier = 'merchant.com.connectapp';
      Stripe.urlScheme = 'connectapp';
      await Stripe.instance.applySettings();

      final available = await SubscriptionService.init();
      if (available) {
        SubscriptionService.setupListener(_handlePurchaseUpdates);
      }

      if (!_dynamicLinksInitialized) {
        _dynamicLinksInitialized = true;
        await _initDynamicLinks();
      }

      _foregroundBootstrapDone = true;
    } catch (e, st) {
      debugPrint('Foreground bootstrap failed: $e\n$st');
    } finally {
      _foregroundBootstrapRunning = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_ensureForegroundBootstrap());
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_ensureForegroundBootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(
      FirestoreReadHelper.ensureNetworkEnabled(reason: 'app_resumed'),
    );
    unawaited(_ensureForegroundBootstrap());
  }

  Future<void> _initDynamicLinks() async {
    FirebaseDynamicLinks.instance.onLink.listen((data) {
      final uri = data.link;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      if (uri.path == '/success') {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('✅ Payment successful')),
        );
      } else if (uri.path == '/cancel') {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('❌ Payment cancelled')),
        );
      }
    }).onError((e) {
      debugPrint('Dynamic link error: $e');
    });

    final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      final uri = initialLink.link;
      if (uri.path == '/success') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('✅ Payment successful')),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [_RouteLogger()],
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),

      // Start from AuthGate
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),

        // ✅ IMPORTANT: define /home explicitly
        '/home': (_) => const MainScaffold(),

        '/login': (_) => const FullScreenBackGesture(child: LoginScreen()),
        '/register': (_) => const FullScreenBackGesture(child: SignupScreen()),
        '/forgot-password': (_) =>
            const FullScreenBackGesture(child: ForgotPasswordScreen()),

        '/create_post': (_) =>
            const FullScreenBackGesture(child: CreatePostScreen()),
        '/search': (_) => const FullScreenBackGesture(child: SearchScreen()),
        '/edit_post': (_) =>
            const FullScreenBackGesture(child: EditPostScreen()),

        '/my_consultations': (_) =>
            const FullScreenBackGesture(child: MyConsultationsScreen()),

        '/premium': (_) => FullScreenBackGesture(child: PremiumScreen()),

        '/onboarding': (_) =>
            const FullScreenBackGesture(child: OnboardingScreen()),
        '/paymentSetup': (_) =>
            const FullScreenBackGesture(child: PaymentSetupScreen()),
      },

      onGenerateRoute: (settings) {
        final name = settings.name;
        if (name == null) return null;

        final uri = Uri.parse(name);

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'profile') {
          final userId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) =>
                FullScreenBackGesture(child: ProfileScreen(userID: userId)),
            settings: settings,
          );
        }

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'post') {
          final postId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) =>
                FullScreenBackGesture(child: PostDetailScreen(postId: postId)),
            settings: settings,
          );
        }

        if (settings.name == '/consultation') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) return null;

          return MaterialPageRoute(
            builder: (_) => FullScreenBackGesture(
              child: ConsultationBookingScreen(
                targetUserId: args['targetUserId'],
                targetUserName: args['targetUserName'],
              ),
            ),
            settings: settings,
          );
        }

        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) return null;
          debugPrint('[Route:/chat] args=$args');

          return MaterialPageRoute(
            builder: (_) => FullScreenBackGesture(
              child: ChatScreen(
                chatId: args['chatId'],
                otherUserId: args['otherUserId'],
                otherUserName: args['otherUserName'],
                otherUserAvatar: args['otherUserAvatar'],
              ),
            ),
            settings: settings,
          );
        }

        final callV2Route = CallV2RolloutPolicy.productionEnabled
            ? resolveCallV2Route(settings)
            : null;
        if (callV2Route != null) return callV2Route;

        return null;
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _notifBoundUid;
  late final StreamSubscription<User?> _sub;

  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final snap = await FirestoreReadHelper.getDoc(
        ref,
        timeout: const Duration(seconds: 5),
      );
      final data = snap.data() ?? const <String, dynamic>{};
      final authName = (user.displayName ?? '').trim();
      final existingName =
          (data['displayName'] ?? data['fullName'] ?? '').toString().trim();
      final resolvedName = existingName.isNotEmpty
          ? existingName
          : (authName.isNotEmpty ? authName : 'User');

      final patch = <String, dynamic>{
        'displayName': resolvedName,
        'displayName_lc': resolvedName.toLowerCase(),
        'fullName': resolvedName,
        'fullNameLower': resolvedName.toLowerCase(),
      };

      final email = (user.email ?? '').trim();
      if (email.isNotEmpty && (data['email'] ?? '').toString().trim().isEmpty) {
        patch['email'] = email;
      }

      if (!snap.exists) {
        patch.addAll({
          'bio': 'No bio available yet.',
          'followers': [],
          'following': [],
          'postsCount': 0,
          'profilePicture': '',
          'createdAt': FieldValue.serverTimestamp(),
          'xpPoints': 0,
          'badges': [],
          'postCount': 0,
          'commentCount': 0,
          'helpfulMarks': 0,
          'dailyLoginStreak': 0,
          'postingStreak': 0,
          'lastLoginDate': null,
          'lastPostDate': null,
          'referralCount': 0,
          'categoryPosts': {
            'Career': 0,
            'Travel': 0,
            'Finance': 0,
            'Technology': 0,
            'Health': 0,
          },
          'activePerks': {
            'priorityPostBoost': null,
            'profileHighlight': null,
            'commentBoost': null,
          },
          'premiumStatus': 'none',
          'trialUsed': false,
        });
      }

      await ref
          .set(patch, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('ensureUserDoc failed for ${user.uid}: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _notifBoundUid = null;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await notificationService.onSignedOut();
          } catch (_) {}
        });
        return;
      }

      if (_notifBoundUid != user.uid) {
        _notifBoundUid = user.uid;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            unawaited(_ensureUserDoc(user));
          }
          try {
            await notificationService.initialize();
          } catch (e, st) {
            debugPrint('Notification init failed: $e\n$st');
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) {
            unawaited(_ensureUserDoc(user));
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData) {
          return const FullScreenBackGesture(child: LoginScreen());
        }

        final user = snap.data!;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (_, userSnap) {
            if (userSnap.hasError) {
              return const MainScaffold();
            }
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userSnap.data?.data() ?? const <String, dynamic>{};
            final hasOnboardingFlag = data['onboardingComplete'] == true;
            final hasName = ((data['displayName'] ?? data['fullName'] ?? '')
                .toString()
                .trim()
                .isNotEmpty);
            final hasLanguage =
                (data['language'] ?? '').toString().trim().isNotEmpty;
            final hasTopics = data['interestTags'] is List &&
                (data['interestTags'] as List).isNotEmpty;

            final needsOnboarding =
                !(hasOnboardingFlag && hasName && hasLanguage && hasTopics);
            return needsOnboarding
                ? const FullScreenBackGesture(child: OnboardingScreen())
                : const MainScaffold();
          },
        );
      },
    );
  }
}
