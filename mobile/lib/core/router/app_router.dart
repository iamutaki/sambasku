import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/pages/activity_page.dart';
import '../../features/auth/auth_router.dart';
import '../../features/dictionary/presentation/pages/home_search_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../shared/splash/splash_router.dart';
import '../network/auth_token_storage.dart';

/// Router utama (pola jnn_mobile):
/// - redirect auth global (isAuth dari AuthTokenStorage)
/// - StatefulShellRoute = 3 tab bottom nav: Home (pencarian), Action
///   (kontribusi - placeholder), Profile (placeholder)
class AppRouter {
  AppRouter._();

  static final AuthTokenStorage _tokenStorage = AuthTokenStorage.instance;

  static final GoRouter router = GoRouter(
    initialLocation: SplashRouter.splash.path,
    routes: [
      ...SplashRouter.routes,
      ...AuthRouter.routes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              name: 'HomeRouter.search',
              builder: (context, state) => const HomeSearchPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/action',
              name: 'ActionRouter.activity',
              builder: (context, state) => const ActivityPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              name: 'ProfileRouter.profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ]),
        ],
      ),
    ],
    redirect: _redirect,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Halaman tidak ditemukan: ${state.error}'),
      ),
    ),
  );

  /// Tamu BOLEH pakai app (pencarian publik) - jadi redirect hanya
  /// menghalau user LOGIN-page yang sudah punya sesi, dan mengembalikan
  /// ke login dari splash saat belum pernah memilih apa pun.
  static Future<String?> _redirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuth = await _tokenStorage.getIsAuth();
    final isOnLogin = state.matchedLocation == AuthRouter.login.path;

    // sudah login tapi masih di halaman login -> langsung home
    if (isAuth && isOnLogin) return '/';

    return null;
  }
}

/// Shell 3 tab bottom navigation.
class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Kontribusi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
