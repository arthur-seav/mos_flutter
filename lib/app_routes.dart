/// Route paths, kept in one place so screens never hard-code strings.
abstract final class AppRoutes {
  static const login = '/login';
  static const signUp = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/forgot-password/reset';

  static const home = '/home';
  static const menu = '/menu';
  static const orders = '/orders';
  static const profile = '/profile';

  /// Drink customization, opened over the tabs. With [line], it edits
  /// that cart line instead of adding a new one ("Edit options").
  static const productPattern = '/product/:id';
  static String product(int id, {int? line}) =>
      line == null ? '/product/$id' : '/product/$id?line=$line';

  /// The cart (FR-10), opened over the tabs.
  static const cart = '/cart';

  /// Checkout (FR-11 to FR-13).
  static const checkout = '/checkout';

  /// Paying for an order that is waiting for payment.
  static const khqrPattern = '/pay/khqr/:orderId';
  static String khqr(int orderId) => '/pay/khqr/$orderId';
  static const cardPattern = '/pay/card/:orderId';
  static String card(int orderId) => '/pay/card/$orderId';

  /// Success or failure (SA §4.2.3.4). Needs a PaymentOutcome as `extra`.
  static const paymentResult = '/pay/result';

  /// Login for a guest who must sign in first (BR-06, TC-18); afterwards
  /// the app goes to [path].
  static String loginThenReturnTo(String path) =>
      '$login?from=${Uri.encodeQueryComponent(path)}';

  /// Checkout and payment pages: signed-in customers only (BR-06).
  static bool isOrdering(String location) =>
      location == checkout || location.startsWith('/pay/');

  /// Pages for people who are not signed in. Everything else needs a
  /// session (customer or guest).
  static const authPages = {login, signUp, forgotPassword, resetPassword};
}
