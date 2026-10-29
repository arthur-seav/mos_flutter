import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// One line of a [SettingsCard]: a rounded icon box, a label and
/// something at the end (a chevron, a switch, or nothing).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;

  /// The chevron or the notifications switch. Null leaves the end empty.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Text and icon color; used for "Sign out", which is in Danger red.
  final Color? color;

  /// The chevron used by the rows that open another page.
  static const chevron = Icon(
    Icons.chevron_right,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color ?? AppColors.mocha),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: color == null
                    ? AppTextStyles.bodyMedium
                    : AppTextStyles.bodyMedium.copyWith(color: color),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
