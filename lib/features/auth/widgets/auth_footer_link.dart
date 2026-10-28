import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// "New here? Create an account" / "Already have an account? Sign in"
/// at the bottom of the auth pages. Wraps onto two lines when the screen
/// is narrow or the system font size is large.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}
