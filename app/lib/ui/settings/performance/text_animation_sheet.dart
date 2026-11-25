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

    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(label, style: theme.textTheme.labelLarge),
    );

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
                  section(l10n.performanceTextAnimationTyping),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationLetters,
                    subtitle: l10n.performanceTextAnimationLettersHint,
                    value: prefs.textAnimationLetters,
                    onChanged: (v) => unawaited(notifier.setTextAnimationLetters(v)),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationSlideUp,
                    subtitle: l10n.performanceTextAnimationSlideUpHint,
                    value: prefs.textAnimationSlideUp,
                    onChanged: (v) => unawaited(notifier.setTextAnimationSlideUp(v)),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationUnblur,
                    subtitle: l10n.performanceTextAnimationUnblurHint,
                    value: prefs.textAnimationUnblur,
                    onChanged: (v) => unawaited(notifier.setTextAnimationUnblur(v)),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationPop,
                    subtitle: l10n.performanceTextAnimationPopHint,
                    value: prefs.textAnimationPop,
                    onChanged: (v) => unawaited(notifier.setTextAnimationPop(v)),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationTilt,
                    subtitle: l10n.performanceTextAnimationTiltHint,
                    value: prefs.textAnimationTilt,
                    onChanged: (v) => unawaited(notifier.setTextAnimationTilt(v)),
                  ),
                  section(l10n.performanceTextAnimationAdjust),
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
                  section(l10n.performanceTextAnimationDelete),
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
                  section(l10n.performanceTextAnimationCursor),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationCursorGlide,
                    value: prefs.textAnimationCursor == TextAnimationCursor.glide,
                    onChanged: (v) => unawaited(notifier.setTextAnimationCursor(
                      v ? TextAnimationCursor.glide : TextAnimationCursor.steady,
                    )),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationTrail,
                    subtitle: l10n.performanceTextAnimationTrailHint,
                    value: prefs.textAnimationTrail,
                    onChanged: (v) => unawaited(notifier.setTextAnimationTrail(v)),
                  ),
                  sliderRow(
                    label: l10n.performanceTextAnimationCursorSpeed,
                    value: prefs.textAnimationCursorSpeed.toDouble(),
                    min: 6,
                    max: 40,
                    step: 2,
                    shown: '${prefs.textAnimationCursorSpeed}',
                    onChanged: (v) => unawaited(notifier.setTextAnimationCursorSpeed(v.round())),
                  ),
                  SettingsSwitchTile(
                    title: l10n.performanceTextAnimationEveryField,
                    subtitle: l10n.performanceTextAnimationEveryFieldHint,
                    value: prefs.textAnimationEveryField,
                    onChanged: (v) => unawaited(notifier.setTextAnimationEveryField(v)),
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
