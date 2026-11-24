// The new-chat Workspace sheet's "Clone a repository" action: parse a GitHub /
// GitLab source, pick a parent folder on the active Host, run git in a
// throwaway Host session, then register the cloned folder as a workspace.

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/connection_state.dart';
import '../../state/git_repository_state.dart';
import '../../state/sessions_state.dart' show localWorkspaceDir;
import '../common/app_sheet.dart';
import '../common/list_page_row.dart';
import '../common/segmented_pill.dart';
import '../common/sheet_title_bar.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'directory_picker.dart';
import 'workspace_actions.dart';
import 'workspace_format.dart';

/// Opens the clone sheet from the Workspace switcher.
Future<void> showCloneRepositorySheet(BuildContext context) => showAppSheet<void>(
  context,
  isScrollControlled: true,
  builder: (_) => const CloneRepositorySheet(),
);

class CloneRepositorySheet extends ConsumerStatefulWidget {
  const CloneRepositorySheet({super.key});

  @override
  ConsumerState<CloneRepositorySheet> createState() => _CloneRepositorySheetState();
}

class _CloneRepositorySheetState extends ConsumerState<CloneRepositorySheet> {
  final _input = TextEditingController();
  GitHost _host = GitHost.github;
  String? _parent;
  String? _problem;
  String? _progress;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final l10n = context.l10n;
    final path = await showDirectoryPicker(context, title: l10n.remoteWorkspaceCloneFolder, confirmLabel: l10n.commonAdd);
    if (!mounted || path == null) return;
    setState(() {
      _parent = path;
      _problem = null;
    });
  }

  Future<void> _clone() async {
    if (_busy) return;
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final spec = parseGitRepoInput(_input.text, _host);
    if (spec == null) {
      setState(() => _problem = l10n.remoteWorkspaceCloneInvalid);
      return;
    }
    final parent = _parent ?? (container.read(activeConnectionProvider).value?.isLocal == true ? localWorkspaceDir : null);
    if (parent == null || parent.isEmpty) {
      setState(() => _problem = l10n.remoteWorkspaceCloneChooseFolder);
      return;
    }
    final connection = container.read(activeConnectionProvider).value;
    final client = connection?.client;
    final generation = client?.mux.generation;
    if (client == null) return;
    bool current() =>
        mounted &&
        identical(container.read(activeConnectionProvider).value, connection) &&
        client.mux.generation == generation;
    if (!client.supportsTerminals) {
      setState(() => _problem = l10n.remoteWorkspaceCloneTerminalOff);
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
      _progress = l10n.remoteWorkspaceCloneBusy;
    });
    try {
      final outcome = await container.read(gitHostServiceProvider).clone(
        client: client,
        spec: spec,
        parentPath: parent,
        stillCurrent: current,
        onProgress: (line) {
          if (current()) setState(() => _progress = line);
        },
      );
      if (!current()) return;
      if (!outcome.ok) {
        setState(() {
          _busy = false;
          _problem = '${l10n.remoteWorkspaceCloneFailed}\n${outcome.output}';
        });
        return;
      }
      final registered = await registerWorkspacePath(
        container,
        messenger,
        outcome.path,
        successNotice: l10n.remoteWorkspaceCloneAdded,
        errorFallback: l10n.remoteWorkspaceCloneFailed,
      );
      if (!mounted || registered == null) return;
      Navigator.of(context).maybePop();
    } on GitCommandException catch (e) {
      if (!current()) return;
      setState(() {
        _busy = false;
        _problem = e.code == 'terminalUnavailable'
            ? l10n.remoteWorkspaceCloneTerminalOff
            : '${l10n.remoteWorkspaceCloneFailed} (${e.code})';
      });
    } on Object catch (e) {
      if (!current()) return;
      setState(() {
        _busy = false;
        _problem = '${l10n.remoteWorkspaceCloneFailed}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final local = ref.watch(activeConnectionProvider.select((c) => c.value?.isLocal ?? true));
    const margin = EdgeInsets.fromLTRB(SheetTitleBar.inset, 0, SheetTitleBar.inset, 12);
    final parentLabel = _parent == null
        ? local ? displayPath(localWorkspaceDir, local: true) : l10n.remoteWorkspaceCloneChooseFolder
        : displayPath(_parent!, local: local);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitleBar(l10n.remoteWorkspaceClone),
              SheetGroup(
                margin: margin,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: 1,
                      decoration: InputDecoration(hintText: l10n.remoteWorkspaceCloneHint, errorText: _problem),
                      onChanged: (_) {
                        if (_problem != null) setState(() => _problem = null);
                      },
                      onSubmitted: (_) => _clone(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.remoteWorkspaceCloneHost, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        SegmentedPill<GitHost>(
                          segments: [
                            PillSegment(GitHost.github, GitHost.github.label),
                            PillSegment(GitHost.gitlab, GitHost.gitlab.label),
                          ],
                          selected: _host,
                          onChanged: _busy ? null : (v) => setState(() => _host = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SheetGroup(
                margin: margin,
                children: [
                  ListPageRow(
                    icon: AppIcons.workspace,
                    title: l10n.remoteWorkspaceCloneFolder,
                    subtitle: parentLabel,
                    onTap: _busy ? null : _pickFolder,
                    chevron: false,
                  ),
                ],
              ),
              if (_progress != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SheetTitleBar.inset, vertical: 8),
                  child: Text(
                    _progress!,
                    style: theme.textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 4, SheetTitleBar.inset, 12),
                child: FilledButton(
                  onPressed: _busy ? null : _clone,
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: _busy
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.remoteWorkspaceCloneAction),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
