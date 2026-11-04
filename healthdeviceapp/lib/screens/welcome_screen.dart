import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Screen: Welcome / Get Started landing screen.
class WelcomeScreen extends StatelessWidget {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;

  const WelcomeScreen({
    super.key,
    required this.authRepository,
    required this.healthRepository,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : 28,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hardware Capsule Graphic
                  Container(
                    width: 72,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: AppTheme.cyan.withValues(alpha: 0.7),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyan.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.cyan.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: AppTheme.cyan,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'HealthDevice',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your personal wearable companion for heart rate, blood oxygen, posture coaching, and intelligent wellness guidance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 42),

                  // Get Started / Sign Up
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => SignUpScreen(
                              authRepository: authRepository,
                              healthRepository: healthRepository,
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlueLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Log In Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => LoginScreen(
                              authRepository: authRepository,
                              healthRepository: healthRepository,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.border,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'I Already Have an Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
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
