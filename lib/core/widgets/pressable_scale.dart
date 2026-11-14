import 'package:flutter/material.dart';
import 'package:sharegari/core/theme/app_motion.dart';

/// Wraps any widget to give it a subtle, bouncy press animation
/// (scales down to 0.97 on press and quickly springs back on release).
///
/// Can either handle the tap directly via [onTap], or wrap an existing
/// interactive widget (like an [ElevatedButton]) using pointer listeners.
/// Respects reduced motion settings.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.isReducedMotion(context)) {
      if (widget.onTap != null) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: widget.child,
        );
      }
      return widget.child;
    }

    Widget content = AnimatedScale(
      scale: _isPressed ? widget.scaleDown : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.stateChangeCurve,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: content,
      );
    }

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: content,
    );
  }
}
