import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_routes.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/labeled_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/or_divider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_title.dart';
import '../widgets/brand_header.dart';

/// SA 2.0 §4.2.1.1 Login (Figma: 1.1_Login).
///
/// Customers sign in, or continue as a guest (FR-01, FR-03).
/// Where to go next is decided by the router: once [authControllerProvider]
/// has a session, the router leaves this page by itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SubmitStateMixin {
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await runSubmit(
      () => ref
          .read(authControllerProvider.notifier)
          .signIn(
            identifier: _identifierController.text,
            password: _passwordController.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = submitError;

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
                    const AuthTitle(
                      title: 'Welcome back',
                      subtitle: 'Sign in to order ahead and skip the queue.',
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
                            onChanged: (_) => clearSubmitError(),
                            enabled: !isSubmitting,
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
                            onChanged: (_) => clearSubmitError(),
                            onFieldSubmitted: (_) => _signIn(),
                            enabled: !isSubmitting,
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => context.push(AppRoutes.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      ErrorBanner(message: error),
                    ],
                    const SizedBox(height: 20),
                    LoadingButton(
                      label: 'Sign in',
                      isLoading: isSubmitting,
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: 20),
                    const OrDivider(),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : ref
                                .read(authControllerProvider.notifier)
                                .continueAsGuest,
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
                    child: AuthFooterLink(
                      prompt: 'New here?',
                      action: 'Create an account',
                      onTap: isSubmitting
                          ? null
                          : () => context.push(AppRoutes.signUp),
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
