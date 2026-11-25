// The native equivalent of the web UI's "Add plugin": install any npm package,
// GitHub repository or Host-side directory through the plugin manager. Market
// installs stay on the market tab; this is the free-form escape hatch.

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/app_dialog.dart';
import '../theme/theme.dart';

/// What the dialog hands back to the install queue.
typedef AddPluginSelection = ({String spec, String? registry});

const addPluginMirrorRegistry = 'https://registry.npmmirror.com';
const addPluginNpmRegistry = 'https://registry.npmjs.org';

/// A short name for progress and toasts. Only the last path segment of a Git
/// URL or directory counts; a version suffix on an npm spec is dropped, while
/// the leading `@` of a scoped package is kept.
String addPluginName(String spec) {
  var name = spec.trim().replaceFirst(RegExp(r'[\\/]+$'), '');
  final slash = name.lastIndexOf(RegExp(r'[\\/]'));
  if (slash >= 0) name = name.substring(slash + 1);
  if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
  final at = name.lastIndexOf('@');
  if (at > 0) name = name.substring(0, at);
  return name.isEmpty ? spec.trim() : name;
}

/// Custom registries must be plain https origins: no query, fragment or
/// credentials in the URL. Authentication belongs in the Host's `.npmrc`.
bool isValidAddPluginRegistry(String raw) {
  final uri = Uri.tryParse(raw.trim());
  return uri != null &&
      uri.isAbsolute &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

Future<AddPluginSelection?> showAddPluginDialog(BuildContext context, {required bool local}) =>
    showAppDialog<AddPluginSelection>(
      context: context,
      builder: (_) => _AddPluginDialog(local: local),
    );

class _AddPluginDialog extends StatefulWidget {
  const _AddPluginDialog({required this.local});

  final bool local;

  @override
  State<_AddPluginDialog> createState() => _AddPluginDialogState();
}

class _AddPluginDialogState extends State<_AddPluginDialog> {
  final _spec = TextEditingController();
  final _custom = TextEditingController();
  int _registry = 0;
  String? _error;

  @override
  void dispose() {
    _spec.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _install() {
    final l10n = context.l10n;
    final spec = _spec.text.trim();
    if (spec.isEmpty || spec.length > 512) {
      setState(() => _error = l10n.pluginsAddInvalid);
      return;
    }
    String? registry;
    switch (_registry) {
      case 0:
        registry = addPluginMirrorRegistry;
      case 1:
        registry = addPluginNpmRegistry;
      default:
        final raw = _custom.text.trim();
        if (!isValidAddPluginRegistry(raw)) {
          setState(() => _error = l10n.pluginsAddInvalidRegistry);
          return;
        }
        registry = raw;
    }
    Navigator.of(context).pop((spec: spec, registry: registry));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    return AlertDialog(
      title: Text(l10n.pluginsAddPlugin),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _spec,
              autofocus: true,
              maxLines: 1,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(labelText: l10n.pluginsInstallPlugin, hintText: l10n.pluginsAddHint),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _registry,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.pluginsAddRegistry),
              items: [
                DropdownMenuItem(value: 0, child: Text(l10n.pluginsAddRegistryMirror)),
                DropdownMenuItem(value: 1, child: Text(l10n.pluginsAddRegistryNpm)),
                DropdownMenuItem(value: 2, child: Text(l10n.pluginsAddRegistryCustom)),
              ],
              onChanged: (value) => setState(() {
                _registry = value ?? 0;
                _error = null;
              }),
            ),
            if (_registry == 2) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _custom,
                maxLines: 1,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(hintText: l10n.pluginsAddRegistryHint, helperText: l10n.pluginsAddRegistryHelp),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              widget.local ? l10n.pluginsPermissionLocalTrusted : l10n.pluginsPermissionRemoteTrusted,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: colors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _install, child: Text(l10n.pluginsAddInstall)),
      ],
    );
  }
}
