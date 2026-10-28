import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// A form field with its label above it and an icon inside,
/// as used on the login, sign-up and profile screens.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;

  /// An error that comes from outside the field's [validator], such as
  /// "Account not found." from the server. Shown until it is cleared.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          enabled: enabled,
          forceErrorText: errorText,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}
