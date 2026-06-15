import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';

enum CustomButtonType { primary, secondary, outline, danger }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final CustomButtonType type;
  final IconData? icon;
  final IconData? trailingIcon;
  final double? width;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Gradient? gradient;
  final BorderSide? borderSide;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.type = CustomButtonType.primary,
    this.icon,
    this.trailingIcon,
    this.width,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
    this.borderSide,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _animationController;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isEnabled
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              widget.onPressed!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double? targetWidth =
                widget.width ??
                (constraints.hasBoundedWidth ? double.infinity : null);
            return Container(
              width: targetWidth,
              height: widget.height,
              decoration: _buildDecoration(isEnabled),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Center(
                  child: widget.isLoading
                      ? _buildLoadingIndicator()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildContent(),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Decoration _buildDecoration(bool isEnabled) {
    if (!isEnabled) {
      return BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      );
    }

    if (widget.backgroundColor != null || widget.gradient != null) {
      return BoxDecoration(
        color: widget.gradient == null ? widget.backgroundColor : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.borderSide != null
            ? Border.fromBorderSide(widget.borderSide!)
            : null,
      );
    }

    switch (widget.type) {
      case CustomButtonType.primary:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentCyan, AppTheme.accentPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentCyan.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case CustomButtonType.secondary:
        return BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: AppTheme.borderCol),
        );
      case CustomButtonType.outline:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: AppTheme.accentCyan, width: 1.5),
        );
      case CustomButtonType.danger:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accentRed, Color(0xFFC62828)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentRed.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    final TextStyle textStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: _getTextColor(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: _getTextColor()),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: 18, color: _getTextColor()),
        ],
      ],
    );
  }

  Color _getTextColor() {
    if (widget.onPressed == null) {
      return AppTheme.textMuted;
    }

    if (widget.foregroundColor != null) {
      return widget.foregroundColor!;
    }

    switch (widget.type) {
      case CustomButtonType.primary:
        return Colors.white;
      case CustomButtonType.secondary:
        return AppTheme.textMain;
      case CustomButtonType.outline:
        return AppTheme.accentCyan;
      case CustomButtonType.danger:
        return Colors.white;
    }
  }
}
