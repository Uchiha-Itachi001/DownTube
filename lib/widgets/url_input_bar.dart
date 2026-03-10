import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'app_notification.dart';

class UrlInputBar extends StatefulWidget {
  final String placeholder;
  final Function(String url)? onAnalyze;
  final VoidCallback? onPaste;
  final bool compact;
  /// Optional inline status shown below the bar (error / success / fetching)
  final String? statusMessage;
  final NotificationType statusType;

  const UrlInputBar({
    super.key,
    this.placeholder = 'Paste video URL from YouTube, Vimeo, Twitch...',
    this.onAnalyze,
    this.onPaste,
    this.compact = false,
    this.statusMessage,
    this.statusType = NotificationType.info,
  });

  @override
  State<UrlInputBar> createState() => _UrlInputBarState();
}

class _UrlInputBarState extends State<UrlInputBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textCtrl = TextEditingController();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _textCtrl.text = text;
      _textCtrl.selection =
          TextSelection.collapsed(offset: text.length);
    }
    widget.onPaste?.call();
  }

  void _triggerAnalyze() {
    final url = _textCtrl.text.trim();
    if (url.isEmpty) {
      showAppNotification(
        context,
        type: NotificationType.error,
        message: 'Please paste a video URL first',
        duration: const Duration(seconds: 3),
      );
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      showAppNotification(
        context,
        type: NotificationType.error,
        message: 'Invalid URL — must start with http:// or https://',
        duration: const Duration(seconds: 3),
      );
      return;
    }
    widget.onAnalyze?.call(url);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.fromLTRB(16, widget.compact ? 4 : 6, widget.compact ? 4 : 6, widget.compact ? 4 : 6),
          decoration: BoxDecoration(
            color: _focused
                ? const Color(0xFF0A110A).withOpacity(0.75)
                : const Color(0xFF080C09).withOpacity(0.55),
            border: Border.all(
              color: _focused
                  ? AppColors.accent.withOpacity(0.85)
                  : AppColors.accent.withOpacity(0.3),
              width: _focused ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.18),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.08),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.06),
                      blurRadius: 12,
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(Icons.link, size: 16,
                  color: _focused ? AppColors.accent.withOpacity(0.7) : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: _textCtrl,
                  style: AppTextStyles.outfit(fontSize: widget.compact ? 12 : 13.5),
                  onSubmitted: (_) => _triggerAnalyze(),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTextStyles.outfit(
                        fontSize: widget.compact ? 12 : 13.5, color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 10),
                _PasteButton(onTap: _pasteFromClipboard),
                const SizedBox(width: 6),
              ],
              _AnalyzeButton(
                onTap: _triggerAnalyze,
                compact: widget.compact,
              ),
            ],
          ),
        ),
        // Inline fused status card
        if (widget.statusMessage != null && widget.statusMessage!.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppNotificationCard(
            type: widget.statusType,
            message: widget.statusMessage!,
          ),
        ],
      ],
    );
  }
}

class _PasteButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _PasteButton({this.onTap});

  @override
  State<_PasteButton> createState() => _PasteButtonState();
}

class _PasteButtonState extends State<_PasteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.accent.withOpacity(0.08) : Colors.transparent,
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.accent.withOpacity(0.40),
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_paste_rounded, size: 12,
                  color: _hovered ? AppColors.accent : AppColors.accent.withOpacity(0.7)),
              const SizedBox(width: 5),
              Text(
                'Paste',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppColors.accent : AppColors.accent.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzeButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool compact;
  const _AnalyzeButton({this.onTap, this.compact = false});

  @override
  State<_AnalyzeButton> createState() => _AnalyzeButtonState();
}

class _AnalyzeButtonState extends State<_AnalyzeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 20,
            vertical: widget.compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: _hovered ? 28 : 20,
                offset: Offset(0, _hovered ? 6 : 4),
              ),
            ],
          ),
          transform: _hovered
              ? (Matrix4.identity()..translate(0.0, -1.0))
              : Matrix4.identity(),
          child: widget.compact
              ? const Icon(Icons.add, size: 16, color: Colors.black)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ANALYZE',
                      style: AppTextStyles.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
