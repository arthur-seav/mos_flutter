import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../controllers/account_verification_controller.dart';
import '../widgets/auth_back_button.dart';
import '../widgets/auth_status_view.dart';
import '../widgets/auth_title.dart';

/// SA 2.0 §4.2.1.3, step 1 (Figma: 1.3_input acc info to verify,
/// 1.3_Verify Account before reset password, 1.3_verify Account failed).
///
/// The customer enters their phone number; [AccountVerificationController]
/// checks it. This screen only draws the controller's state: the form, the
/// "Verifying account..." page, or the error under the field. Once verified,
/// it opens the new-password page.
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  AccountVerificationController get _controller =>
      ref.read(accountVerificationProvider.notifier);

  void _verify() {
    FocusScope.of(context).unfocus();
    _controller.reset();
    if (!_formKey.currentState!.validate()) return;
    _controller.verify(_phoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(accountVerificationProvider);

    ref.listen(accountVerificationProvider, (previous, next) {
      final ticket = next.ticket;
      if (ticket != null && previous?.ticket == null) {
        context.push(AppRoutes.resetPassword, extra: ticket);
        _controller.reset();
      }
    });

    if (verification.isVerifying) {
      return Scaffold(
        body: AuthStatusView.loading(
          message: 'Verifying account...',
          action: OutlinedButton(
            onPressed: _controller.cancel,
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
                errorText: verification.errorMessage,
                onChanged: (_) => _controller.reset(),
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
