import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The main full-width button. Shows a spinner and ignores taps while
/// [isLoading], so a form cannot be sent twice.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.onBrand,
              ),
            )
          : Text(label),
    );
  }
}
