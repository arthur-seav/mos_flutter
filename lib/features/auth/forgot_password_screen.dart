import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/labeled_text_field.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/auth_status_view.dart';
import 'widgets/auth_title.dart';

/// SA 2.0 §4.2.1.3, step 1 (Figma: 1.3_input acc info to verify,
/// 1.3_Verify Account before reset password, 1.3_verify Account failed).
///
/// The customer enters their phone number; the app checks that an account
/// uses it before going to the new-password page. While checking, a
/// "Verifying account..." page with a Cancel button is shown.
/// An unknown number shows "Account not found." under the field (TC-06).
///
/// The SA plans an OTP step here once the app is in production.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _verifying = false;
  String? _phoneError;

  /// Increases on every attempt and on Cancel, so the answer to a
  /// cancelled attempt is ignored when it arrives later.
  int _attempt = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() => _phoneError = null);
    if (!_formKey.currentState!.validate()) return;

    final attempt = ++_attempt;
    setState(() => _verifying = true);
    try {
      final ticket = await ref
          .read(authControllerProvider.notifier)
          .verifyAccountForReset(phone: _phoneController.text);
      if (!mounted || attempt != _attempt) return;
      setState(() => _verifying = false);
      context.push(AppRoutes.resetPassword, extra: ticket);
    } on AuthException catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _verifying = false;
        _phoneError = e.message;
      });
    }
  }

  void _cancel() {
    setState(() {
      _attempt++;
      _verifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verifying) {
      return Scaffold(
        body: AuthStatusView.loading(
          message: 'Verifying account...',
          action: OutlinedButton(
            onPressed: _cancel,
            child: const Text('Cancel'),
          ),
        ),
      );
    }

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
                title: 'Forgot password',
                subtitle: 'Enter the phone number on your account.',
              ),
              const SizedBox(height: 24),
              LabeledTextField(
                label: 'Phone number',
                hintText: '012 345 678',
                controller: _phoneController,
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: validatePhone,
                errorText: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                onFieldSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _verify, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}
