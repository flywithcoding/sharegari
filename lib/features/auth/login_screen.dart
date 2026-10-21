import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';
import 'package:sharegari/features/auth/data/auth_repository.dart';

/// Email + password sign-in screen.
///
/// Uses email auth for development; phone OTP will replace this
/// once an SMS provider is configured.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 15-second timeout — avoids loading forever on network issues.
      final result = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => const AuthResult.failure(
              'Sign-in timed out. Check your internet connection and try again.',
            ),
          );

      // Log outcome for debugging.
      debugPrint('[Auth] signInWithEmail → '
          '${result.isSuccess ? "OK uid=${result.user?.id}" : "FAIL: ${result.error}"}');

      if (!mounted) return;

      if (result.isSuccess) {
        // Do NOT call context.go() here.
        // The GoRouter's refreshListenable is connected to authUserProvider
        // (a StreamProvider). When Supabase emits SIGNED_IN, authUserProvider
        // emits a non-null User, the notifier fires, and GoRouter's redirect
        // automatically sends the user to AppRoutes.home.
        //
        // Calling context.go() manually races with that redirect and can
        // cause double-navigation or override the redirect while isLoading
        // is still true (the old Android bug).
        //
        // We just clear the loading spinner here; navigation is handled
        // by the router.
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = result.error;
        });
      }
    } catch (e, st) {
      debugPrint('[Auth] Unexpected error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branding
                  Text('ShareGari', style: tt.displaySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Shared rides for Dhaka commuters',
                    style: tt.bodyMedium
                        ?.copyWith(color: AppColors.onSurfaceMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter your email';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.onSurfaceMuted,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error banner
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Sign-in button
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 14),

                  // Register
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.register),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Using email login for development.\nPhone OTP will be added later.',
                    style: tt.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
        color: AppColors.error.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
