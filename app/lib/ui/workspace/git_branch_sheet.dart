// The Git branch sheet: which branch the folder behind a conversation (or the
// workspace a new conversation will start in) is on, and switching it.
//
// Opened from the new-chat options row and from the composer's branch chip;
// both hide their entry unless [gitBranchProvider] says the folder is a repo.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/connection_state.dart';
import '../../state/git_branch_state.dart';
import '../../state/git_repository_state.dart';
import '../common/app_sheet.dart';
import '../common/brief_notice.dart';
import '../common/list_page_row.dart';
import '../common/row_marks.dart';
import '../common/sheet_title_bar.dart';
import '../features/feature_kit.dart' show QuietSpinner;
import '../theme/app_icons.dart';
import '../theme/theme.dart';

Future<void> showGitBranchSheet(BuildContext context, GitScope scope) => showAppSheet<void>(
  context,
  isScrollControlled: true,
  builder: (_) => GitBranchSheet(scope: scope),
);

/// The composer's branch chip, beside the model pill: the fork glyph and the
/// branch name, nothing else. It draws nothing until the folder reports a
/// repository, so a conversation outside git keeps the row as it was.
class GitBranchChip extends ConsumerWidget {
  const GitBranchChip({super.key, required this.scope});

  final GitScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = this.scope;
    if (scope == null) return const SizedBox.shrink();
    final info = ref.watch(gitBranchProvider(scope)).value;
    if (info == null || !info.isRepo) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final label = info.branch ?? l10n.remoteGitBranchDetached;
    void open() => unawaited(showGitBranchSheet(context, scope));
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        button: true,
        label: '${l10n.remoteGitBranch}: $label',
        excludeSemantics: true,
        onTap: open,
        child: InkResponse(
          key: const ValueKey('composer-branch'),
          onTap: open,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, maxWidth: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(color: colors.onSurface.withValues(alpha: 0.06), shape: const StadiumBorder()),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.fork, size: 15, color: dsh.textTertiary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(fontSize: 12.5, color: dsh.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GitBranchSheet extends ConsumerStatefulWidget {
  const GitBranchSheet({super.key, required this.scope});

  final GitScope scope;

  @override
  ConsumerState<GitBranchSheet> createState() => _GitBranchSheetState();
}

class _GitBranchSheetState extends ConsumerState<GitBranchSheet> {
  String? _busy;
  String? _problem;

  Future<void> _switch(String branch) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final connection = container.read(activeConnectionProvider).value;
    final client = connection?.client;
    final generation = client?.mux.generation;
    if (client == null) return;
    bool current() =>
        mounted &&
        identical(container.read(activeConnectionProvider).value, connection) &&
        client.mux.generation == generation;
    setState(() {
      _busy = branch;
      _problem = null;
    });
    try {
      final cwd = await gitScopeCwd(client, widget.scope);
      if (!current()) return;
      if (cwd == null || cwd.isEmpty) {
        setState(() {
          _busy = null;
          _problem = l10n.remoteGitBranchNoFolder;
        });
        return;
      }
      final outcome = await container.read(gitHostServiceProvider).checkout(
        client: client,
        cwd: cwd,
        branch: branch,
        stillCurrent: current,
      );
      if (!current()) return;
      container.invalidate(gitBranchProvider(widget.scope));
      if (outcome.ok) {
        if (!mounted) return;
        messenger?.showBriefNotice(l10n.remoteGitBranchSwitched(branch));
        Navigator.of(context).maybePop();
        return;
      }
      // git's own refusal (local changes, unknown branch) is the message.
      setState(() {
        _busy = null;
        _problem = outcome.output.isEmpty ? l10n.remoteGitBranchFailed : outcome.output;
      });
    } on GitCommandException catch (e) {
      if (!current()) return;
      setState(() {
        _busy = null;
        _problem = e.code == 'terminalUnavailable' ? l10n.remoteWorkspaceCloneTerminalOff : e.code;
      });
    } on Object catch (e) {
      if (!current()) return;
      setState(() {
        _busy = null;
        _problem = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final info = ref.watch(gitBranchProvider(widget.scope));
    const margin = EdgeInsets.fromLTRB(SheetTitleBar.inset, 0, SheetTitleBar.inset, 12);
    final body = info.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: QuietSpinner()),
      ),
      error: (_, _) => _note(context, l10n.remoteGitBranchNotRepo),
      data: (info) {
        if (!info.isRepo) return _note(context, l10n.remoteGitBranchNotRepo);
        return SheetGroup(
          margin: margin,
          children: [
            if (info.branches.isEmpty)
              ListPageRow(icon: AppIcons.fork, title: l10n.remoteGitBranchDetached, onTap: null, chevron: false)
            else
              for (final branch in info.branches)
                ListPageRow(
                  icon: AppIcons.fork,
                  title: branch,
                  trailing: RowCheck(visible: branch == info.branch),
                  onTap: branch == info.branch || _busy != null ? null : () => _switch(branch),
                ),
          ],
        );
      },
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitleBar(l10n.remoteGitBranch),
              body,
              if (_busy != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: SheetTitleBar.inset, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _busy!,
                          style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 4, SheetTitleBar.inset, 8),
                  child: Text(
                    _problem!,
                    style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).danger),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text) => SheetGroup(
    margin: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 0, SheetTitleBar.inset, 12),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
