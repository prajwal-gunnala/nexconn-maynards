import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Six PIN dots that shake when [shakeKey] changes.
class PinDots extends StatefulWidget {
  const PinDots({super.key, required this.length, this.max = 6, this.error = false, this.shakeKey = 0});

  final int length;
  final int max;
  final bool error;

  /// Bump to replay the shake.
  final int shakeKey;

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(PinDots old) {
    super.didUpdateWidget(old);
    if (old.shakeKey != widget.shakeKey) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UPI PIN, ${widget.length} of ${widget.max} digits entered',
      liveRegion: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final dx = _c.isAnimating ? math.sin(t * math.pi * 5) * 10 * (1 - t) : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.max; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.error
                      ? AppColors.danger.withValues(alpha: i < widget.length ? 1 : 0.0)
                      : i < widget.length
                          ? AppColors.ink
                          : Colors.transparent,
                  border: Border.all(
                    color: widget.error ? AppColors.danger : (i < widget.length ? AppColors.ink : AppColors.inkMuted.withValues(alpha: 0.5)),
                    width: 1.6,
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// 3×4 numeric keypad: 1–9, delete, 0, submit.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onDelete, required this.onSubmit, this.enabled = true, this.keyHeight = 52});

  /// 52 normally, smaller on short screens.
  final double keyHeight;

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// Null disables the ✓ key (fewer than 4 digits).
  final VoidCallback? onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key({required Widget child, required String label, VoidCallback? onTap, bool accent = false}) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            enabled: enabled && onTap != null,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: accent ? (onTap != null && enabled ? AppColors.brand : AppColors.line) : AppColors.canvas,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled && onTap != null
                      ? () {
                          HapticFeedback.selectionClick();
                          onTap();
                        }
                      : null,
                  child: SizedBox(height: keyHeight, child: Center(child: child)),
                ),
              ),
            ),
          ),
        );
    Widget digit(String d) => key(
          label: 'Digit $d',
          onTap: () => onDigit(d),
          child: Text(d, style: AppText.title.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(children: [for (final d in row) digit(d)]),
      Row(children: [
        key(label: 'Delete', onTap: onDelete, child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.ink)),
        digit('0'),
        key(
          label: 'Authorize hold',
          onTap: onSubmit,
          accent: true,
          child: Icon(Icons.check_rounded, size: 26, color: onSubmit != null && enabled ? Colors.white : AppColors.inkMuted),
        ),
      ]),
    ]);
  }
}
