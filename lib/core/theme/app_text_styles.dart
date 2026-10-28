import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles from SA 2.0, section 4.1.1 (DG-F01 to DG-F08).
abstract final class AppTextStyles {
  static const serif = 'Fraunces';
  static const sans = 'DMSans';

  /// DG-F01: main page titles and the pickup code.
  static const pageTitle = TextStyle(
    fontFamily: serif,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// DG-F02: second-level titles, drink names, status titles.
  static const title = TextStyle(
    fontFamily: serif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  /// DG-F03: section titles, product names.
  static const sectionTitle = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// DG-F04: normal body text.
  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// DG-F05: body text with a bit of emphasis, like option names.
  static const bodyMedium = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Form field labels (DG-F05 size, SemiBold as in the Figma login page).
  static const fieldLabel = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// DG-F06: chips, links, small buttons.
  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// DG-F07: times, descriptions, helper text.
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// DG-F08: prices, always in Mocha.
  static const price = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.mocha,
  );

  /// Text on full-width buttons (DG-F03 size and weight).
  static const button = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
