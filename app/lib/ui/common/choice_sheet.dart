// The app's one-choice sheet: a glass bottom sheet with an icon, a subtitle
// and a tick on the current value. Form controls and feature pages share it
// instead of falling back to the platform's flat dropdown overlay.

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'app_sheet.dart';
import 'list_page_row.dart';
import 'sheet_title_bar.dart';

/// One row of [showChoiceSheet].
class Choice<T> {
  const Choice(this.value, this.title, {this.subtitle, this.icon, this.meta});

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? meta;
}

/// A titled list of choices; pops with the tapped value.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<Choice<T>> choices,
  required T selected,
}) => showAppSheet<T>(
  context,
  isScrollControlled: true,
  builder: (sheet) {
    final max = MediaQuery.sizeOf(sheet).height * 0.62;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitleBar(title),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: max),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: SheetGroup(
                children: [
                  for (final c in choices)
                    Semantics(
                      selected: c.value == selected,
                      inMutuallyExclusiveGroup: true,
                      child: ListPageRow(
                        icon: c.icon,
                        title: c.title,
                        subtitle: c.subtitle,
                        meta: c.value == selected ? null : c.meta,
                        trailing: c.value == selected ? const SelectedMark() : null,
                        chevron: false,
                        onTap: () => Navigator.pop(sheet, c.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  },
);

/// The check at the end of the chosen row.
class SelectedMark extends StatelessWidget {
  const SelectedMark({super.key});

  @override
  Widget build(BuildContext context) => Icon(AppIcons.selected, size: 20, color: Theme.of(context).colorScheme.primary);
}
