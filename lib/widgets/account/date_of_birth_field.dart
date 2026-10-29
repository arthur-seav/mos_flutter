import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/time_format.dart';

/// The read-only "Date of Birth" field on "Edit Personal Info": tapping it
/// opens a date picker instead of the keyboard, so the stored date is
/// always a real date (`users.date_of_birth`, which may be empty).
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.value,
    required this.onPressed,
    this.enabled = true,
  });

  /// Null when the account has no date of birth yet.
  final DateTime? value;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth', style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.cake_outlined, size: 20),
            ),
            child: Text(
              value == null ? 'Not set' : formatDate(value),
              style: value == null
                  ? AppTextStyles.body.copyWith(color: AppColors.textSecondary)
                  : AppTextStyles.body,
            ),
          ),
        ),
      ],
    );
  }
}
