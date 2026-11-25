import 'package:connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/screens/home/home_content_screen.dart';
import 'package:connect_app/screens/posts/create_post_screen.dart';
import 'package:connect_app/screens/search/search_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/theme/tokens.dart';

import 'package:connect_app/navigation/app_router.dart';

/// Lets a screen inside a tab switch tabs (after posting, show the feed).
class MainTabs {
  static final requested = ValueNotifier<int?>(null);
}

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
    MainTabs.requested.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    MainTabs.requested.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final index = MainTabs.requested.value;
    if (index == null || !mounted) return;
    MainTabs.requested.value = null;
    setState(() => _selectedIndex = index);
    if (index == 0) _homeController.scrollToTop();
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
      // Hidden tabs stop animations and pause any playing feed video.
      child: TickerMode(
        enabled: _selectedIndex == index,
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
              ProfileScreen(
                  userID: FirebaseAuth.instance.currentUser?.uid ?? ''),
            ),
          ],
        ),
        bottomNavigationBar: _InkTabBar(
          index: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            (Icons.home_outlined, Icons.home_rounded, context.l10n.tabHome),
            (Icons.search_rounded, Icons.search_rounded, context.l10n.tabSearch),
            (Icons.add_circle_outline_rounded, Icons.add_circle_rounded,
                context.l10n.tabPost),
            (Icons.person_outline_rounded, Icons.person_rounded,
                context.l10n.tabProfile),
          ],
        ),
      ),
    );
  }
}

/// Quiet paper bar: icons only, a hairline on top, a clay dot under the
/// active tab. Labels stay for screen readers.
class _InkTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;

  const _InkTabBar({
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].$3,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == index ? items[i].$2 : items[i].$1,
                            size: 25,
                            color: i == index
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == index
                                  ? AppColors.accent
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
