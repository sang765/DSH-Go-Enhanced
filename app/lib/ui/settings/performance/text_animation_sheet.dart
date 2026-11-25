import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../performance/performance_state.dart';
import '../../common/app_sheet.dart';
import '../../common/sheet_title_bar.dart';
import '../settings_widgets.dart';

Future<void> showTextAnimationSheet(BuildContext context) => showAppSheet<void>(
  context,
  dismissal: SheetDismissal.button,
  isScrollControlled: true,
  builder: (_) => const TextAnimationSheet(),
);

class TextAnimationSheet extends ConsumerWidget {
  const TextAnimationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(performancePrefsProvider);
    final notifier = ref.read(performancePrefsProvider.notifier);

    Widget sliderRow({
      required String label,
      required double value,
      required double min,
      required double max,
      required double step,
      required String shown,
      required ValueChanged<double> onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Text(shown, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Semantics(
            label: label,
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              label: shown,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitleBar(l10n.performanceTextAnimationOptions),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kSheetGutter, 8, kSheetGutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sliderRow(
                    label: l10n.performanceTextAnimationSpeed,
                    value: prefs.textAnimationSpeed.toDouble(),
                    min: 120,
                    max: 600,
                    step: 20,
                    shown: '${prefs.textAnimationSpeed} ms',
                    onChanged: (v) => unawaited(notifier.setTextAnimationSpeed(v.round())),
                  ),
                  sliderRow(
                    label: l10n.performanceTextAnimationSlide,
                    value: prefs.textAnimationSlide,
                    min: 0,
                    max: 24,
                    step: 2,
                    shown: '${prefs.textAnimationSlide.round()} dp',
                    onChanged: (v) => unawaited(notifier.setTextAnimationSlide(v)),
                  ),
                  SettingsSegmentTile<TextAnimationDelete>(
                    title: l10n.performanceTextAnimationDelete,
                    segments: [
                      PillSegment(TextAnimationDelete.fallAway, l10n.performanceTextAnimationDeleteFallAway),
                      PillSegment(TextAnimationDelete.dust, l10n.performanceTextAnimationDeleteDust),
                      PillSegment(TextAnimationDelete.none, l10n.performanceTextAnimationDeleteNone),
                    ],
                    selected: prefs.textAnimationDelete,
                    onChanged: (v) => unawaited(notifier.setTextAnimationDelete(v)),
                  ),
                  SettingsSegmentTile<TextAnimationCursor>(
                    title: l10n.performanceTextAnimationCursor,
                    segments: [
                      PillSegment(TextAnimationCursor.glide, l10n.performanceTextAnimationCursorGlide),
                      PillSegment(TextAnimationCursor.steady, l10n.performanceTextAnimationCursorSteady),
                    ],
                    selected: prefs.textAnimationCursor,
                    onChanged: (v) => unawaited(notifier.setTextAnimationCursor(v)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
