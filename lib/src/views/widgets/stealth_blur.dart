import 'dart:ui';
import 'package:flutter/material.dart';

/// Widget de proteção anti-olhares (Modo Furtivo).
/// Quando ativado, desfoca suavemente o conteúdo até que o usuário passe o mouse ou interaja.
class StealthBlur extends StatefulWidget {
  const StealthBlur({
    super.key,
    required this.enabled,
    required this.child,
    this.blurRadius = 5.5,
    this.replacementHint = 'Conteúdo protegido',
  });

  final bool enabled;
  final Widget child;
  final double blurRadius;
  final String replacementHint;

  @override
  State<StealthBlur> createState() => _StealthBlurState();
}

class _StealthBlurState extends State<StealthBlur> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onEnter: (_) => setState(() => _revealed = true),
      onExit: (_) => setState(() => _revealed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => setState(() => _revealed = true),
        onTapUp: (_) => setState(() => _revealed = false),
        onTapCancel: () => setState(() => _revealed = false),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _revealed
              ? widget.child
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: widget.blurRadius,
                    sigmaY: widget.blurRadius,
                  ),
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}
