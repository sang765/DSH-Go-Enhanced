// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show InlinePattern;

import '../../../l10n/l10n.dart';
import '../../../state/composer_quote.dart' show splitQuote;
import '../../common/expand_reveal.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../media/generate_header.dart';
import '../media/media_format.dart' show mediaParamsLine;
import '../mention/mention_chip.dart';
import '../mention/mention_syntax.dart' show parseMessageMentions;
import '../render/markdown_body.dart';
import '../secret_mask.dart';
import 'message_actions.dart';
import 'message_selection.dart';
import 'quote_chip.dart';
import 'theme_role_tag.dart';

/// A pasted block with fences, headings or links reads as Markdown instead of
/// a wall of `**` and ```` ``` ````. Deliberately conservative: ordinary prose,
/// prompts, commands and code fragments keep the plain bubble.
final _mdFence = RegExp(r'^[ \t]*(```|~~~)', multiLine: true);
final _mdHeading = RegExp(r'^#{1,6}\s', multiLine: true);
final _mdLink = RegExp(r'\[[^\]]+\]\(https?://[^)]+\)');
bool looksLikeMarkdown(String text) =>
    _mdFence.hasMatch(text) || _mdHeading.hasMatch(text) || _mdLink.hasMatch(text);

/// Mentions stay chips inside a rendered message; credentials are masked
/// before the Markdown parser sees them (with `•`, not `*`, so the mask
/// cannot turn into emphasis).
final _bubbleMentionPattern = InlinePattern(
  // A mention starts at a token boundary. The canonical grammar then drops
  // bare @words and emails — reuse it so the rendered bubble matches the
  // plain one instead of making every @ into a file chip.
  pattern: RegExp(r'(?<!\S)@[^\s]+'),
  builder: (context, match, style) {
    final tokens = parseMessageMentions(match[0]!);
    final token = tokens.isEmpty ? null : tokens.first;
    if (token == null) return TextSpan(text: match[0], style: style);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: MentionChip(kind: token.kind, label: token.label, style: style),
    );
  },
);

/// 用户消息:**右对齐的软气泡**,比页面深一档,像"按进去"的。
///
/// 禁配:气泡底上只用主文字 / 次级文字;三级文字(4.32)与主色(4.22)
/// 不过 AA。
///
/// 长按气泡里的字就地选字([MessageSelection])，可直接「编辑后重发」([onEdit])；
/// 选区上的「更多」打开完整菜单。
///
/// 以引用块开头的消息(引用追问),引文画在气泡顶部([BubbleQuote]),
/// 下面是正文;复制、选择文字、编辑拿到的仍是发出去的原文。
///
/// 贴进来的 Markdown(代码围栏 / 标题 / 链接)按 [MarkdownBody] 画,旁边有
/// 「查看原文」切回原样;遮挡凭据、chip @ 和原文操作都不受影响。
class UserBubble extends StatefulWidget {
  const UserBubble({
    super.key,
    required this.text,
    this.attachments,
    this.pendingLabel,
    this.pendingIcon = AppIcons.queued,
    this.pendingActions = const [],
    this.onEdit,
    this.onQuote,
  });

  final String text;

  /// Images and file cards, shown right-aligned above the bubble (附件不塞进
  /// 气泡里)。
  final Widget? attachments;

  /// 非空 = 乐观气泡(还没被 DSH 回显),显示在气泡下方("发送中" / "排队中")。
  final String? pendingLabel;
  final IconData pendingIcon;

  /// Small text actions after the pending label ("改为插话", "撤回").
  final List<(String, VoidCallback)> pendingActions;

  /// "编辑后重发" in the selection toolbar and the full menu. Optimistic
  /// bubbles leave it out; they have "撤回" instead.
  final VoidCallback? onEdit;

  /// "引用" in the long-press menu (and in 选择文字); null leaves it out.
  final ValueChanged<String>? onQuote;

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  /// The person can always flip back to the literal text of this message.
  bool _raw = false;

  String get _shown => GenerateHeader.parse(widget.text)?.description ?? widget.text;

