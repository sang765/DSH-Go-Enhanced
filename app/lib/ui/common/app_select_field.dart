// A form control that picks one value from the app's choice sheet.
//
// It looks like the dialog's text fields (same InputDecoration) but opens the
// glass bottom sheet instead of the platform dropdown overlay: the menu never
// covers a dialog's buttons, and the current value gets an icon and a tick.
// T is non-null: a cancelled sheet returns null and leaves the value alone.

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'choice_sheet.dart';
import 'pressable.dart';

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.selected,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final T selected;
  final List<Choice<T>> choices;
  final ValueChanged<T> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showChoiceSheet<T>(context, title: label, choices: choices, selected: selected);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    Choice<T>? current;
    for (final choice in choices) {
      if (choice.value == selected) {
        current = choice;
        break;
      }
    }
    final title = current?.title ?? '';
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(labelText: label),
      child: SizedBox(
        height: 24,
        child: Pressable(
          onTap: () => _pick(context),
          semanticLabel: '$label: $title',
          child: Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.expand, size: 18, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
