// One chat anchor's plugin views (plugin-chat-views contract, §3.2 and §3.5).
// A slot asks for the views declared at its anchor, skips the ones its role /
// tools hint rules out, and draws what the plugin returns through the ordinary
// native view renderer. Nothing matches → nothing is drawn, so chat is never
// disturbed by a plugin that has nothing to show.

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../plugins/native/native_model.dart';
import '../../../plugins/native/native_state.dart';
import '../../../plugins/native/native_surface.dart';
import '../view/plugin_view.dart';

/// The views at one anchor. [scope] is what the plugin's `view(scope, caps)`
/// reads: ids only. [role] and [tools] are the slot's coarse filter — a view's
/// advisory `hint` may skip a fetch, but never decides what to draw.
class ChatViewSlot extends ConsumerWidget {
  const ChatViewSlot({
    super.key,
    required this.anchor,
    this.scope = DshGoScope.none,
    this.role,
    this.tools = const [],
    this.childPadding = const EdgeInsets.only(top: 8),
    required this.onAction,
  });

  /// One of [DshGoChatView.anchors].
  final String anchor;
  final DshGoScope scope;

  /// `user` / `assistant` when the slot has a specific message role.
  final String? role;

  /// Tool-call names present here; empty means "cannot rule anything out".
  final List<String> tools;

  /// Space between the slot and the view only when there is something to draw;
  /// an empty slot stays zero high so chat goldens never shift.
  final EdgeInsetsGeometry childPadding;

  final Future<bool> Function(PluginAction action, NativeSurfaceKey key) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];
    for (final plugin in ref.watch(nativeContributionsProvider).plugins) {
      if (!ref.watch(nativeSurfaceOnProvider((plugin.package, NativeSurface.chatView)))) continue;
      for (final view in plugin.chatViews) {
        if (view.anchor != anchor) continue;
        if (role != null && view.role != null && view.role != role) continue;
        if (tools.isNotEmpty && view.tools.isNotEmpty && !view.tools.any(tools.contains)) continue;
        final key = NativeSurfaceKey(
          package: plugin.package,
          surface: NativeSurface.chatView,
          id: view.id,
          scope: scope,
        );
        final state = ref.watch(nativeSurfaceProvider(key));
        final bridge = ref.watch(nativeBridgeProvider);
        // A plugin whose view() answered null has no view; loading, offline
        // and broken views never push the chat around.
        if (!state.hasView || state.failure != null || bridge == null) continue;
        children.add(
          Padding(
            padding: childPadding,
            child: PluginFrame(
              pluginName: ref.watch(nativePluginTitleProvider(plugin.package)),
              icon: plugin.icon,
              child: PluginView(
                key: ValueKey(key),
                view: state.view,
                data: state.data,
                showTitle: false,
                imageResolver: (src) =>
                    src.startsWith('asset:') ? bridge.asset(plugin.package, src.substring(6)) : null,
                onAction: (action) => onAction(action, key),
              ),
            ),
          ),
        );
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }
}
