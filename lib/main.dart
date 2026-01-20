// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

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
import 'services/firebase_options.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'debug/firestore_probe.dart';
import 'theme/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final NotificationService notificationService;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      androidProvider: AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint('⚠️ AppCheck failed: $e');
  }

  // Stripe
  Stripe.publishableKey = 'pk_live_xxxxxxxxxxxxxxxxxxxxx';
  Stripe.merchantIdentifier = 'merchant.com.connectapp';
  Stripe.urlScheme = 'connectapp';
  await Stripe.instance.applySettings();

  // FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Notifications + Subscriptions
  notificationService = NotificationService(navigatorKey: navigatorKey);

  final available = await SubscriptionService.init();
  if (available) {
    SubscriptionService.setupListener(_handlePurchaseUpdates);
  }

  runApp(const MyApp());
}

void _handlePurchaseUpdates(List<PurchaseDetails> details) {
  for (final pd in details) {
    if (pd.status == PurchaseStatus.purchased ||
        pd.status == PurchaseStatus.restored) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) continue;

      final doc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (pd.productID == 'premium_monthly' ||
          pd.productID == 'premium_yearly') {
        final expires = DateTime.now().add(
          pd.productID == 'premium_monthly'
              ? const Duration(days: 30)
              : const Duration(days: 365),
        );

        doc.set({
          'premiumStatus':
              pd.productID == 'premium_monthly' ? 'Monthly' : 'Yearly',
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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
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
    });

    final initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
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
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),

      // 👇 ROOT ROUTE SAFETY
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),

        '/login': (_) => const LoginScreen(),
        '/register': (_) => const SignupScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),

        '/search': (_) => const SearchScreen(),
        '/create_post': (_) => const CreatePostScreen(),
        '/edit_post': (_) => const EditPostScreen(),

        '/my_consultations': (_) => const MyConsultationsScreen(),
        '/premium': (_) => const PremiumScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/paymentSetup': (_) => const PaymentSetupScreen(),
      },

      // 👇 ARGUMENT / DEEP LINK ROUTES
      onGenerateRoute: (settings) {
        debugPrint('➡️ onGenerateRoute: ${settings.name}');
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;

        if (uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'profile') {
          return MaterialPageRoute(
            builder: (_) =>
                ProfileScreen(userID: uri.pathSegments[1]),
            settings: settings,
          );
        }

        if (uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'post') {
          return MaterialPageRoute(
            builder: (_) =>
                PostDetailScreen(postId: uri.pathSegments[1]),
            settings: settings,
          );
        }

        if (settings.name == '/consultation') {
          final args =
              settings.arguments as Map<String, dynamic>?;
          if (args == null) return null;

          return MaterialPageRoute(
            builder: (_) => ConsultationBookingScreen(
              targetUserId: args['targetUserId'],
              targetUserName: args['targetUserName'],
            ),
            settings: settings,
          );
        }

        if (settings.name == '/chat') {
          final args =
              settings.arguments as Map<String, dynamic>?;
          if (args == null) return null;

          return MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: args['otherUserId'],
              otherUserName: args['otherUserName'],
              otherUserAvatar: args['otherUserAvatar'],
            ),
            settings: settings,
          );
        }

        return null;
      },

      // 👇 DEBUG UNKNOWN ROUTES
      onUnknownRoute: (settings) {
        debugPrint('❌ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
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
  bool _notifInitDone = false;
  late final StreamSubscription<User?> _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !_notifInitDone) {
        _notifInitDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await notificationService.initialize();
          await FirestoreProbe.run();
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

        return snap.hasData
            ? const MainScaffold()
            : const LoginScreen();
      },
    );
  }
}
