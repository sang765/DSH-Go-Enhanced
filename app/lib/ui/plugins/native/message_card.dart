import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../plugins/native/native_model.dart';
import '../../../plugins/native/native_state.dart';
import '../../../plugins/native/native_surface.dart';
import '../view/plugin_view.dart';

/// The plugins' live cards for one durable assistant reply. It stays empty
/// until a plugin publishes a view; the reply itself is never replaced.
class NativeMessageCardSlot extends ConsumerWidget {
  const NativeMessageCardSlot({
    super.key,
    required this.sessionId,
    required this.turnId,
    required this.messageId,
    required this.replyText,
    required this.onAction,
  });

  final String sessionId;
  final String? turnId;
  final String messageId;
  final String replyText;
  final Future<bool> Function(PluginAction action, NativeSurfaceKey key) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (turnId == null) return const SizedBox.shrink();
    final scope = DshGoScope(sessionId: sessionId, turnId: turnId, messageId: messageId);
    final children = <Widget>[];
    for (final plugin in ref.watch(nativeContributionsProvider).plugins) {
      if (!ref.watch(nativeSurfaceOnProvider((plugin.package, NativeSurface.messageCard)))) continue;
      for (final id in plugin.messageCards) {
        final key = NativeSurfaceKey(package: plugin.package, surface: NativeSurface.messageCard, id: id, scope: scope);
        final state = ref.watch(nativeSurfaceProvider(key));
        final bridge = ref.watch(nativeBridgeProvider);
        final visible = state.data is Map ? (state.data as Map)['hasCards'] != false : true;
        if (!state.hasView || state.failure != null || bridge == null || !visible) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PluginFrame(
              pluginName: ref.watch(nativePluginTitleProvider(plugin.package)),
              icon: plugin.icon,
              child: PluginView(
                key: ValueKey(key),
                view: state.view,
                data: state.data,
                showTitle: false,
                imageResolver: (src) => src.startsWith('asset:') ? bridge.asset(plugin.package, src.substring(6)) : null,
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
