import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_options.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/post_screen.dart';
import 'screens/search_screen.dart';
import 'screens/create_post_screen.dart'; // Ensure correct import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        // Login screen route
        '/login': (context) => const LoginScreen(),

        // Register screen route
        '/register': (context) => const RegisterScreen(),

        // Home screen route
        '/home': (context) => const HomeScreen(),

        // Profile screen route
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

        // Create post screen route
        '/create_post': (context) => const CreatePostScreen(),

        // Search screen route
        '/search': (context) => const SearchScreen(),
      },
    );
  }
}
