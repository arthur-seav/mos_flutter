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

  /// Pages for people who are not signed in. Everything else needs a
  /// session (customer or guest).
  static const authPages = {login, signUp, forgotPassword, resetPassword};
}
