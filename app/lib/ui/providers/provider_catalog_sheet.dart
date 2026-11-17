// 「添加渠道」sheet: the models.dev catalogue, fetched live when the sheet
// opens, plus the manual 「自定义」 entry that behaves exactly as before.
// Picking a catalogue entry pops with it; the form then locks name, protocol
// and Base URL and only asks for the API key.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../state/modelsdev_provider_catalog.dart';
import '../common/app_sheet.dart';
import '../common/list_page_row.dart';
import '../common/sheet_title_bar.dart';
import '../settings/settings_widgets.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'provider_widgets.dart';

/// What the sheet hands back: a catalogue provider to preset the form with,
/// or nothing (the user picked custom / dismissed) — the form stays plain.
Future<ModelsDevProvider?> showProviderCatalogSheet(BuildContext context) =>
    showAppSheet<ModelsDevProvider>(
      context,
      dismissal: SheetDismissal.button,
      isScrollControlled: true,
      builder: (_) => const ProviderCatalogSheet(),
    );

class ProviderCatalogSheet extends ConsumerStatefulWidget {
  const ProviderCatalogSheet({super.key});

  @override
  ConsumerState<ProviderCatalogSheet> createState() => _ProviderCatalogSheetState();
}

class _ProviderCatalogSheetState extends ConsumerState<ProviderCatalogSheet> {
  String _query = '';

  List<ModelsDevProvider> _visible(List<ModelsDevProvider> providers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return providers;
    return [
      for (final p in providers)
        if (p.name.toLowerCase().contains(q) || p.id.toLowerCase().contains(q)) p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final catalog = ref.watch(modelsDevCatalogProvider);
    const inset = SheetTitleBar.inset;
    final maxList = MediaQuery.sizeOf(context).height * 0.6;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitleBar(l10n.engineProviderCatalogTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, 0, inset, 8),
              child: TextField(
                autocorrect: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.engineProviderCatalogSearch,
                  prefixIcon: const Icon(AppIcons.search, size: 20),
                ),
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxList),
                child: switch (catalog) {
                  AsyncValue(:final value?) => _CatalogList(providers: _visible(value.providers), query: _query),
                  AsyncValue(:final error?, hasValue: false) => _CatalogError(
                    error: error,
                    onRetry: () => ref.invalidate(modelsDevCatalogProvider),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, 4, inset, 12),
              child: Text(
                l10n.engineProviderCatalogCredit,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, 0, inset, 12),
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.engineProviderCatalogCustom),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.providers, required this.query});

  final List<ModelsDevProvider> providers;

  /// Non-empty shows a "no match" footer instead of a bare list end.
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    if (providers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          l10n.engineProviderCatalogNoMatch,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
        ),
      );
    }
    return ListPageCard(
      margin: const EdgeInsets.symmetric(horizontal: SheetTitleBar.inset - SettingsMetrics.inset),
      children: [
        for (final provider in providers)
          ListPageRow(
            leading: _ProviderLogo(provider: provider),
            title: provider.name,
            subtitle: [
              if (provider.apiUrl case final url?) Uri.parse(url).host,
              if (provider.models.isNotEmpty) l10n.engineProviderModels(provider.models.length),
            ].join(' · '),
            chevron: true,
            onTap: () => Navigator.of(context).pop(provider),
          ),
        if (query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.engineProviderCatalogNoMatch,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ),
      ],
    );
  }
}

/// A provider's logo, loaded from models.dev's `/logos/<id>.svg`; falls back
/// to the monogram disc while loading or when there is nothing to show.
class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider});

  final ModelsDevProvider provider;

  @override
  Widget build(BuildContext context) => SvgPicture.network(
    provider.logoUrl,
    width: 32,
    height: 32,
    fit: BoxFit.contain,
    placeholderBuilder: (context) => Monogram(provider.name),
  );
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: SheetTitleBar.inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.engineProviderCatalogFetchFailed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh, size: 18),
            label: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
