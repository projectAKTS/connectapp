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
import 'screens/credits/credits_screen.dart';

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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      androidProvider: AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint('⚠️ AppCheck failed: $e');
  }

  Stripe.publishableKey = 'pk_live_xxxxxxxxxxxxxxxxxxxxx';
  Stripe.merchantIdentifier = 'merchant.com.connectapp';
  Stripe.urlScheme = 'connectapp';
  await Stripe.instance.applySettings();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

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

      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (pd.productID == 'premium_monthly' || pd.productID == 'premium_yearly') {
        final isMonthly = pd.productID == 'premium_monthly';
        final expires = DateTime.now().add(
          isMonthly ? const Duration(days: 30) : const Duration(days: 365),
        );

        doc.set({
          'premiumStatus': isMonthly ? 'Monthly' : 'Yearly',
          'premiumExpiresAt': Timestamp.fromDate(expires),
        }, SetOptions(merge: true));
      } else if (pd.productID.startsWith('credits_')) {
        final minutes = pd.productID == 'credits_5min'
            ? 5
            : pd.productID == 'credits_30min'
                ? 30
                : 60;

        doc.set({
          'freeConsultationMinutes': FieldValue.increment(minutes),
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

        '/login': (_) => const LoginScreen(),
        '/register': (_) => const SignupScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),

        '/create_post': (_) => const CreatePostScreen(),
        '/search': (_) => const SearchScreen(),
        '/edit_post': (_) => const EditPostScreen(),

        '/my_consultations': (_) => const MyConsultationsScreen(),

        '/credits': (_) => CreditsStoreScreen(),
        '/premium': (_) => PremiumScreen(),

        '/onboarding': (_) => const OnboardingScreen(),
        '/paymentSetup': (_) => const PaymentSetupScreen(),
      },

      onGenerateRoute: (settings) {
        final name = settings.name;
        if (name == null) return null;

        final uri = Uri.parse(name);

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'profile') {
          final userId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => ProfileScreen(userID: userId),
            settings: settings,
          );
        }

        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'post') {
          final postId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId),
            settings: settings,
          );
        }

        if (settings.name == '/consultation') {
          final args = settings.arguments as Map<String, dynamic>?;
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
          final args = settings.arguments as Map<String, dynamic>?;
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

      onUnknownRoute: (settings) {
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
          try {
            await notificationService.initialize();
          } catch (e, st) {
            debugPrint('Notification init failed: $e\n$st');
          }

          try {
            await FirestoreProbe.run();
          } catch (e) {
            debugPrint('FirestoreProbe.run() error: $e');
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

        // If already signed in, go straight to home
        return snap.hasData ? const MainScaffold() : const LoginScreen();
      },
    );
  }
}
