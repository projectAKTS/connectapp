import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart'; // ✅ Notifications
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/posts/post_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/posts/boost_post_screen.dart'; // ✅ Boost Post Screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize Notifications (FCM & Local)
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

        // ✅ Safe Profile Navigation (Prevents Crash If No User Logged In)
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
      },
      onGenerateRoute: (settings) {
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

        return null;
      },
    );
  }
}
