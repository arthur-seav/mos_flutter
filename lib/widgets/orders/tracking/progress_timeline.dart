// Material has its own StepState (for Stepper); this page uses the one
// from OrderProgress.
import 'package:flutter/material.dart' hide StepState;

import '../../../controllers/orders/order_progress.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// The five steps of the order flow, one row each, joined by a vertical
/// line (Figma: the white card in the middle of the tracking page).
class ProgressTimeline extends StatelessWidget {
  const ProgressTimeline({super.key, required this.steps});

  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final ProgressStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final faded = step.state == StepState.skipped;
    final titleStyle = switch (step.state) {
      StepState.current => AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.w700,
      ),
      StepState.failed => AppTextStyles.bodyMedium.copyWith(
        color: AppColors.danger,
      ),
      StepState.skipped => AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      StepState.done || StepState.upcoming => AppTextStyles.bodyMedium,
    };
    final subtitleStyle = switch (step.state) {
      StepState.current => AppTextStyles.caption.copyWith(
        color: AppColors.caramel,
      ),
      StepState.failed => AppTextStyles.caption.copyWith(
        color: AppColors.danger,
      ),
      StepState.skipped => AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      StepState.done || StepState.upcoming => AppTextStyles.caption,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                _Marker(state: step.state),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: faded
                          ? AppColors.border.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: subtitleStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 22px dot at the left of a step: a green check when it happened, a
/// caramel ring while it is happening, a red cross where it stopped, an
/// empty ring for what has not happened yet.
class _Marker extends StatelessWidget {
  const _Marker({required this.state});

  final StepState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case StepState.done:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 14, color: AppColors.onBrand),
        );
      case StepState.failed:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 14, color: AppColors.onBrand),
        );
      case StepState.current:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.caramel, width: 2),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.caramel,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case StepState.upcoming:
      case StepState.skipped:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: state == StepState.skipped
                  ? AppColors.border.withValues(alpha: 0.5)
                  : AppColors.border,
              width: 2,
            ),
          ),
        );
    }
  }
}
