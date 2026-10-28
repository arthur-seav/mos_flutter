import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// How long a success message stays before the app moves on by itself.
const authStatusDisplayTime = Duration(milliseconds: 1500);

/// A full-page status: a large mark, a short message and an optional
/// button. Used for "Account created", "Verifying account..." and
/// "Password reset" (Figma 1.2_Sign-Up_Success, 1.3_Verify, 1.3_Success).
class AuthStatusView extends StatelessWidget {
  const AuthStatusView.success({super.key, required this.message})
    : _isLoading = false,
      action = null;

  const AuthStatusView.loading({super.key, required this.message, this.action})
    : _isLoading = true;

  final String message;
  final bool _isLoading;

  /// Shown under the message, e.g. a Cancel button while loading.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: Center(
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.espresso,
                        ),
                      )
                    : const _CheckMark(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// The thin hand-drawn style tick from the Figma success screens.
class _CheckMark extends StatelessWidget {
  const _CheckMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Success',
      child: CustomPaint(size: const Size(72, 48), painter: _CheckPainter()),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.espresso
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..lineTo(size.width * 0.38, size.height * 0.95)
      ..lineTo(size.width * 0.95, size.height * 0.05);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
