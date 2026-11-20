// About DSH Go: a quiet brand hero, then app information, the original author
// and personal profiles, the fork's repository, then the slogan and disclaimer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/app_info.dart';
import '../../state/star_prompt.dart' show starLinkOpenerProvider;
import '../../state/update_state.dart';
import '../shell/brand_mark.dart';
import '../shell/page_frame.dart';
import '../star/star_prompt_dialog.dart' show openStarProject;
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import '../update/update_tiles.dart';
import 'settings_widgets.dart';

/// The installed version as the app shows it: `0.9.6 (10271234)`.
String installedVersionLabel(WidgetRef ref) {
  // What Android reports as installed (the compiled-in constant until it does).
  final installed = ref.watch(appUpdateProvider.select((s) => s.current));
  return installed.build == null ? installed.name : '${installed.name} (${installed.build})';
}

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    final version = installedVersionLabel(ref);
    return AppPage.list(
      title: l10n.hubAbout,
      children: [
        _AboutHero(version: version),
        SettingsSection(
          children: [
            SettingsTile(
              spot: Spots.version,
              icon: AppIcons.info,
              tint: 5,
              tinted: false,
              value: Text(version, style: AppType.tabular(theme.textTheme.bodyMedium!)),
            ),
            const AppUpdateTiles(tint: 5, tinted: false),
            SettingsTile(
              key: const ValueKey('settings-star'),
              spot: Spots.star,
              icon: AppIcons.starProject,
              tint: 7,
              tinted: false,
              onTap: () => unawaited(
                openStarProject(ProviderScope.containerOf(context, listen: false), ScaffoldMessenger.maybeOf(context)),
              ),
            ),
            SettingsTile(
              spot: Spots.licenses,
              icon: AppIcons.code,
              tint: 1,
              tinted: false,
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: version,
                applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandMark(size: 56, tile: true)),
                applicationLegalese: AppInfo.disclaimer,
              ),
            ),
          ],
        ),
        _AboutHeader(title: l10n.hubAboutAuthor),
        SettingsSection(
          children: [
            SettingsTile(title: AppInfo.author, icon: AppIcons.profile, tint: 2, tinted: false),
            _authorLink(
              context,
              ref,
              'about-author-bilibili',
              l10n.hubAboutBilibili,
              AppInfo.authorBilibiliName,
              AppInfo.authorBilibiliUrl,
              icon: AppIcons.web,
              tint: 4,
              tinted: false,
            ),
            _authorLink(
              context,
              ref,
              'about-author-x',
              l10n.hubAboutX,
              AppInfo.authorXHandle,
              AppInfo.authorXUrl,
              icon: AppIcons.community,
              tint: 3,
              tinted: false,
            ),
            _authorLink(
              context,
              ref,
              'about-author-github',
              l10n.hubAboutGithub,
              '@${AppInfo.author}',
              AppInfo.authorGithubUrl,
              icon: AppIcons.code,
              tint: 0,
              tinted: false,
            ),
          ],
        ),
        _AboutHeader(title: l10n.hubAboutFork),
        SettingsSection(
          children: [
            _authorLink(
              context,
              ref,
              'about-fork',
              l10n.hubAboutForkRepo,
              '@${AppInfo.forkAuthor}',
              AppInfo.forkUrl,
              icon: AppIcons.code,
              tint: 6,
              tinted: false,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Divider(height: 1, thickness: 0.5, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 18),
              BrandMark(size: 18, color: colors.textDisabled),
              const SizedBox(height: 10),
              Text(
                AppInfo.slogan,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(height: 8),
              Text(
                AppInfo.disclaimer,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _authorLink(
    BuildContext context,
    WidgetRef ref,
    String key,
    String title,
    String handle,
    String url, {
    required IconData icon,
    required int tint,
  }) =>
      Semantics(
        link: true,
        child: SettingsTile(
          key: ValueKey(key),
          icon: icon,
          tint: tint,
          tinted: false,
          title: title,
          subtitle: handle,
          trailing: Icon(AppIcons.openExternal, size: 18, color: DshColors.of(context).textTertiary),
          onTap: () => unawaited(_openAuthorLink(context, ref, Uri.parse(url))),
        ),
      );

  Future<void> _openAuthorLink(BuildContext context, WidgetRef ref, Uri url) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (await ref.read(starLinkOpenerProvider)(url)) return;
    } catch (_) {
      // As with the project's link, fall back to copying when no browser opens.
    }
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: url.toString()));
    } catch (_) {
      copied = false;
    }
    if (messenger?.mounted ?? false) {
      messenger!.showSnackBar(
        SnackBar(content: Text(copied ? l10n.shellBrowserUrlCopied : l10n.stateBrowserOpenFailed)),
      );
    }
  }
}

/// The page's one splash of colour: the launcher tile on a soft brand wash,
/// with the version and fork as quiet chips. No image asset — it follows the
/// active wallpaper accent like the rest of the app.
class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final short = version.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: GlassSurface(
        tier: GlassTier.card,
        borderRadius: AppShape.radiusLg,
        child: ClipRRect(
          borderRadius: AppShape.radiusLg,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AboutHeroWash(
                    scheme: theme.colorScheme,
                    dark: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  children: [
                    const BrandMark(size: 64, tile: true),
                    const SizedBox(height: 12),
                    Text(
                      AppInfo.name,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroChip(icon: AppIcons.info, label: short),
                        const SizedBox(width: 8),
                        _HeroChip(icon: AppIcons.code, label: '@${AppInfo.forkAuthor}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two quiet corner glows over one accent-tinted base. The wash reads as a
/// deliberate colour field instead of the muddy neutral the glass alone gave.
class _AboutHeroWash extends CustomPainter {
  const _AboutHeroWash({required this.scheme, required this.dark});

  final ColorScheme scheme;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Color.lerp(scheme.surface, scheme.primaryContainer, dark ? 0.34 : 0.24) ?? scheme.surface;
    canvas.drawRect(rect, Paint()..color = base);
    void glow(Offset center, double radius, Color color) {
      final box = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        box,
        Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(box),
      );
    }

    glow(
      Offset(size.width * 0.04, 0),
      size.height * 1.1,
      scheme.primary.withValues(alpha: dark ? 0.26 : 0.18),
    );
    glow(
      Offset(size.width, size.height),
      size.height * 1.1,
      scheme.tertiary.withValues(alpha: dark ? 0.2 : 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _AboutHeroWash old) => old.scheme != scheme || old.dark != dark;
}

/// A small centred chip in the hero. Painted directly rather than through the
/// shared glass pill: that one stretches to its parent and left-aligns here.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DshColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.textTertiary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// A group title in the hub's own voice, with no extra ornament.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    child: Semantics(header: true, child: Text(title, style: SettingsSection.titleStyle(context))),
  );
}
