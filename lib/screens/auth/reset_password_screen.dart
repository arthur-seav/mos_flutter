import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/common/submit_state.dart';
import '../../utils/validators.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/labeled_text_field.dart';
import '../../widgets/common/loading_button.dart';
import '../../data/repositories/auth_repository.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../widgets/auth/auth_back_button.dart';
import '../../widgets/auth/auth_status_view.dart';
import '../../widgets/auth/auth_title.dart';

/// SA 2.0 §4.2.1.3, step 2 (Figma: 1.3_Reset-Password,
/// 1.3_Reset-Password_Success).
///
/// The customer types the new password twice. After a short success
/// message the app returns to the login page, where the new password
/// works and the old one does not (TC-05).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.ticket});

  /// From the verify step; proves which account is being reset.
  final PasswordResetTicket ticket;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SubmitStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _done = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await runSubmit(
      () => ref
          .read(authControllerProvider.notifier)
          .resetPassword(
            ticket: widget.ticket,
            newPassword: _passwordController.text,
          ),
    );
    if (!ok || !mounted) return;

    setState(() => _done = true);
    await Future<void>.delayed(authStatusDisplayTime);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return const Scaffold(
        body: AuthStatusView.success(message: 'Password reset successful.'),
      );
    }

    final error = submitError;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const AuthBackButton(),
              const SizedBox(height: 72),
              const AuthTitle(
                title: 'New password',
                subtitle: 'Choose a new password for your account.',
              ),
              const SizedBox(height: 24),
              AutofillGroup(
                child: Column(
                  children: [
                    LabeledTextField(
                      label: 'New password',
                      hintText: 'At least $minPasswordLength characters',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: validateNewPassword,
                      onChanged: (_) => clearSubmitError(),
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    LabeledTextField(
                      label: 'Confirm password',
                      hintText: 'Type it again',
                      controller: _confirmController,
                      icon: Icons.lock_outline,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (value) => validatePasswordConfirmation(
                        value,
                        password: _passwordController.text,
                      ),
                      onChanged: (_) => clearSubmitError(),
                      onFieldSubmitted: (_) => _reset(),
                      enabled: !isSubmitting,
                    ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: error),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Continue',
                isLoading: isSubmitting,
                onPressed: _reset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
