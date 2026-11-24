// The remote-tracking branches of the folder behind a conversation (or a
// workspace a new conversation will start in): tapping one checks out the
// local branch git makes for it, so `origin/develop` becomes `develop`.
//
// Pushed from the branch sheet. Each remote-tracking name is offered with the
// local branch name it will create; the switch itself is the sheet's
// [GitBranchSwitching], so both surface git's answer the same way.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/git_branch_state.dart';
import '../common/list_page_row.dart';
import '../common/row_marks.dart';
import '../features/feature_kit.dart' show QuietSpinner;
import '../features/feature_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import 'git_branch_sheet.dart' show GitBranchSwitching, GitBranchSwitchStatus;

/// The local branch a remote-tracking name makes when checked out: only the
/// first path segment (the remote) goes, so `origin/develop` is `develop` and
/// `upstream/feature/x` is `feature/x`.
String remoteBranchShortName(String remote) => remote.substring(remote.indexOf('/') + 1);

class GitRemoteBranchesPage extends ConsumerStatefulWidget {
  const GitRemoteBranchesPage({super.key, required this.scope});

  final GitScope scope;

  @override
  ConsumerState<GitRemoteBranchesPage> createState() => _GitRemoteBranchesPageState();
}

class _GitRemoteBranchesPageState extends ConsumerState<GitRemoteBranchesPage>
    with GitBranchSwitching<GitRemoteBranchesPage> {
  @override
  GitScope get gitBranchScope => widget.scope;

  Widget _body(BuildContext context, GitBranchInfo info) {
    final l10n = context.l10n;
    final busy = busyBranch != null;
    final remotes = info.remotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (remotes.isEmpty)
          FeatureMessage(icon: AppIcons.fork, title: l10n.remoteGitBranchRemoteEmpty)
        else
          ListPageCard(
            children: [
              for (final remote in remotes)
                ListPageRow(
                  icon: AppIcons.fork,
                  title: remote,
                  subtitle: remoteBranchShortName(remote),
                  trailing: RowCheck(visible: remoteBranchShortName(remote) == info.branch),
                  onTap: busy || remoteBranchShortName(remote) == info.branch
                      ? null
                      : () => switchBranch(remoteBranchShortName(remote)),
                ),
            ],
          ),
        GitBranchSwitchStatus(busyBranch: busyBranch, problem: problem),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = ref.watch(gitBranchProvider(widget.scope));
    final body = info.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: QuietSpinner()),
      ),
      error: (_, _) => FeatureMessage(icon: AppIcons.fork, title: l10n.remoteGitBranchNotRepo),
      data: (info) => info.isRepo
          ? _body(context, info)
          : FeatureMessage(icon: AppIcons.fork, title: l10n.remoteGitBranchNotRepo),
    );
    return AppPage(title: l10n.remoteGitBranchRemote, slivers: [SliverList.list(children: [body])]);
  }
}