// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.
// Local change: merging an original DSH Go app's engine data (its `/root`) into
// this fork's engine — the export runs in the old app, the import here.

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_state.dart';
import '../../state/engine_control.dart';
import '../../state/engine_settings_state.dart' show engineSettingsProvider;
import '../../state/sessions_state.dart';
import '../../state/workspaces_state.dart';
import '../common/app_dialog.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// What the old app runs, everything and the one without workspace files.
/// `.cache` and `.l2s` never travel: one is re-downloadable, the other is
/// proot's hardlink bookkeeping whose data lives in the tree itself.
const _exportFull =
    "tar --exclude='root/.cache' --exclude='root/.l2s' -czf /sdcard/Download/dsh-go-export.tgz -C / root";
const _exportLight =
    "tar --exclude='root/workspace' --exclude='root/.cache' --exclude='root/.l2s' -czf /sdcard/Download/dsh-go-export.tgz -C / root";

/// 「导入 DSH Go 数据」: the old app packs its engine data onto shared storage,
/// this side merges it into the rootfs while the engine is stopped.
class HomeImportPage extends ConsumerStatefulWidget {
  const HomeImportPage({super.key});

  @override
  ConsumerState<HomeImportPage> createState() => _HomeImportPageState();
}

class _HomeImportPageState extends ConsumerState<HomeImportPage> {
  bool _busy = false;
  String? _status;

  void _copy(String command) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(Clipboard.setData(ClipboardData(text: command)));
    messenger?.showSnackBar(SnackBar(content: Text(context.l10n.phoneHomeImportCopied)));
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (!mounted) return;
    if (path == null || !(path.endsWith('.tgz') || path.endsWith('.tar.gz'))) {
      setState(() => _status = l10n.phoneHomeImportNotTar);
      return;
    }
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.phoneHomeImport),
        content: Text(l10n.phoneHomeImportStep2),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _status = l10n.phoneHomeImportRunning;
    });
    try {
      if (!await EngineControl.stopAndWait(container)) {
        setState(() => _status = l10n.phoneHomeImportStopped);
        return;
      }
      await container.read(runtimeBridgeProvider).importHomeData(path);
      await container.read(localRuntimeProvider.notifier).start();
      container.invalidate(sessionsProvider);
      container.invalidate(workspacesProvider);
      container.invalidate(engineSettingsProvider);
      setState(() => _status = l10n.phoneHomeImportDone);
    } on PlatformException catch (error) {
      setState(() => _status = '${l10n.phoneHomeImportFailed}: ${error.message ?? error.code}');
    } catch (_) {
      setState(() => _status = l10n.phoneHomeImportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    return AppPage.list(
      title: l10n.phoneHomeImport,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Text(
            l10n.phoneHomeImportIntro,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
          ),
        ),
        SettingsSection(
          title: l10n.phoneHomeImportStep1,
          children: [
            SettingsTile(
              icon: AppIcons.terminal,
              title: l10n.phoneHomeImportFull,
              subtitle: _exportFull,
              chevron: false,
              trailing: Icon(AppIcons.copy, size: 18, color: colors.textTertiary),
              onTap: _busy ? null : () => _copy(_exportFull),
            ),
            SettingsTile(
              icon: AppIcons.terminal,
              title: l10n.phoneHomeImportLight,
              subtitle: _exportLight,
              chevron: false,
              trailing: Icon(AppIcons.copy, size: 18, color: colors.textTertiary),
              onTap: _busy ? null : () => _copy(_exportLight),
            ),
          ],
        ),
        SettingsSection(
          title: l10n.phoneHomeImportStep2,
          children: [
            SettingsTile(
              icon: AppIcons.download,
              title: l10n.phoneHomeImportPick,
              subtitle: _status,
              chevron: false,
              trailing: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _busy ? null : _import,
            ),
          ],
        ),
      ],
    );
  }
}

/// The engine screen's row. Android only: the guest whose `/root` receives the
/// data is this phone's proot rootfs; HarmonyOS runs the engine natively.
class HomeImportRow extends ConsumerWidget {
  const HomeImportRow({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsTile(
      icon: AppIcons.download,
      tinted: false,
      title: l10n.phoneHomeImport,
      subtitle: l10n.phoneHomeImportHint,
      chevron: true,
      onTap: enabled
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HomeImportPage()))
          : null,
    );
  }
}
