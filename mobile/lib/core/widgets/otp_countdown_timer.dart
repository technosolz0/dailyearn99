import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:target99/core/theme/app_theme.dart';

class OtpCountdownTimer extends StatefulWidget {
  final VoidCallback onResend;
  final int durationInSeconds;

  const OtpCountdownTimer({
    super.key,
    required this.onResend,
    this.durationInSeconds = 60,
  });

  @override
  State<OtpCountdownTimer> createState() => _OtpCountdownTimerState();
}

class _OtpCountdownTimerState extends State<OtpCountdownTimer> {
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = widget.durationInSeconds;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
        _timer?.cancel();
      }
    });
  }

  void _handleResend() {
    if (_canResend) {
      widget.onResend();
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: _canResend
          ? Row(
              key: const ValueKey("resend_active"),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive code? ",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13.5,
                  ),
                ),
                GestureDetector(
                  onTap: _handleResend,
                  child: Text(
                    "Resend OTP",
                    style: GoogleFonts.inter(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.accentCyan,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              key: const ValueKey("timer_active"),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Resend code in ",
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13.5,
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    shadows: [
                      BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text("${_secondsRemaining}s"),
                ),
              ],
            ),
    );
  }
}
