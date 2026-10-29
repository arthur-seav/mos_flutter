import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'data/repositories/auth_repository.dart';
import 'screens/account/profile_screen.dart';
import 'controllers/checkout/payment_outcome.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/checkout/card_payment_screen.dart';
import 'screens/checkout/checkout_screen.dart';
import 'screens/checkout/khqr_payment_screen.dart';
import 'screens/checkout/payment_result_screen.dart';
import 'controllers/auth/auth_controller.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/menu/customize_drink_screen.dart';
import 'screens/menu/menu_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/shell/main_shell.dart';

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
  // It fires only when there starts or stops being a session (sign in,
  // sign out), not when a guest signs in: that guest is on a pushed
  // login page, which goes back by itself, and a re-check at that moment
  // rebuilds the page stack from before the pop and puts login back.
  var auth = ref.read(authControllerProvider);
  final session = ValueNotifier<bool>(auth.hasSession);
  ref.listen(authControllerProvider, (_, next) {
    auth = next;
    session.value = next.hasSession;
  });

  final router = GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final onAuthPage = AppRoutes.authPages.contains(state.matchedLocation);
      if (!auth.hasSession) {
        return onAuthPage ? null : AppRoutes.login;
      }
      // BR-06 / TC-18: guests never reach checkout or payment, e.g. by a
      // link; they log in first and come back to checkout.
      if (auth.isGuest && AppRoutes.isOrdering(state.matchedLocation)) {
        return AppRoutes.loginThenReturnTo(AppRoutes.checkout);
      }
      if (!onAuthPage) return null;
      final from = state.uri.queryParameters['from'];
      if (auth.isGuest) {
        // A guest stays on login only when sent there to sign in before
        // ordering (BR-06, TC-18: login?from=/checkout). "Continue as
        // guest" on the plain login page goes Home.
        final plainLogin =
            state.matchedLocation == AppRoutes.login && from == null;
        return plainLogin ? AppRoutes.home : null;
      }
      // Signed in: on to where they were going, or Home.
      return _returnPath(from) ?? AppRoutes.home;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          returnTo: _returnPath(state.uri.queryParameters['from']),
        ),
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
      GoRoute(
        path: AppRoutes.productPattern,
        builder: (context, state) => CustomizeDrinkScreen(
          productId: int.parse(state.pathParameters['id']!),
          lineId: int.tryParse(state.uri.queryParameters['line'] ?? ''),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.khqrPattern,
        builder: (context, state) => KhqrPaymentScreen(
          orderId: int.parse(state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.cardPattern,
        builder: (context, state) => CardPaymentScreen(
          orderId: int.parse(state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentResult,
        // Only reachable from a payment page, which passes the outcome.
        redirect: (context, state) =>
            state.extra is PaymentOutcome ? null : AppRoutes.home,
        builder: (context, state) =>
            PaymentResultScreen(outcome: state.extra! as PaymentOutcome),
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

/// Only paths inside the app ("/checkout"), never another site.
String? _returnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  return from;
}
