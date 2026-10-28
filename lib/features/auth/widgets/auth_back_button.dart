import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../app_routes.dart';

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
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: 'Back',
          child: InkWell(
            onTap: onPressed ?? () => goBack(context),
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.chevron_left, color: AppColors.textPrimary),
            ),
          ),
        ),
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
