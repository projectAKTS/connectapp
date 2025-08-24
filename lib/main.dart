import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/search/search_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
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

import 'services/firebase_options.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'widgets/main_scaffold.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late final NotificationService notificationService;

// Background handler (don’t navigate here)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // no-op
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  notificationService = NotificationService(navigatorKey: navigatorKey);

  // In-app purchases
  final iapAvailable = await SubscriptionService.init();
  if (iapAvailable) {
    SubscriptionService.setupListener(_handlePurchaseUpdates);
  }

  // Run the app first
  runApp(const MyApp());

  // Initialize notifications AFTER auth, and only once
  bool _notifInitDone = false;
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null && !_notifInitDone) {
      _notifInitDone = true;
      try {
        await notificationService.initialize(); // safe if called once
      } catch (e, st) {
        debugPrint('Notification init failed: $e\n$st');
      }
    }
  });
}

void _handlePurchaseUpdates(List<PurchaseDetails> details) {
  for (final pd in details) {
    if (pd.status == PurchaseStatus.purchased || pd.status == PurchaseStatus.restored) {
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
        // ⬇ ensure rules allow this field (added to allowedUserKeys)
        doc.set({'freeConsultationMinutes': FieldValue.increment(minutes)}, SetOptions(merge: true));
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snap.hasData) {
            return const MainScaffold();
          } else {
            return const LoginScreen();
          }
        },
      ),

      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const SignupScreen(),
        '/home': (_) => const MainScaffold(),
        '/create_post': (_) => const CreatePostScreen(),
        '/search': (_) => const SearchScreen(),
        '/edit_post': (_) => const EditPostScreen(),
        '/my_consultations': (_) => const MyConsultationsScreen(),
        '/credits': (_) => const CreditsStoreScreen(),
        '/onboarding': (_) => const OnboardingScreen(),

        '/chat': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          final otherUserId = args?['otherUserId'] as String?;
          if (otherUserId == null || otherUserId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Missing otherUserId')));
          }
          return ChatScreen(otherUserId: otherUserId);
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

        if (settings.name == '/boostPost') {
          final args = settings.arguments as Map<String, dynamic>?;
          final postId = args?['postId'] as String?;
          return MaterialPageRoute(
            builder: (_) => postId == null
                ? const Scaffold(body: Center(child: Text('Invalid Post ID')))
                : BoostPostScreen(postId: postId),
            settings: settings,
          );
        }

        if (settings.name == '/consultation') {
          final args = settings.arguments as Map<String, dynamic>?;
          final id = args?['targetUserId'] as String?;
          final name = args?['targetUserName'] as String?;
          final rate = (args?['ratePerMinute'] as num?)?.toInt() ?? 0;
          return MaterialPageRoute(
            builder: (_) => (id == null || name == null)
                ? const Scaffold(body: Center(child: Text('Invalid args')))
                : ConsultationBookingScreen(
                    targetUserId: id,
                    targetUserName: name,
                    ratePerMinute: rate,
                  ),
            settings: settings,
          );
        }

        return null;
      },

      onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }
}
