import 'package:flutter/material.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;

  const SplashScreen({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkBg, Color(0xFF0F1426)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Premium branding logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                  children: [
                    TextSpan(
                      text: 'DailyEarn',
                      style: TextStyle(color: AppTheme.accentCyan),
                    ),
                    TextSpan(
                      text: '99',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SKILL-BASED REAL MONEY GAMING',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 48),
              if (error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Initialization failed: $error',
                    style: const TextStyle(
                      color: AppTheme.accentRed,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
              ] else
                const CircularProgressIndicator(color: AppTheme.accentCyan),
            ],
          ),
        ),
      ),
    );
  }
}
