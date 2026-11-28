// The page sheet feel: while a sheet is up, the page under it sits back a little, its corners round
// off and the status bar turns light over the dark edge that shows. It follows the sheet, finger
// included. On the fluid tier and on phones only, on iOS and Android; nothing on desktop or web.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'motion.dart';
import 'shapes.dart';

bool get _available =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

/// Sheets take over the whole screen's attention on a phone. A tablet's float in the middle and
/// leave the page where it is, as the system's do.
bool _sitsBack(BuildContext context) => AppMotion.fluid(context) && MediaQuery.sizeOf(context).shortestSide < 600;

/// How far the open sheets have the page sat back, from 0 to 1.
abstract final class SheetRecede {
  /// How small the page gets, all the way back. Mochy's RecedeScale.
  static const scale = 0.9;

  /// Mochy's MenuEasing (CubicBezier 0.57, 0.53, 0, 1), used for its 440 ms
  /// sheet presence. The sheet here rises in 380 ms, so the keyframe weights
  /// keep the same shape on our shorter clock.
  static const _mochyEase = Cubic(0.57, 0.53, 0, 1);

  /// Three keyframes shaped after Mochy's no-bounce, low-stiffness spring:
  /// the page slips back as the sheet clears the bottom, coasts through the
  /// middle, then lands softly. The sheet's own curve comes from its animation
  /// style; this times the page separately instead of riding in lockstep.
  static final _recedeFrames = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 0.62).chain(CurveTween(curve: _mochyEase)),
      weight: 44,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.62, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 36,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
  ]);

  /// Mochy's PopupSpring visibilityThreshold: don't snap the last fraction of
  /// a percent, which shows up as a hitch right as the sheet settles.
  static const _settleEpsilon = 0.0005;

  static final _routes = <ModalRoute<dynamic>>{};
  static final _amount = ValueNotifier<double>(0);

  @visibleForTesting
  static ValueListenable<double> get amount => _amount;

  /// How small a sheet gets while another route sits on top of it. The page
  /// recedes under any sheet; a sheet only under something above itself.
  static const coveredScale = 0.95;

  static final _covered = <ModalRoute<dynamic>, ValueNotifier<double>>{};
  static final _coverSources = <ModalRoute<dynamic>, Animation<double>>{};
  static final _coverListeners = <ModalRoute<dynamic>, void Function()>{};

  /// A sheet's own recede, driven by whatever is currently pushed above it.
  static ValueNotifier<double> coveredFor(ModalRoute<dynamic> route) =>
      _covered.putIfAbsent(route, () => ValueNotifier(0));

  /// Called by an app sheet's route when the route above it changes. The lower
  /// sheet follows the upper route's own animation so the two move together.
  static void onNextChanged(ModalRoute<dynamic> route, Route<dynamic>? next) {
    final notifier = coveredFor(route);
    final previous = _coverSources.remove(route);
    final previousListener = _coverListeners.remove(route);
    if (previous != null && previousListener != null) previous.removeListener(previousListener);

    final upper = next is ModalRoute<dynamic> ? next : null;
    final animation = upper?.animation;
    if (animation == null) {
      notifier.value = 0;
      return;
    }
    void sync() {
      // On the way out the upper route stops being current before its
      // animation unwinds; keep following it or the lower sheet jumps back.
      if (upper!.isCurrent || animation.status == AnimationStatus.reverse) {
        notifier.value = animation.value;
      }
    }

    _coverSources[route] = animation;
    _coverListeners[route] = sync;
    animation.addListener(sync);
    sync();
  }

  /// Drops every observation held for a sheet whose route is gone.
  static void forget(ModalRoute<dynamic> route) {
    final previous = _coverSources.remove(route);
    final previousListener = _coverListeners.remove(route);
    if (previous != null && previousListener != null) previous.removeListener(previousListener);
    _covered.remove(route)?.dispose();
  }

  static void _update() {
    var most = 0.0;
    for (final route in _routes) {
      // A sheet under a pushed screen is not current any more. Its animation
      // stays completed, so ignoring it brings the old page back to full size.
      // A popping route is also not current, but its animation is reversing:
      // keep following that, or the page snaps back instead of growing with
      // the sheet as it goes down.
      final animation = route.animation;
      if (animation == null) continue;
      if (!route.isCurrent && animation.status != AnimationStatus.reverse) continue;
      most = math.max(most, animation.value);
    }
    final progress = most.clamp(0.0, 1.0);
    _amount.value = progress < _settleEpsilon
        ? 0
        : progress > 1 - _settleEpsilon
            ? 1
            : _recedeFrames.transform(progress);
  }

  static void _add(ModalRoute<dynamic> route) {
    if (_routes.add(route)) route.animation?.addListener(_update);
    // A sheet comes and goes during a build, which can't rebuild the page.
    scheduleMicrotask(_update);
  }

  static void _remove(ModalRoute<dynamic> route) {
    if (_routes.remove(route)) route.animation?.removeListener(_update);
    scheduleMicrotask(_update);
  }
}