  Future<void> _menu(BuildContext context) async {
    final onEdit = widget.onEdit;
    final onQuote = widget.onQuote;
    final action = await showMessageMenu(
      context,
      // 菜单顶部的预览也是显示,同样遮挡;预览会把 `**` 当粗体删掉,
      // 所以这里用 •。
      text: maskSecrets(_shown, mark: '•'),
      actions: [
        MessageAction.copy,
        MessageAction.selectText,
        if (onQuote != null) MessageAction.quote,
        if (onEdit != null) MessageAction.edit,
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case MessageAction.copy:
        await copyMessage(context, _shown);
      case MessageAction.selectText:
        await showSelectTextSheet(context, _shown, onQuote: onQuote);
      case MessageAction.edit:
        onEdit?.call();
      case MessageAction.quote:
        // The message's own words: an earlier quote it opened with stays out.
        onQuote?.call(splitQuote(_shown).body);
      case MessageAction.share || MessageAction.readAloud || MessageAction.regenerate || MessageAction.branch:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = DshSurfaces.of(context);
    final theme = Theme.of(context);
    final themeStyle = DshThemeStyle.of(context);
    final scheme = theme.colorScheme;
    final bubbleVariant = themeStyle.components.userBubbleStyle;
    final textColor = switch (bubbleVariant) {
      ThemeUserBubbleStyle.accent => scheme.onPrimaryContainer,
      ThemeUserBubbleStyle.minimal => scheme.onSurface,
      _ => surfaces.onUserBubble,
    };
    final style = AppType.chatBody(context, color: textColor);
    // A generation request (generation mode's parameter header on the first
    // line): the description is the bubble, the parameters a small line under
    // the bubble; the header itself is for the host's plugin.
    final generate = GenerateHeader.parse(widget.text);
    final shown = generate?.description ?? widget.text;
    final (:quote, :body) = splitQuote(shown);
    final interactive = widget.pendingLabel == null;
    final markdown = !_raw && looksLikeMarkdown(body);
    // Long-press selects in place. `@` references draw as chips; text with a
    // credential stays a plain SecretText. In markdown mode the same two
    // guarantees come from the masked text and the mention InlinePattern.
    Widget content = markdown
        ? MarkdownPatterns(
            patterns: [_bubbleMentionPattern],
            child: MarkdownBody(text: maskSecrets(body, mark: '•'), selectable: false),
          )
        : ReferenceText(quote == null ? shown : body, style: style, interactive: interactive);
    if (quote != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The quote is display too: credentials in it stay masked.
          BubbleQuote(maskSecrets(quote, mark: '•')),
          if (body.isNotEmpty) ...[const SizedBox(height: 6), content],
        ],
      );
    }

    // Its own semantics node, carrying the text; a screen reader's long-press
    // opens the menu.
    final Decoration bubbleDecoration = themeStyle.pack == null
        ? ShapeDecoration(color: surfaces.userBubble, shape: AppShape.bubble)
        : switch (bubbleVariant) {
            ThemeUserBubbleStyle.soft => ShapeDecoration(
              color: surfaces.userBubble,
              shape: themeStyle.bubbleShape(),
            ),
            ThemeUserBubbleStyle.outlined => ShapeDecoration(
              color: surfaces.userBubble.withValues(alpha: 0.72),
              shape: themeStyle.bubbleShape(
                themeStyle.userBubbleBorder ?? scheme.outlineVariant,
                themeStyle.borderWidth.clamp(0.8, 2.0),
              ),
            ),
            ThemeUserBubbleStyle.accent => ShapeDecoration(
              color: scheme.primaryContainer,
              shape: themeStyle.bubbleShape(),
            ),
            ThemeUserBubbleStyle.minimal => BoxDecoration(
              border: Border(
                right: BorderSide(color: themeStyle.rule ?? scheme.primary, width: 2.5),
              ),
            ),
          };
    final bubble = Semantics(
      container: true,
      header: true,
      onLongPress: () => _menu(context),
      child: DecoratedBox(
        decoration: bubbleDecoration,
        child: Padding(
          padding: themeStyle.pack == null
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              : EdgeInsets.symmetric(horizontal: themeStyle.shapes.bubblePadH, vertical: themeStyle.shapes.bubblePadV),
          child: MessageSelection(
            text: _shown,
            onQuote: widget.onQuote,
            onEdit: widget.onEdit,
            onMore: () => _menu(context),
            child: content,
          ),
        ),
      ),
    );

    final canToggle = looksLikeMarkdown(body);
    final roleTag = themeStyle.pack == null ? null : themeRoleTag(context, themeStyle, user: true);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.82;
        // Explicit nodes: the bubble's long-press node must not pull the
        // attachments' labels into one merged node.
        return Semantics(
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ?roleTag,
              if (widget.attachments case final a?)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: widget.pendingLabel == null ? a : Opacity(opacity: 0.72, child: a),
                ),
              if (widget.attachments != null && shown.trim().isNotEmpty) const SizedBox(height: 8),
              if (shown.trim().isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: AnimatedOpacity(
                    opacity: widget.pendingLabel == null ? 1 : 0.72,
                    duration: AppMotion.of(context, AppMotion.quick),
                    child: bubble,
                  ),
                ),
              if (canToggle)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _raw = !_raw),
                    child: Text(
                      _raw ? context.l10n.chatViewMarkdown : context.l10n.chatViewRaw,
                      style: theme.textTheme.labelSmall?.copyWith(color: DshColors.of(context).textTertiary),
                    ),
                  ),
                ),
              if (generate case (:final header, description: _))
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: shown.trim().isEmpty && widget.attachments == null ? 0 : GenerateParamsLine.gap,
                      right: GenerateParamsLine.inset,
                    ),
                    child: GenerateParamsLine(header: header),
                  ),
                ),
              _PendingSlot(label: widget.pendingLabel, icon: widget.pendingIcon, actions: widget.pendingActions),
            ],
          ),
        );
      },
    );
  }
}

