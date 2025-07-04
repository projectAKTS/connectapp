// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'screens/search/search_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/posts/edit_post_screen.dart';
import 'screens/posts/boost_post_screen.dart';
import 'screens/consultation/consultation_booking_screen.dart';
import 'screens/consultation/my_consultation_screen.dart';
import 'screens/credits_store_screen.dart';
import 'screens/Agora_Call_Screen.dart';
import 'screens/profile/profile_screen.dart';

import 'services/firebase_options.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  await NotificationService().initialize();

  final iapAvailable = await SubscriptionService.init();
  if (iapAvailable) {
    SubscriptionService.setupListener(_handlePurchaseUpdates);
  }

  runApp(const MyApp());
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
        doc.update({'freeConsultationMinutes': FieldValue.increment(minutes)});
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData) {
            return const MainScaffold();
          } else {
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainScaffold(), // ✅ FIX ADDED HERE
        '/create_post': (_) => const CreatePostScreen(),
        '/search': (_) => const SearchScreen(),
        '/edit_post': (_) => const EditPostScreen(),
        '/my_consultations': (_) => const MyConsultationsScreen(),
        '/credits': (_) => const CreditsStoreScreen(),
        '/video_call': (_) => const AgoraCallScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/boostPost') {
          final args = settings.arguments as Map<String, dynamic>?;
          final postId = args?['postId'] as String?;
          return MaterialPageRoute(
            builder: (_) => postId == null
                ? const Scaffold(body: Center(child: Text('Invalid Post ID')))
                : BoostPostScreen(postId: postId),
          );
        }

        if (settings.name == '/consultation') {
          final args = settings.arguments as Map<String, dynamic>?;
          final id = args?['targetUserId'] as String?;
          final name = args?['targetUserName'] as String?;
          final rate = (args?['ratePerMinute'] as num?)?.toInt() ?? 0;
          return MaterialPageRoute(
            builder: (_) => id == null || name == null
                ? const Scaffold(body: Center(child: Text('Invalid args')))
                : ConsultationBookingScreen(
                    targetUserId: id,
                    targetUserName: name,
                    ratePerMinute: rate,
                  ),
          );
        }

        if (settings.name == '/profile') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userId = args?['userID'] as String?;
          return MaterialPageRoute(
            builder: (_) => userId == null
                ? const Scaffold(body: Center(child: Text('Missing userID')))
                : ProfileScreen(userID: userId),
          );
        }

        return null;
      },
    );
  }
}
