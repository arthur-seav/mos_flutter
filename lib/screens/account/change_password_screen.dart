import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth/auth_controller.dart';
import '../../controllers/common/submit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/labeled_text_field.dart';
import '../../widgets/common/square_icon_button.dart';

/// SA 2.0 §4.2.5.3 Change Password while signed in (FR-30;
/// Figma: Change_Password).
///
/// The customer confirms the current password and types the new one twice.
/// The session stays, so on success the page just closes with a short
/// confirmation. A wrong current password keeps the page open with the
/// message from the server.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with SubmitStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await runSubmit(
      () => ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          ),
    );
    if (!ok || !mounted) return;

    // Taken before the page closes: afterwards this context is gone.
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Password changed.'), persist: false),
      );
  }

  @override
  Widget build(BuildContext context) {
    final error = submitError;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SquareIconButton(
                      icon: Icons.close,
                      tooltip: 'Cancel',
                      onPressed: isSubmitting ? null : () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Change Password',
                        style: AppTextStyles.title,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SquareIconButton(
                      icon: Icons.check,
                      tooltip: 'Save',
                      onPressed: isSubmitting ? null : _save,
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 20),
                  ErrorBanner(message: error),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      LabeledTextField(
                        label: 'Current Password',
                        controller: _currentController,
                        icon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        validator: validateRequiredPassword,
                        onChanged: (_) => clearSubmitError(),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'New Password',
                        hintText: 'At least $minPasswordLength characters',
                        controller: _newController,
                        icon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) =>
                            validateNewPassword(value) ??
                            validateDifferentPassword(
                              value,
                              current: _currentController.text,
                            ),
                        onChanged: (_) => clearSubmitError(),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Confirm New Password',
                        hintText: 'Type it again',
                        controller: _confirmController,
                        icon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) => validatePasswordConfirmation(
                          value,
                          password: _newController.text,
                        ),
                        onChanged: (_) => clearSubmitError(),
                        onFieldSubmitted: (_) => _save(),
                        enabled: !isSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
