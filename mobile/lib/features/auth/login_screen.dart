import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import 'package:dailyearn99/core/widgets/custom_text_field.dart';
import 'package:dailyearn99/core/widgets/premium_background.dart';
import 'package:dailyearn99/core/widgets/custom_otp_pin_field.dart';
import 'package:dailyearn99/core/widgets/otp_countdown_timer.dart';
import 'package:dailyearn99/core/widgets/terms_dialog.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/features/auth/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _otpSent = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(screenName: 'LoginScreen');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocListener<AppBloc, AppState>(
        listener: (context, state) {
          if (state.otpSentMessage != null && !_otpSent) {
            setState(() {
              _otpSent = true;
            });
            // Focus on OTP field immediately when it arrives
            Future.delayed(const Duration(milliseconds: 300), () {
              _otpFocusNode.requestFocus();
            });
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              SnackBar(
                content: Text(state.otpSentMessage!),
                backgroundColor: AppTheme.accentCyan,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<AppBloc>().add(ClearAuthMessageEvent());
          }
          if (state.authError != null) {
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
              SnackBar(
                content: Text(state.authError!),
                backgroundColor: AppTheme.accentRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<AppBloc>().add(ClearAuthMessageEvent());
          }
        },
        child: PremiumBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, anim) {
                    final isOtp =
                        child.key == const ValueKey("otp_verification_view");
                    final beginOffset = isOtp
                        ? const Offset(0.8, 0.0)
                        : const Offset(-0.8, 0.0);
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: beginOffset,
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: !_otpSent
                      ? _buildPhoneInputView(context)
                      : _buildOtpVerificationView(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone Input View ───────────────────────────────────────────────────────
  Widget _buildPhoneInputView(BuildContext context) {
    return Column(
      key: const ValueKey("phone_input_view"),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pulsing Logo Accent
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.accentPurple.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cardBg,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  children: const [
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
              Text(
                'SKILL-BASED REAL MONEY GAMING',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),

        // Glassmorphic Input Card
        Card(
          color: AppTheme.cardBg.withOpacity(0.65),
          shadowColor: Colors.black.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log In Account',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your phone number to request a secure OTP code.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 28),

                // Phone Input Field
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: 'Enter 10-digit number',
                  keyboardType: TextInputType.phone,
                  enabled: true,
                  prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                ),
                const SizedBox(height: 24),

                // Terms & Conditions Checkbox Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(unselectedWidgetColor: AppTheme.textMuted),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _termsAccepted,
                          activeColor: AppTheme.accentCyan,
                          checkColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final accepted = await TermsDialog.show(context);
                          if (accepted) {
                            setState(() {
                              _termsAccepted = true;
                            });
                          }
                        },
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                            children: const [
                              TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' & confirm I am 18+'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Submit Button
                BlocBuilder<AppBloc, AppState>(
                  builder: (context, state) {
                    return CustomButton(
                      text: 'GET VERIFICATION CODE',
                      isLoading: state.isAuthLoading,
                      onPressed: () => _requestOtp(context),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Switch to Sign Up
                Center(
                  child: TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12.5),
                        children: const [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Restricted States Legal text
        GestureDetector(
          onTap: () async {
            final accepted = await TermsDialog.show(context);
            if (accepted) {
              setState(() {
                _termsAccepted = true;
              });
            }
          },
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: AppTheme.textMuted,
                height: 1.6,
              ),
              children: const [
                TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(
                  text:
                      ' & age/state limits.\nRestricted States: Assam, Odisha, Sikkim, Nagaland.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── OTP Verification View ──────────────────────────────────────────────────
  Widget _buildOtpVerificationView(BuildContext context) {
    final formattedPhone = _phoneController.text.trim();

    return Column(
      key: const ValueKey("otp_verification_view"),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centered Pulsing Security Badge
        const Center(child: _PulsingSecurityIcon()),
        const SizedBox(height: 32),

        // Header Labels
        Center(
          child: Column(
            children: [
              Text(
                "Verification",
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent a 6-digit OTP code to",
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "+91 $formattedPhone",
                style: GoogleFonts.inter(
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  shadows: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Card Container for OTP Field & Button
        Card(
          color: AppTheme.cardBg.withOpacity(0.65),
          shadowColor: Colors.black.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Enter 6-Digit Code",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Separated glowing custom pin entry field
                CustomOtpPinField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  onCompleted: (otp) {
                    _verifyOtp(context, otp);
                  },
                ),
                const SizedBox(height: 28),

                // Manual submit trigger (optional fallback to keyboard submit)
                BlocBuilder<AppBloc, AppState>(
                  builder: (context, state) {
                    return CustomButton(
                      text: "VERIFY & LOG IN",
                      isLoading: state.isAuthLoading,
                      onPressed: () {
                        final otp = _otpController.text.trim();
                        if (otp.length < 6) {
                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid 6-digit OTP'),
                              backgroundColor: AppTheme.accentPurple,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _verifyOtp(context, otp);
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Sleek countdown and resend link
                OtpCountdownTimer(
                  onResend: () {
                    _resendOtp(context);
                  },
                ),
                const SizedBox(height: 12),

                // Back Link to change phone number
                Center(
                  child: TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      context.read<AppBloc>().add(ClearAuthMessageEvent());
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentCyan,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                    ),
                    child: Text(
                      'Change phone number',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentCyan.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper Actions ─────────────────────────────────────────────────────────

  void _requestOtp(BuildContext context) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          backgroundColor: AppTheme.accentPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_termsAccepted) {
      final accepted = await TermsDialog.show(context);
      if (accepted) {
        setState(() {
          _termsAccepted = true;
        });
      } else {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text(
              'You must agree to the Terms & Conditions to proceed',
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    context.read<AppBloc>().add(SendOtpEvent(phone, isRegister: false));
  }

  void _verifyOtp(BuildContext context, String otp) {
    final phone = _phoneController.text.trim();
    context.read<AppBloc>().add(VerifyOtpEvent(phone, otp));
  }

  void _resendOtp(BuildContext context) {
    final phone = _phoneController.text.trim();
    context.read<AppBloc>().add(SendOtpEvent(phone, isRegister: false));
  }
}

// ── Pulsing Security Badge Widget ───────────────────────────────────────────
class _PulsingSecurityIcon extends StatefulWidget {
  const _PulsingSecurityIcon();

  @override
  State<_PulsingSecurityIcon> createState() => _PulsingSecurityIconState();
}

class _PulsingSecurityIconState extends State<_PulsingSecurityIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accentCyan.withOpacity(0.08),
          border: Border.all(
            color: AppTheme.accentCyan.withOpacity(0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentCyan.withOpacity(0.12),
              blurRadius: 30,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Icon(
          Icons.security_rounded,
          color: AppTheme.accentCyan,
          size: 44,
        ),
      ),
    );
  }
}
