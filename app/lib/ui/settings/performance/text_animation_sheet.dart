import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../performance/performance_state.dart';
import '../../chat/animated_composer_text.dart';
import '../../common/app_sheet.dart';
import '../../common/sheet_title_bar.dart';
import '../../theme/app_icons.dart';
import '../../theme/motion.dart';
import '../settings_widgets.dart';

class _PreviewField extends ConsumerStatefulWidget {
  const _PreviewField();

  @override
  ConsumerState<_PreviewField> createState() => _PreviewFieldState();
}

class _PreviewFieldState extends ConsumerState<_PreviewField> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(performancePrefsProvider);
    final animate = prefs.textAnimation && prefs.textAnimationEveryField && AppMotion.fluid(context);
    final style = theme.textTheme.bodyMedium!;

    final field = TextField(
      controller: _controller,
      maxLines: 1,
      showCursor: !animate,
      style: animate ? style.copyWith(color: Colors.transparent) : style,
      scrollController: animate ? _scroll : null,
      decoration: InputDecoration(
        hintText: l10n.performanceTextAnimationTryHint,
        hintStyle: style.copyWith(color: theme.colorScheme.onSurfaceVariant),
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.performanceTextAnimationTryHere, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: animate
              ? Stack(
                  children: [
                    field,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedComposerText(
                          controller: _controller,
                          style: style,
                          textPad: 8,
                          maxLines: 1,
                          textDirection: Directionality.of(context),
                          scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
                          cursorColor: theme.colorScheme.primary,
                          letterDuration: Duration(milliseconds: prefs.textAnimationSpeed),
                          slideDistance: prefs.textAnimationSlide,
                          deleteMode: prefs.textAnimationDelete,
                          cursorMode: prefs.textAnimationCursor,
                          animateLetters: prefs.textAnimationLetters,
                          slideUp: prefs.textAnimationSlideUp,
                          unblur: prefs.textAnimationUnblur,
                          pop: prefs.textAnimationPop,
                          tilt: prefs.textAnimationTilt,
                          trailEnabled: prefs.textAnimationTrail,
                          cursorSpeed: prefs.textAnimationCursorSpeed,
                          popStrength: prefs.textAnimationPopStrength,
                          tiltStrength: prefs.textAnimationTiltStrength,
                        ),
                      ),
                    ),
                  ],
                )
              : field,
        ),
      ],
    );
  }
}

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
                  const _PreviewField(),
                  section(l10n.performanceTextAnimationTyping),
                  SettingsSwitchTile(
                    icon: AppIcons.textSpeed,
                    title: l10n.performanceTextAnimationLetters,
                    subtitle: l10n.performanceTextAnimationLettersHint,
                    value: prefs.textAnimationLetters,
                    onChanged: (v) => unawaited(notifier.setTextAnimationLetters(v)),
                  ),
                  if (prefs.textAnimationLetters) ...[
                    SettingsSwitchTile(
                      icon: AppIcons.scrollToTop,
                      title: l10n.performanceTextAnimationSlideUp,
                      subtitle: l10n.performanceTextAnimationSlideUpHint,
                      value: prefs.textAnimationSlideUp,
                      onChanged: (v) => unawaited(notifier.setTextAnimationSlideUp(v)),
                    ),
                    SettingsSwitchTile(
                      icon: AppIcons.preview,
                      title: l10n.performanceTextAnimationUnblur,
                      subtitle: l10n.performanceTextAnimationUnblurHint,
                      value: prefs.textAnimationUnblur,
                      onChanged: (v) => unawaited(notifier.setTextAnimationUnblur(v)),
                    ),
                    SettingsSwitchTile(
                      icon: AppIcons.generateMedia,
                      title: l10n.performanceTextAnimationPop,
                      subtitle: l10n.performanceTextAnimationPopHint,
                      value: prefs.textAnimationPop,
                      onChanged: (v) => unawaited(notifier.setTextAnimationPop(v)),
                    ),
                    SettingsSwitchTile(
                      icon: AppIcons.refresh,
                      title: l10n.performanceTextAnimationTilt,
                      subtitle: l10n.performanceTextAnimationTiltHint,
                      value: prefs.textAnimationTilt,
                      onChanged: (v) => unawaited(notifier.setTextAnimationTilt(v)),
                    ),
                  ],
                  if (prefs.textAnimationLetters) section(l10n.performanceTextAnimationAdjust),
                  if (prefs.textAnimationLetters) ...[
                    sliderRow(
                      label: l10n.performanceTextAnimationSpeed,
                      value: prefs.textAnimationSpeed.toDouble(),
                      min: 120,
                      max: 900,
                      step: 20,
                      shown: '${prefs.textAnimationSpeed} ms',
                      onChanged: (v) => unawaited(notifier.setTextAnimationSpeed(v.round())),
                    ),
                    if (prefs.textAnimationSlideUp)
                      sliderRow(
                        label: l10n.performanceTextAnimationSlide,
                        value: prefs.textAnimationSlide,
                        min: 2,
                        max: 30,
                        step: 1,
                        shown: '${prefs.textAnimationSlide.round()} dp',
                        onChanged: (v) => unawaited(notifier.setTextAnimationSlide(v)),
                      ),
                    if (prefs.textAnimationPop)
                      sliderRow(
                        label: l10n.performanceTextAnimationPopStrength,
                        value: prefs.textAnimationPopStrength.toDouble(),
                        min: 25,
                        max: 200,
                        step: 5,
                        shown: '${prefs.textAnimationPopStrength}%',
                        onChanged: (v) => unawaited(notifier.setTextAnimationPopStrength(v.round())),
                      ),
                    if (prefs.textAnimationTilt)
                      sliderRow(
                        label: l10n.performanceTextAnimationTiltStrength,
                        value: prefs.textAnimationTiltStrength.toDouble(),
                        min: 25,
                        max: 200,
                        step: 5,
                        shown: '${prefs.textAnimationTiltStrength}%',
                        onChanged: (v) => unawaited(notifier.setTextAnimationTiltStrength(v.round())),
                      ),
                  ],
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
                    icon: AppIcons.edit,
                    title: l10n.performanceTextAnimationCursorGlide,
                    value: prefs.textAnimationCursor == TextAnimationCursor.glide,
                    onChanged: (v) => unawaited(notifier.setTextAnimationCursor(
                      v ? TextAnimationCursor.glide : TextAnimationCursor.steady,
                    )),
                  ),
                  if (prefs.textAnimationCursor == TextAnimationCursor.glide) ...[
                    SettingsSwitchTile(
                      icon: AppIcons.generateMedia,
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
                      step: 1,
                      shown: '${prefs.textAnimationCursorSpeed}',
                      onChanged: (v) => unawaited(notifier.setTextAnimationCursorSpeed(v.round())),
                    ),
                  ],
                  SettingsSwitchTile(
                    icon: AppIcons.webSearch,
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
