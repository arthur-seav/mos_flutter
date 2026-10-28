import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_routes.dart';
import '../../../core/widgets/square_icon_button.dart';

/// The small white back button at the top of the sign-up and
/// forgot-password pages.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  /// Defaults to going back one page, or to the login page when there is
  /// nothing to go back to (for example after a hot restart).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SquareIconButton(
        icon: Icons.chevron_left,
        tooltip: 'Back',
        size: 40,
        radius: 10,
        onPressed: onPressed ?? () => goBack(context),
      ),
    );
  }

  /// Back one page, or to login when there is no page to go back to.
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }
}
