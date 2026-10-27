import 'package:go_router/go_router.dart';

import 'features/account/profile_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/menu/menu_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/shell/main_shell.dart';

/// Route paths, kept in one place so screens never hard-code strings.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const menu = '/menu';
  static const orders = '/orders';
  static const profile = '/profile';
}

/// Owns the app's [GoRouter].
///
/// The router listens to [AuthController]: with no session it always shows
/// the login page; once the user signs in or continues as a guest it moves
/// on to Home. Screens therefore never navigate after login themselves.
class AppRouter {
  AppRouter(this._auth);

  final AuthController _auth;

  late final GoRouter config = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _auth,
    redirect: (context, state) {
      final onLogin = state.matchedLocation == AppRoutes.login;
      if (!_auth.hasSession) return onLogin ? null : AppRoutes.login;
      if (onLogin) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.menu,
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