/// [_PendingMeta] 的位置:回显时(同一行,标签变成 null)这一行和输入条上
/// 的胶囊同一节奏收起,气泡平稳落位,不会"啪"地矮一截。收起途中还画着
/// 最后一次的状态。
class _PendingSlot extends StatefulWidget {
  const _PendingSlot({required this.label, required this.icon, required this.actions});

  final String? label;
  final IconData icon;
  final List<(String, VoidCallback)> actions;

  @override
  State<_PendingSlot> createState() => _PendingSlotState();
}

class _PendingSlotState extends State<_PendingSlot> {
  late _PendingMeta? _last = _meta();

  _PendingMeta? _meta() => switch (widget.label) {
    final label? => _PendingMeta(label: label, icon: widget.icon, actions: widget.actions),
    null => null,
  };

  @override
  void didUpdateWidget(_PendingSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Echoed: keep the last line (without its buttons) while it folds away.
    _last =
        _meta() ??
        switch (_last) {
          final last? => _PendingMeta(label: last.label, icon: last.icon, actions: const []),
          null => null,
        };
  }

  @override
  Widget build(BuildContext context) => ExpandReveal(
    open: widget.label != null,
    duration: AppMotion.standard,
    curve: AppMotion.std,
    child: Align(alignment: Alignment.centerRight, child: _last ?? const SizedBox.shrink()),
  );
}

/// 乐观气泡下方的状态与文字操作;放不下时按可用宽度换行。
///
/// 右端与气泡的直边对齐(缩进 8):只有状态时状态文字留 8;有操作时最后
/// 一个操作自带左右 8 的点按区,文字同样停在 8 处。
class _PendingMeta extends StatelessWidget {
  const _PendingMeta({required this.label, required this.icon, required this.actions});

  final String label;
  final IconData icon;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = DshColors.of(context).textTertiary;
    final style = theme.textTheme.labelSmall?.copyWith(color: muted);
    return Padding(
      padding: EdgeInsets.only(top: actions.isEmpty ? 4 : 0, right: actions.isEmpty ? 8 : 0),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: muted),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: style)),
            ],
          ),
          for (final (text, onTap) in actions)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(text),
            ),
        ],
      ),
    );
  }
}

/// 「图像 · 3:4 · 2 张」 under a generation request: the pending line's look
/// (12 icon, small tertiary text), its right end 8 in from the bubble's
/// straight edge.
class GenerateParamsLine extends StatelessWidget {
  const GenerateParamsLine({super.key, required this.header});

  final GenerateHeader header;

  /// Bubble → line.
  static const gap = 4.0;

  /// The bubble's right edge → the line's end.
  static const inset = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = DshColors.of(context).textTertiary;
    final video = header.kind == GenerateKind.video;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(video ? AppIcons.generateVideo : AppIcons.generateImage, size: 12, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            mediaParamsLine(
              video: video,
              aspect: header.aspect,
              count: header.count,
              seconds: header.seconds,
              resolution: header.resolution,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.tabular(theme.textTheme.labelSmall!.copyWith(color: muted)),
          ),
        ),
      ],
    );
  }
}
