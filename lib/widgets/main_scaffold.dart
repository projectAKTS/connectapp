import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/screens/home/home_content_screen.dart';
import 'package:connect_app/screens/posts/create_post_screen.dart';
import 'package:connect_app/screens/search/search_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  List<Widget> _buildScreens() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return [
      const HomeContentScreen(),
      const SearchScreen(),
      const CreatePostScreen(),
      ProfileScreen(userID: uid),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
