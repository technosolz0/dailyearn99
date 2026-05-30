import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:target99/core/theme/app_theme.dart';

class CustomOtpPinField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onCompleted;

  const CustomOtpPinField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onCompleted,
  });

  @override
  State<CustomOtpPinField> createState() => _CustomOtpPinFieldState();
}

class _CustomOtpPinFieldState extends State<CustomOtpPinField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.controller.text.length == 6 && widget.onCompleted != null) {
      widget.onCompleted!(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.focusNode]),
      builder: (context, _) {
        final text = widget.controller.text;

        return GestureDetector(
          onTap: () {
            if (!widget.focusNode.hasFocus) {
              widget.focusNode.requestFocus();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Invisible text field that captures all keyboard inputs
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 1), // extremely tiny text
                  ),
                ),
              ),

              // 2. High-fidelity UI Rendering
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFocused =
                      widget.focusNode.hasFocus && text.length == index;
                  final hasChar = index < text.length;
                  final char = hasChar ? text[index] : "";

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 56,
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppTheme.accentCyan.withOpacity(0.06)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused
                              ? AppTheme.accentCyan
                              : hasChar
                              ? Colors.white.withOpacity(0.3)
                              : AppTheme.borderCol.withOpacity(0.5),
                          width: isFocused ? 1.8 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentCyan.withOpacity(0.25),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isFocused
                            ? const _BlinkingCursor()
                            : Text(
                                char,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animController,
      child: Container(width: 2.2, height: 24, color: AppTheme.accentCyan),
    );
  }
}
