import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/labeled_text_field.dart';
import '../../core/widgets/or_divider.dart';
import 'auth_controller.dart';
import 'widgets/brand_header.dart';

/// SA 2.0 §4.2.1.1 Login (Figma: 1.1_Login).
///
/// Customers sign in, or continue as a guest (FR-01, FR-03).
/// Where to go next is decided by the router: once [AuthController] has a
/// session, the router leaves this page by itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final auth = context.read<AuthController>();
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await auth.signIn(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );
  }

  void _showNotReady(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature is coming in a later step.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                sliver: SliverList.list(
                  children: [
                    const BrandHeader(),
                    const SizedBox(height: 32),
                    const Text('Welcome back', style: AppTextStyles.pageTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to order ahead and skip the queue.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'Email',
                            hintText: 'Email or phone number',
                            controller: _identifierController,
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.telephoneNumber,
                            ],
                            validator: validateEmailOrPhone,
                            onChanged: (_) => auth.clearError(),
                            enabled: !auth.isBusy,
                          ),
                          const SizedBox(height: 20),
                          LabeledTextField(
                            label: 'Password',
                            hintText: 'Password',
                            controller: _passwordController,
                            icon: Icons.lock_outline,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: validateRequiredPassword,
                            onChanged: (_) => auth.clearError(),
                            onFieldSubmitted: (_) => _signIn(),
                            enabled: !auth.isBusy,
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: () => _showNotReady('Password reset'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: auth.errorMessage!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _signIn,
                      child: auth.isBusy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onBrand,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 20),
                    const OrDivider(),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: auth.isBusy ? null : auth.continueAsGuest,
                      child: const Text('Continue as guest'),
                    ),
                  ],
                ),
              ),
              // Keeps "New here?" at the bottom of tall screens, and below
              // the form when the keyboard is open.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: _SignUpPrompt(onTap: () => _showNotReady('Sign up')),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New here?',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        TextButton(onPressed: onTap, child: const Text('Create an account')),
      ],
    );
  }
}
