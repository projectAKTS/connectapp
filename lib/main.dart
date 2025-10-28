// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

import 'screens/search/search_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/posts/edit_post_screen.dart';
import 'screens/posts/boost_post_screen.dart';
import 'screens/posts/post_detail_screen.dart';
import 'screens/consultation/consultation_booking_screen.dart';
import 'screens/consultation/my_consultation_screen.dart';
import 'screens/credits_store_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/payment/payment_setup_screen.dart';

import 'services/firebase_options.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'widgets/main_scaffold.dart';
import 'theme/theme.dart';
import 'debug/firestore_probe.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final NotificationService notificationService;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background FCM messages if needed
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1️⃣ Firebase Initialization ---
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- 2️⃣ Firebase App Check (PRODUCTION / TESTFLIGHT MODE) ---
  try {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      androidProvider: AndroidProvider.playIntegrity,
    );
    debugPrint('✅ Firebase App Check activated (App Attest + DeviceCheck)');
  } catch (e, st) {
    debugPrint('⚠️ Firebase App Check init failed → $e\n$st');
  }

  // --- 3️⃣ Stripe Initialization ---
  Stripe.publishableKey = 'pk_live_xxxxxxxxxxxxxxxxxxxxx'; // replace with your live or test key
  Stripe.merchantIdentifier = 'merchant.com.connectapp';
  Stripe.urlScheme = 'connectapp';
  await Stripe.instance.applySettings();

  // --- 4️⃣ Firebase Cloud Messaging ---
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // --- 5️⃣ Notifications & Subscriptions ---
  notificationService = NotificationService(navigatorKey: navigatorKey);

  final iapAvailable = await SubscriptionService.init();
  if (iapAvailable) {
    SubscriptionService.setupListener(_handlePurchaseUpdates);
  }

  // --- 6️⃣ Launch App ---
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
      } else if (pd.productID.startsWith('credits_')) {
        final minutes = pd.productID == 'credits_5min'
            ? 5
            : pd.productID == 'credits_30min'
                ? 30
                : 60;
        doc.set({
          'freeConsultationMinutes': FieldValue.increment(minutes)
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
    FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData data) {
      final uri = data.link;
      if (uri.path == '/success') {
        ScaffoldMessenger.of(navigatorKey.currentContext!)
            .showSnackBar(const SnackBar(content: Text('✅ Payment successful!')));
      } else if (uri.path == '/cancel') {
        ScaffoldMessenger.of(navigatorKey.currentContext!)
            .showSnackBar(const SnackBar(content: Text('❌ Payment canceled.')));
      }
    }).onError((e) {
      debugPrint('Dynamic link error: $e');
    });

    final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      final uri = initialLink.link;
      if (uri.path == '/success') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(navigatorKey.currentContext!)
              .showSnackBar(const SnackBar(content: Text('✅ Payment successful!')));
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
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const SignupScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/home': (_) => const MainScaffold(),
        '/create_post': (_) => const CreatePostScreen(),
        '/search': (_) => const SearchScreen(),
        '/edit_post': (_) => const EditPostScreen(),
        '/my_consultations': (_) => const MyConsultationsScreen(),
        '/credits': (_) => const CreditsStoreScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/paymentSetup': (_) => const PaymentSetupScreen(),
        '/chat': (ctx) {
          final args =
              ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          final otherUserId = args?['otherUserId'] as String?;
          final otherUserName = args?['otherUserName'] as String?;
          final otherUserAvatar = args?['otherUserAvatar'] as String?;
          if (otherUserId == null || otherUserId.isEmpty) {
            return const Scaffold(
                body: Center(child: Text('Missing otherUserId')));
          }
          return ChatScreen(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserAvatar: otherUserAvatar,
          );
        },
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name!);
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
          final id = args?['targetUserId'] as String?;
          final name = args?['targetUserName'] as String?;
          if (id == null || name == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Invalid consultation arguments')),
              ),
              settings: settings,
            );
          }
          return MaterialPageRoute(
            builder: (_) => ConsultationBookingScreen(
              targetUserId: id,
              targetUserName: name,
            ),
            settings: settings,
          );
        }
        return null;
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const MainScaffold()),
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

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) async {
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
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) return const MainScaffold();
        return const LoginScreen();
      },
    );
  }
}
