import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/forms/submit_state.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/labeled_text_field.dart';
import '../../core/widgets/loading_button.dart';
import '../../data/models/sign_up_request.dart';
import 'auth_controller.dart';
import 'widgets/auth_back_button.dart';
import 'widgets/auth_footer_link.dart';
import 'widgets/auth_status_view.dart';
import 'widgets/auth_title.dart';

/// SA 2.0 §4.2.1.2 Sign Up (Figma: 1.2_Sign-Up, 1.2_Sign-Up_Success).
///
/// A guest creates a customer account with an email or a phone number
/// (FR-02). After a short success message the new customer is signed in
/// and the router takes them to Home (TC-02).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SubmitStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _created = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// FR-02 asks for an email **or** a phone number, so each field is
  /// optional on its own but not both.
  String? _validateEmail(String? value) {
    final bothEmpty =
        (value?.trim().isEmpty ?? true) && _phoneController.text.trim().isEmpty;
    if (bothEmpty) return 'Enter an email or a phone number.';
    return validateOptionalEmail(value);
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authControllerProvider.notifier);
    final request = SignUpRequest(
      fullName: _nameController.text,
      email: _nullIfEmpty(_emailController),
      phone: _nullIfEmpty(_phoneController),
      password: _passwordController.text,
    );

    final ok = await runSubmit(() async {
      final user = await auth.createAccount(request);
      if (!mounted) return;
      setState(() => _created = true);
      await Future<void>.delayed(authStatusDisplayTime);
      // Signing in makes the router leave this page for Home.
      auth.startSession(user);
    });
    if (!ok && mounted) setState(() => _created = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_created) {
      return const Scaffold(
        body: AuthStatusView.success(message: 'Account created successfully.'),
      );
    }

    final error = submitError;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverList.list(
                  children: [
                    const AuthBackButton(),
                    const SizedBox(height: 24),
                    const AuthTitle(
                      title: 'Create account',
                      subtitle: 'Save your favourites and track every order.',
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'Full name',
                            hintText: 'Dara Sok',
                            controller: _nameController,
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: validateFullName,
                            onChanged: (_) => clearSubmitError(),
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: 16),
                          LabeledTextField(
                            label: 'Email',
                            hintText: 'dara@example.com',
                            controller: _emailController,
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: _validateEmail,
                            onChanged: (_) => clearSubmitError(),
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: 16),
                          LabeledTextField(
                            label: 'Phone number',
                            hintText: '012 345 678',
                            controller: _phoneController,
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: validateOptionalPhone,
                            onChanged: (_) => clearSubmitError(),
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: 16),
                          LabeledTextField(
                            label: 'Password',
                            hintText: 'At least $minPasswordLength characters',
                            controller: _passwordController,
                            icon: Icons.lock_outline,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: validateNewPassword,
                            onChanged: (_) => clearSubmitError(),
                            onFieldSubmitted: (_) => _createAccount(),
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
                      label: 'Create account',
                      isLoading: isSubmitting,
                      onPressed: _createAccount,
                    ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: AuthFooterLink(
                      prompt: 'Already have an account?',
                      action: 'Sign in',
                      onTap: isSubmitting
                          ? null
                          : () => AuthBackButton.goBack(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
