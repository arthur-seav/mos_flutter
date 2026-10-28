import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'data/repositories/auth_repository.dart';
import 'features/account/profile_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/menu/menu_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/shell/main_shell.dart';

export 'app_routes.dart';

/// The app's [GoRouter].
///
/// It follows [authControllerProvider]:
/// - with no session, only the auth pages (login, sign up, forgot
///   password) can be opened; anything else goes to login;
/// - with a session, the auth pages send the user to Home.
///
/// Screens therefore never navigate after signing in themselves.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router wants a Listenable to know when to re-check `redirect`.
  // This one changes whenever the session does.
  final session = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final onAuthPage = AppRoutes.authPages.contains(state.matchedLocation);
      if (!session.value.hasSession) {
        return onAuthPage ? null : AppRoutes.login;
      }
      return onAuthPage ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
        routes: [
          GoRoute(
            path: 'reset',
            // Only reachable from the verify step, which passes a ticket.
            redirect: (context, state) => state.extra is PasswordResetTicket
                ? null
                : AppRoutes.forgotPassword,
            builder: (context, state) => ResetPasswordScreen(
              ticket: state.extra! as PasswordResetTicket,
            ),
          ),
        ],
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
