import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late FocusNode _effectiveFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // Only dispose if it was created locally
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _effectiveFocusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused
              ? AppTheme.accentCyan.withOpacity(0.8)
              : AppTheme.borderCol.withOpacity(0.5),
          width: _isFocused ? 1.5 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.12),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        enabled: widget.enabled,
        validator: widget.validator,
        onChanged: widget.onChanged,
        textCapitalization: widget.textCapitalization,
        maxLines: widget.maxLines,
        style: GoogleFonts.inter(
          color: widget.enabled ? AppTheme.textMain : AppTheme.textMuted,
          fontSize: 14.5,
        ),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: _isFocused ? AppTheme.accentCyan : AppTheme.textMuted,
                  ),
                  child: widget.prefixIcon!,
                )
              : null,
          suffixIcon: widget.suffixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: _isFocused ? AppTheme.accentCyan : AppTheme.textMuted,
                  ),
                  child: widget.suffixIcon!,
                )
              : null,
          labelStyle: TextStyle(
            color: _isFocused ? AppTheme.accentCyan : AppTheme.textMuted,
            fontSize: 13,
          ),
          hintStyle: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
          ),
          filled: false, // Background is handled by AnimatedContainer
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
