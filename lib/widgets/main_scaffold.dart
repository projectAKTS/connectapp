import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/screens/home/home_content_screen.dart';
import 'package:connect_app/screens/posts/create_post_screen.dart';
import 'package:connect_app/screens/search/search_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/theme/tokens.dart';

import 'package:connect_app/navigation/app_router.dart';

/// ✅ Controller that HomeContentScreenState can register into (NO GlobalKey)
class HomeTabController {
  HomeContentScreenState? _state;

  void attach(HomeContentScreenState state) {
    _state = state;
  }

  void detach(HomeContentScreenState state) {
    if (_state == state) _state = null;
  }

  Future<void> scrollToTop() async {
    final s = _state;
    if (s == null) return;
    await s.scrollToTopFromTab();
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // ✅ Each tab gets its own Navigator (Instagram behavior)
  final _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  // ✅ Home scroll-to-top without GlobalKey
  final HomeTabController _homeController = HomeTabController();

  // Cache root pages so switching tabs doesn’t recreate them
  late final Widget _homeRoot;
  late final Widget _searchRoot;
  late final Widget _createRoot;

  @override
  void initState() {
    super.initState();
    _homeRoot = HomeContentScreen(controller: _homeController);
    _searchRoot = const SearchScreen();
    _createRoot = const CreatePostScreen();
  }

  NavigatorState? get _currentNav => _navKeys[_selectedIndex].currentState;

  void _onItemTapped(int index) async {
    if (index == _selectedIndex) {
      final nav = _currentNav;
      if (nav != null && nav.canPop()) {
        nav.popUntil((r) => r.isFirst);
      }
      if (index == 0) {
        await _homeController.scrollToTop();
      }
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<bool> _onWillPop() async {
    final nav = _currentNav;

    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }

    return true;
  }

  Widget _buildTabNavigator(int index, Widget root) {
    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
        key: _navKeys[index],
        onGenerateRoute: (settings) {
          // ✅ IMPORTANT: make tab navigator understand shared routes too
          return AppRouter.onGenerateTabRoute(
            settings: settings,
            tabRoot: root,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: [
            _buildTabNavigator(0, _homeRoot),
            _buildTabNavigator(1, _searchRoot),
            _buildTabNavigator(2, _createRoot),
            _buildTabNavigator(
              3,
              ProfileScreen(userID: FirebaseAuth.instance.currentUser?.uid ?? ''),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.canvas,
          currentIndex: _selectedIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.muted,
          selectedIconTheme: const IconThemeData(color: AppColors.primary),
          unselectedIconTheme: const IconThemeData(color: AppColors.muted),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Post'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
