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

  /// Pages for people who are not signed in. Everything else needs a
  /// session (customer or guest).
  static const authPages = {login, signUp, forgotPassword, resetPassword};
}
