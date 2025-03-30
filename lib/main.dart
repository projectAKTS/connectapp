import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart'; // Notifications
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/posts/post_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/posts/boost_post_screen.dart'; // Boost Post Screen
import 'screens/consultation/consultation_booking_screen.dart'; // Consultation Booking Screen
import 'screens/consultation/my_consultation_screen.dart'; // My Consultations Screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notifications (FCM & Local)
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Connect App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: FirebaseAuth.instance.currentUser != null ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/create_post': (context) => const CreatePostScreen(),
        '/search': (context) => const SearchScreen(),
        '/profile': (context) {
          final currentUser = FirebaseAuth.instance.currentUser;
          return currentUser != null
              ? ProfileScreen(userID: currentUser.uid)
              : const Scaffold(
                  body: Center(
                    child: Text(
                      'Please log in to view your profile',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
        },
        // My Consultations Route
        '/my_consultations': (context) => const MyConsultationsScreen(),
      },
      onGenerateRoute: (settings) {
        // Boost Post Route
        if (settings.name == '/boostPost') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null || !args.containsKey('postId')) {
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid Post ID. Please try again.',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ),
            );
          }
          final postId = args['postId'];
          return MaterialPageRoute(
            builder: (context) => BoostPostScreen(postId: postId),
          );
        }

        // Consultation Booking Route
        if (settings.name == '/consultation') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null ||
              !args.containsKey('targetUserId') ||
              !args.containsKey('targetUserName')) {
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(
                  child: Text(
                    'Invalid consultation arguments. Please try again.',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (context) => ConsultationBookingScreen(
              targetUserId: args['targetUserId'],
              targetUserName: args['targetUserName'],
              ratePerMinute: args['ratePerMinute'] ?? 0,
            ),
          );
        }

        return null;
      },
    );
  }
}