/// Around a page. The tree stays the same whatever the amount, so nothing in the page rebuilds or
/// loses its state.
class SheetRecedePage extends StatelessWidget {
  const SheetRecedePage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_available) return child;
    final sits = _sitsBack(context);
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<double>(
      valueListenable: SheetRecede._amount,
      child: child,
      builder: (context, amount, child) {
        final t = sits ? amount : 0.0;
        final scale = 1 - (1 - SheetRecede.scale) * t;
        return Transform(
          alignment: Alignment.topCenter,
          // Below the status bar, whose text stays on the dark edge.
          transform: Matrix4.translationValues(0, top * t, 0)..scaleByDouble(scale, scale, 1, 1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppShape.lg * t),
            clipBehavior: t == 0 ? Clip.none : Clip.antiAlias,
            child: child,
          ),
        );
      },
    );
  }
}

/// Inside a sheet: tells the page how far up it is.
class SheetRecedeSheet extends StatefulWidget {
  const SheetRecedeSheet({super.key, required this.child});

  final Widget child;

  @override
  State<SheetRecedeSheet> createState() => _SheetRecedeSheetState();
}

class _SheetRecedeSheetState extends State<SheetRecedeSheet> {
  ModalRoute<dynamic>? _route;
  final _statusBar = OverlayPortalController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_available) return;
    // A sheet that can't sit the page back owns no route and no overlay: adding
    // an empty portal around it changes where its semantics land in the tree.
    final sits = _sitsBack(context);
    final route = sits ? ModalRoute.of(context) : null;
    if (route == _route) {
      // A route pushed above the sheet flips isCurrent without replacing the
      // route or moving its animation, so no listener fires. Depend on the
      // modal scope's isCurrent change to recompute here.
      scheduleMicrotask(SheetRecede._update);
      return;
    }
    if (_route != null) SheetRecede._remove(_route!);
    _route = route;
    if (route != null) SheetRecede._add(route);
    if (sits && !_statusBar.isShowing) _statusBar.show();
    if (!sits && _statusBar.isShowing) _statusBar.hide();
    scheduleMicrotask(SheetRecede._update);
  }

  @override
  void dispose() {
    if (_route != null) {
      SheetRecede._remove(_route!);
      SheetRecede.forget(_route!);
    }
    if (_statusBar.isShowing) _statusBar.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || !_sitsBack(context)) return widget.child;
    // A sheet under another one sits back too, the same way the page does.
    // Pass the content through `child` so the glass, scroll position and
    // gestures survive the resize instead of being rebuilt each frame.
    Widget child = widget.child;
    final route = _route;
    if (route != null) {
      child = ValueListenableBuilder<double>(
        valueListenable: SheetRecede.coveredFor(route),
        builder: (context, covered, child) {
          if (covered <= 0) return child!;
          final scale = 1 - (1 - SheetRecede.coveredScale) * covered;
          return Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.diagonal3Values(scale, scale, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.lg * covered)),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          );
        },
        child: child,
      );
    }
    // The status bar reads the topmost region at its own height, which is outside the sheet's
    // clip, so this one goes on the overlay, above the sheet. It turns once the page has sat back
    // far enough to show the dark edge.
    final sits = _sitsBack(context);
    return OverlayPortal(
      controller: _statusBar,
      overlayChildBuilder: (context) => ValueListenableBuilder<double>(
        valueListenable: SheetRecede._amount,
        builder: (context, amount, _) => sits && amount > 0.5
            ? const AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                sized: false,
                child: SizedBox.shrink(),
              )
            : const SizedBox.shrink(),
      ),
      child: child,
    );
  }
}
