// The Git branch sheet: which branch the folder behind a conversation (or the
// workspace a new conversation will start in) is on, switching it, creating a
// branch and opening its remote-tracking branches.
//
// Opened from the new-chat options row and from the composer's branch chip;
// both hide their entry unless [gitBranchProvider] says the folder is a repo.
// The switch itself lives once, in [GitBranchSwitching], and the remote
// branches page shares it.

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
import 'git_remote_branches_page.dart';
import 'text_prompt.dart';

Future<void> showGitBranchSheet(BuildContext context, GitScope scope) => showAppSheet<void>(
  context,
  isScrollControlled: true,
  builder: (_) => GitBranchSheet(scope: scope),
);

/// The composer's branch chip, beside the model pill: the fork glyph and the
/// branch name, nothing else, with a small dot when the tree has uncommitted
/// changes. It draws nothing until the folder reports a repository, so a
/// conversation outside git keeps the row as it was.
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
    // A worktree outside a session keeps its git directory beyond the folder,
    // so the file probe cannot name its branch. Say what it is instead of
    // claiming a detached HEAD.
    final label = info.branch ??
        (info.worktree && info.changedFiles == null ? l10n.remoteGitBranchWorktree : l10n.remoteGitBranchDetached);
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
                  if (info.dirty) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: const ValueKey('composer-branch-dirty'),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: dsh.warning, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One branch switch, shared by the sheet and the remote branches page: the
/// [busyBranch] and [problem] a view shows, and [switchBranch].
///
/// The state class supplies [gitBranchScope] — the scope the host state is
/// being read for; a successful switch invalidates it.
mixin GitBranchSwitching<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The branch being checked out, or null when nothing runs.
  String? busyBranch;

  /// git's own refusal (or the Host's), shown as it came; null while none.
  String? problem;

  GitScope get gitBranchScope;

  Future<void> switchBranch(String branch, {bool create = false}) async {
    if (busyBranch != null) return;
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
      busyBranch = branch;
      problem = null;
    });
    try {
      final cwd = await gitScopeCwd(client, gitBranchScope);
      if (!current()) return;
      if (cwd == null || cwd.isEmpty) {
        setState(() {
          busyBranch = null;
          problem = l10n.remoteGitBranchNoFolder;
        });
        return;
      }
      final outcome = await container.read(gitHostServiceProvider).checkout(
        client: client,
        cwd: cwd,
        branch: branch,
        stillCurrent: current,
        create: create,
      );
      if (!current()) return;
      container.invalidate(gitBranchProvider(gitBranchScope));
      if (outcome.ok) {
        if (!mounted) return;
        messenger?.showBriefNotice(l10n.remoteGitBranchSwitched(branch));
        Navigator.of(context).maybePop();
        return;
      }
      // git's own refusal (local changes, unknown branch) is the message.
      setState(() {
        busyBranch = null;
        problem = outcome.output.isEmpty ? l10n.remoteGitBranchFailed : outcome.output;
      });
    } on GitCommandException catch (e) {
      if (!current()) return;
      setState(() {
        busyBranch = null;
        problem = e.code == 'terminalUnavailable' ? l10n.remoteWorkspaceCloneTerminalOff : e.code;
      });
    } on Object catch (e) {
      if (!current()) return;
      setState(() {
        busyBranch = null;
        problem = '$e';
      });
    }
  }
}

/// The progress line under a branch list while a switch runs, and git's
/// refusal under it when one fails; shared so the sheet and the remote
/// branches page read the same.
class GitBranchSwitchStatus extends StatelessWidget {
  const GitBranchSwitchStatus({super.key, this.busyBranch, this.problem});

  final String? busyBranch;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final busy = busyBranch;
    final failure = problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SheetTitleBar.inset, vertical: 8),
            child: Row(
              children: [
                const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    busy,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 4, SheetTitleBar.inset, 8),
            child: Text(failure, style: theme.textTheme.bodySmall?.copyWith(color: colors.danger)),
          ),
      ],
    );
  }
}

class GitBranchSheet extends ConsumerStatefulWidget {
  const GitBranchSheet({super.key, required this.scope});

  final GitScope scope;

  @override
  ConsumerState<GitBranchSheet> createState() => _GitBranchSheetState();
}

class _GitBranchSheetState extends ConsumerState<GitBranchSheet> with GitBranchSwitching<GitBranchSheet> {
  @override
  GitScope get gitBranchScope => widget.scope;

  Future<void> _createBranch() async {
    final l10n = context.l10n;
    final name = await showTextPrompt(
      context,
      title: l10n.remoteGitBranchCreate,
      hint: l10n.remoteGitBranchCreateName,
      maxLength: 200,
      validate: (text) => isValidGitRefName(text) ? null : l10n.remoteGitBranchCreateInvalid,
    );
    if (name == null || !mounted) return;
    await switchBranch(name, create: true);
  }

  void _openRemoteBranches() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => GitRemoteBranchesPage(scope: widget.scope)),
      ),
    );
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
        final busy = busyBranch != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.worktree)
              SheetGroup(
                margin: margin,
                children: [
                  ListPageRow(icon: AppIcons.fork, title: l10n.remoteGitBranchWorktree, onTap: null, chevron: false),
                ],
              ),
            SheetGroup(
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
                      onTap: branch == info.branch || busy ? null : () => switchBranch(branch),
                    ),
              ],
            ),
            if (info.dirty)
              Padding(
                padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset + 8, 0, SheetTitleBar.inset + 8, 10),
                child: Text(
                  l10n.remoteGitBranchDirty(info.changedFiles!),
                  style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).warning),
                ),
              ),
            SheetGroup(
              margin: margin,
              children: [
                ListPageRow(
                  icon: AppIcons.add,
                  title: l10n.remoteGitBranchCreate,
                  onTap: busy ? null : _createBranch,
                  chevron: false,
                ),
                ListPageRow(
                  icon: AppIcons.fork,
                  title: l10n.remoteGitBranchRemote,
                  onTap: busy ? null : _openRemoteBranches,
                ),
              ],
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
              GitBranchSwitchStatus(busyBranch: busyBranch, problem: problem),
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