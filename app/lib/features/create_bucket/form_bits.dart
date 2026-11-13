import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// White form section card with a heading and optional helper line.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, this.helper, required this.children, this.trailing});

  final String title;
  final String? helper;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: AppText.heading)),
              if (helper != null) ...[
                const SizedBox(height: 2),
                Text(helper!, style: AppText.caption),
              ],
            ]),
          ),
          ?trailing,
        ]),
        const SizedBox(height: AppSpace.lg),
        ...children,
      ]),
    );
  }
}

/// Label + text field. Money fields get a ₹ prefix; numbers get a digits-only keyboard.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.prefix,
    this.suffix,
    this.number = false,
    this.decimal = false,
    this.onChanged,
    this.maxLength,
    this.textCapitalization = TextCapitalization.sentences,
    this.fieldKey,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final String? prefix;
  final String? suffix;
  final bool number;
  final bool decimal;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: AppText.label.copyWith(color: AppColors.inkMuted)),
      const SizedBox(height: 6),
      TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        maxLength: maxLength,
        textCapitalization: number ? TextCapitalization.none : textCapitalization,
        keyboardType: number ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'))]
            : null,
        style: number ? AppText.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]) : AppText.body,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          counterText: '',
          isDense: true,
          prefixText: prefix,
          prefixStyle: AppText.body.copyWith(fontWeight: FontWeight.w700),
          suffixText: suffix,
          suffixStyle: AppText.bodyMuted,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

/// Pill choice chip, 40 px tall with a 48 px tap target.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: selected ? AppColors.brand : AppColors.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.inkMuted),
                const SizedBox(width: 6),
              ],
              Text(label, style: AppText.label.copyWith(color: selected ? Colors.white : AppColors.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A row of [ChoicePill]s that wraps.
class PillWrap extends StatelessWidget {
  const PillWrap({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: AppSpace.sm, runSpacing: 0, children: children);
}

/// Tappable read-only value tile (date/time pickers).
class PickerTile extends StatelessWidget {
  const PickerTile({super.key, required this.label, required this.value, this.hint, required this.icon, required this.onTap, this.error});

  final String label;
  final String value;
  final String? hint;
  final IconData icon;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final border = error != null ? AppColors.danger : AppColors.line;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        button: true,
        label: '$label, $value. Change',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: AppColors.brandDeep),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              if (hint != null) Text(hint!, style: AppText.caption.copyWith(color: AppColors.brandDeep)),
              const SizedBox(width: 4),
              const Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.inkMuted),
            ]),
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 6),
          child: Text(error!, style: AppText.caption.copyWith(color: AppColors.danger)),
        ),
    ]);
  }
}

/// Small round icon button with a 48 px target.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, required this.semantic, this.color = AppColors.inkMuted});
  final IconData icon;
  final VoidCallback? onTap;
  final String semantic;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: semantic,
        icon: Icon(icon, size: 20, color: onTap == null ? AppColors.line : color),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      );
}

/// Inline "+ Add tier" style action.
class AddRowButton extends StatelessWidget {
  const AddRowButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
          color: AppColors.brandTint.withValues(alpha: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 18, color: onTap == null ? AppColors.inkMuted : AppColors.brandDeep),
          const SizedBox(width: 6),
          Text(label, style: AppText.label.copyWith(color: onTap == null ? AppColors.inkMuted : AppColors.brandDeep)),
        ]),
      ),
    );
  }
}
