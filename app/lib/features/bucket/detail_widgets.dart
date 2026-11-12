import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Tabular figures so money and counters don't jitter while they animate.
const tabular = [FontFeature.tabularFigures()];

extension TabularText on TextStyle {
  TextStyle get tab => copyWith(fontFeatures: tabular);
}

/// Stable, friendly colour per person (owner dots, avatars).
Color personColor(String seed) {
  const palette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFF59E0B),
    Color(0xFF16A34A),
    Color(0xFF6366F1),
    Color(0xFFEA580C),
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

/// Round initial avatar with a white ring (for stacks).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 32, this.ring = true, this.color});

  final String name;
  final double size;
  final bool ring;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? personColor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: AppColors.surface, width: 2) : null,
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: AppText.label.copyWith(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w800, height: 1),
      ),
    );
  }
}

/// Overlapping avatars + "Meera, Ravi and 5 others".
class MembersStrip extends StatelessWidget {
  const MembersStrip({super.key, required this.names, required this.total, this.meName, this.trailing});

  /// Display names; the current member is passed as `you` (lower case).
  final List<String> names;

  /// Total members (may exceed [names]).
  final int total;
  final String? meName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(4).toList();
    final others = total - (names.length >= 2 ? 2 : names.length);
    final firstTwo = names.take(2).join(', ');
    final text = total == 0
        ? 'Be the first neighbour in'
        : names.length <= 2 && others <= 0
            ? (names.length == 2 ? names.join(' and ') : names.first)
            : '$firstTwo and $others ${others == 1 ? 'other' : 'others'}';
    return Semantics(
      label: '$total neighbours in: $text',
      excludeSemantics: true,
      child: Row(children: [
        if (shown.isNotEmpty)
          SizedBox(
            width: 32.0 + (shown.length - 1) * 22,
            height: 32,
            child: Stack(children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * 22.0,
                  child: shown[i] == 'you'
                      ? PersonAvatar(name: meName ?? 'You', color: AppColors.brand)
                      : PersonAvatar(name: shown[i]),
                ),
            ]),
          ),
        if (shown.isNotEmpty) const SizedBox(width: AppSpace.sm),
        Expanded(
          child: LiveText(text, style: AppText.label),
        ),
        ?trailing,
      ]),
    );
  }
}

/// White card with a 1px line border (radius 16).
class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpace.lg), this.color, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: borderColor ?? AppColors.line),
        ),
        child: child,
      );
}

/// `title` 16/700 + optional muted subtitle, above a section's content.
class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.heading.copyWith(fontSize: 17)),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppText.caption)],
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// Text that cross-fades when its value changes (live numbers).
class LiveText extends StatelessWidget {
  const LiveText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        layoutBuilder: (current, previous) => Stack(
          alignment: switch (textAlign) {
            TextAlign.right || TextAlign.end => Alignment.centerRight,
            TextAlign.center => Alignment.center,
            _ => Alignment.centerLeft,
          },
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: child),
        ),
        child: Text(text, key: ValueKey(text), style: style.tab, textAlign: textAlign),
      );
}

/// − qty + stepper, 48 px tap targets.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.label,
    required this.onMinus,
    required this.onPlus,
    this.semanticsLabel,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String? semanticsLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback? on, String tip) => Semantics(
          button: true,
          label: tip,
          child: InkResponse(
            onTap: on,
            radius: 24,
            child: SizedBox(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              child: Icon(icon, size: 20, color: on == null ? AppColors.line : AppColors.brandDeep),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove_rounded, onMinus, 'Less'),
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: compact ? 44 : 56),
          child: Semantics(
            label: semanticsLabel ?? label,
            child: LiveText(label, style: AppText.heading.copyWith(color: AppColors.brandDeep, fontSize: compact ? 14 : 16), textAlign: TextAlign.center),
          ),
        ),
        btn(Icons.add_rounded, onPlus, 'More'),
      ]),
    );
  }
}

/// Selectable pill chip (option groups, slots). 48 px tall tap area.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandTint : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: selected ? AppColors.brand : AppColors.line, width: selected ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: AppColors.brandDeep),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 4),
              ],
              Text(label, style: AppText.label.copyWith(color: selected ? AppColors.brandDeep : AppColors.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Option group (cut style, slot...) as a wrap of [ChoicePill]s.
class OptionPills extends StatelessWidget {
  const OptionPills({super.key, required this.label, required this.choices, required this.value, required this.onChanged});

  final String label;
  final List<String> choices;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.label),
      const SizedBox(height: AppSpace.xs),
      Wrap(spacing: AppSpace.sm, children: [
        for (final c in choices) ChoicePill(label: c, selected: c == value, onTap: () => onChanged(c)),
      ]),
    ]);
  }
}

/// Ticks every 30 s and rebuilds with the time left to [cutoff].
class CountdownBuilder extends StatefulWidget {
  const CountdownBuilder({super.key, required this.cutoff, required this.builder});

  final DateTime cutoff;
  final Widget Function(BuildContext context, Duration left) builder;

  @override
  State<CountdownBuilder> createState() => _CountdownBuilderState();
}

class _CountdownBuilderState extends State<CountdownBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.cutoff.difference(DateTime.now()));
}

/// `Closes in 2h 15m` / `Closes Sat 8:00 pm`.
String closesText(DateTime cutoff, Duration left) {
  if (left.isNegative) return 'Closing now';
  if (left.inHours >= 24) return 'Closes ${Fmt.dayTime(cutoff)}';
  return 'Closes in ${Fmt.timeLeft(cutoff).replaceAll(' left', '')}';
}

/// "Sat 8 pm" style short time used in copy.
String shortWhen(DateTime t) {
  final l = t.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(l.year, l.month, l.day);
  final diff = d.difference(today).inDays;
  final time = Fmt.time(l).replaceAll(':00', '');
  if (diff == 0) return 'today $time';
  if (diff == 1) return 'tomorrow $time';
  return '${Fmt.day(l).split(' ').first} $time';
}

/// Type badge text ("Split", "Bulk", ...).
String typeLabel(Bucket b) => switch (b.type) {
      BucketType.split => b.settleMode == PayMode.atMarket ? 'Book & meet' : 'Split',
      BucketType.bulk => 'Bulk',
      BucketType.service => 'Service',
      BucketType.trip => 'Market trip',
      BucketType.unknown => 'Bucket',
    };

IconData typeIcon(BucketType t) => switch (t) {
      BucketType.split => Icons.pie_chart_outline_rounded,
      BucketType.bulk => Icons.inventory_2_outlined,
      BucketType.service => Icons.home_repair_service_outlined,
      BucketType.trip => Icons.local_shipping_outlined,
      BucketType.unknown => Icons.shopping_basket_outlined,
    };

/// Grey shimmer-free placeholder block for the loading skeleton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(radius)),
      );
}
