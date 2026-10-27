import 'package:flutter/material.dart';

/// Theme colors from SA 2.0, section 4.1.2 (DG-C01 to DG-C14).
///
/// Widgets should read colors from here (or from the [ThemeData] built in
/// `app_theme.dart`) instead of writing hex codes inline, so a palette change
/// only happens in one place.
abstract final class AppColors {
  // Background
  static const canvas = Color(0xFFF7F1EA); // DG-C01 page background
  static const surface = Color(0xFFFFFFFF); // DG-C02 cards
  static const muted = Color(0xFFEFE5DA); // DG-C03 tags, icon backgrounds

  // Brand
  static const espresso = Color(0xFF3B2418); // DG-C04 main buttons
  static const mocha = Color(0xFF6B4430); // DG-C05 prices and icons
  static const caramel = Color(0xFFC8834A); // DG-C06 accents, links
  static const latte = Color(0xFFE9D3BC); // DG-C07 image bg, selected tab
  static const border = Color(0xFFE3D6C8); // DG-C08

  // Status
  static const success = Color(0xFF4F7A4A); // DG-C09
  static const successBg = Color(0xFFE4EEDD); // DG-C10
  static const danger = Color(0xFFB4473A); // DG-C11

  // Text
  static const textPrimary = Color(0xFF2A1A12); // DG-C12
  static const textSecondary = Color(0xFF7A6355); // DG-C13
  static const onBrand = Color(0xFFFFF8F1); // DG-C14 text on dark backgrounds
}
