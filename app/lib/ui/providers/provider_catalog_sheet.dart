// 「添加渠道」sheet: the models.dev catalogue, fetched live when the sheet
// opens, plus the manual 「自定义」 entry that behaves exactly as before.
// Picking a catalogue entry pops with it; the form then locks name, protocol
// and Base URL and only asks for the API key.

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../state/modelsdev_provider_catalog.dart';
import '../common/app_sheet.dart';
import '../common/list_page_row.dart';
import '../common/sheet_title_bar.dart';
import '../settings/settings_widgets.dart' show SettingsMetrics;
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
    // The sheet takes most of the screen: search + up to 62 % for the list,
    // credit and the custom entry stay visible below it.
    final maxList = MediaQuery.sizeOf(context).height * 0.62;

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
              padding: const EdgeInsets.fromLTRB(inset, 2, inset, 12),
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
                  AsyncValue(:final value?) => _CatalogList(providers: _visible(value.providers)),
                  AsyncValue(:final error?, hasValue: false) => _CatalogError(
                    error: error,
                    onRetry: () => ref.read(modelsDevCatalogProvider.notifier).retry(),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, 10, inset, 0),
              child: Text(
                l10n.engineProviderCatalogCredit,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, 12, inset, 16),
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
  const _CatalogList({required this.providers});

  final List<ModelsDevProvider> providers;

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
    // A scrollable list, not a card-sized column: the catalogue has hundreds
    // of rows, and a fixed column overflows into the sheet's footer. Same
    // card look as ListPageCard (card-tier glass, radius 20, rows touching);
    // a hairline separates the rows that scroll.
    final scheme = Theme.of(context).colorScheme;
    final gutter = SheetTitleBar.inset;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter - SettingsMetrics.inset),
      child: GlassSurface(
        tier: GlassTier.card,
        borderRadius: AppShape.radiusLg,
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusLg),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: providers.length,
            itemBuilder: (context, i) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (i > 0)
                  Divider(height: 1, thickness: 0.5, color: scheme.onSurface.withValues(alpha: 0.06)),
                ListPageRow(
                  leading: _ProviderLogo(provider: providers[i]),
                  title: providers[i].name,
                  subtitle: [
                    if (providers[i].apiUrl case final url?) Uri.parse(url).host,
                    if (providers[i].models.isNotEmpty)
                      l10n.engineProviderModels(providers[i].models.length),
                  ].join(' · '),
                  chevron: true,
                  onTap: () => Navigator.of(context).pop(providers[i]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A provider's logo, fetched as bytes through the catalogue's http seam and
/// drawn from memory; the monogram disc stands in while loading, or for
/// good when the fetch fails — a logo is decoration.
class _ProviderLogo extends ConsumerStatefulWidget {
  const _ProviderLogo({required this.provider});

  final ModelsDevProvider provider;

  @override
  ConsumerState<_ProviderLogo> createState() => _ProviderLogoState();
}

class _ProviderLogoState extends ConsumerState<_ProviderLogo> {
  Future<Uint8List?>? _logo;

  @override
  void initState() {
    super.initState();
    _logo = fetchProviderLogo(ref.read(modelsDevHttpProvider), widget.provider);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: FutureBuilder<Uint8List?>(
        future: _logo,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return Monogram(widget.provider.name);
          return SvgPicture.memory(bytes, width: 32, height: 32, fit: BoxFit.contain);
        },
      ),
    );
  }
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
