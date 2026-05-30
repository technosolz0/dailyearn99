import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:target99/core/theme/app_theme.dart';

class PremiumBackground extends StatefulWidget {
  final Widget child;

  const PremiumBackground({super.key, required this.child});

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A very slow, 15-second ambient loop for the background orbs
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. Deep Gradient Back-Layer
        Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkBg,
                Color(0xFF0E1325),
                Color(0xFF070A12),
              ],
            ),
          ),
        ),

        // 2. Ambient Floating Orbs (Shifting dynamically)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            
            // Generate oscillating position offsets
            final dx1 = size.width * 0.75 + math.sin(t * math.pi) * 60;
            final dy1 = size.height * 0.2 + math.cos(t * math.pi) * 40;

            final dx2 = size.width * 0.15 - math.cos(t * math.pi) * 50;
            final dy2 = size.height * 0.75 - math.sin(t * math.pi) * 70;

            final dx3 = size.width * 0.5 + math.sin(t * math.pi * 2) * 40;
            final dy3 = size.height * 0.45 + math.cos(t * math.pi * 2) * 50;

            return Stack(
              children: [
                // Cyan Orb (Top Right area)
                _buildOrb(
                  dx: dx1,
                  dy: dy1,
                  radius: 140,
                  color: AppTheme.accentCyan.withOpacity(0.12),
                ),
                // Purple Orb (Bottom Left area)
                _buildOrb(
                  dx: dx2,
                  dy: dy2,
                  radius: 160,
                  color: AppTheme.accentPurple.withOpacity(0.08),
                ),
                // Intermediate glowing accent (Middle Right)
                _buildOrb(
                  dx: dx3,
                  dy: dy3,
                  radius: 120,
                  color: AppTheme.accentCyan.withOpacity(0.05),
                ),
              ],
            );
          },
        ),

        // 3. Backdrop Filter for Ultra-Smooth Glassmorphic Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 95.0, sigmaY: 95.0),
            child: const SizedBox.shrink(),
          ),
        ),

        // 4. Foreground Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }

  Widget _buildOrb({
    required double dx,
    required double dy,
    required double radius,
    required Color color,
  }) {
    return Positioned(
      left: dx - radius,
      top: dy - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
