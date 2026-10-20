import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sharegari/core/router/app_router.dart';
import 'package:sharegari/core/theme/app_theme.dart';

/// Login / Phone-OTP screen (placeholder for Step 3).
///
/// Step 3 will replace this with real Supabase phone-OTP auth.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Logo / branding
              Text(
                'ShareGari',
                style: tt.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Shared rides for Dhaka commuters',
                style: tt.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),

              // Phone field (placeholder)
              TextField(
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixText: '+880 ',
                  hintText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // CTA
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Continue with OTP'),
              ),
              const SizedBox(height: 12),

              Text(
                'OTP verification coming in Step 3.',
                style: tt.bodySmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
