import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// The app's [GoRouter].
///
/// It follows [authControllerProvider]: with no session it always shows the
/// login page; once the user signs in or continues as a guest it moves on to
/// Home. Screens therefore never navigate after login themselves.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router wants a Listenable to know when to re-check `redirect`.
  // This one changes whenever the session does.
  final session = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final onLogin = state.matchedLocation == AppRoutes.login;
      if (!session.value.hasSession) return onLogin ? null : AppRoutes.login;
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

  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
