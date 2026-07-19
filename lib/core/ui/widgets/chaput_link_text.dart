import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../i18n/app_localizations.dart';
import 'chaput_action_prompt_sheet.dart';

/// Renders plain message text while making HTTP(S) links explicit and safe to
/// leave the app through.
class ChaputLinkText extends StatefulWidget {
  const ChaputLinkText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<ChaputLinkText> createState() => _ChaputLinkTextState();
}

class _ChaputLinkTextState extends State<ChaputLinkText> {
  static final RegExp _urlPattern = RegExp(
    r'(?:(?:https?://)|(?:www\.))[^\s<>]+',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String rawUrl) async {
    final accepted = await showChaputActionPromptSheet(
      context,
      title: context.t('external_link.title'),
      body: context.t('external_link.body'),
      confirmLabel: context.t('common.continue'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!accepted || !mounted) return;

    final normalized = rawUrl.startsWith('www.') ? 'https://$rawUrl' : rawUrl;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) return;

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      // An unavailable external handler must not disturb the conversation.
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }

      final matchedText = match.group(0)!;
      final linkEnd = _trimTrailingPunctuation(matchedText);
      final urlText = matchedText.substring(0, linkEnd);
      final trailingText = matchedText.substring(linkEnd);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openLink(urlText);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: urlText,
          recognizer: recognizer,
          style: widget.style.copyWith(
            color: AppColors.chaputLightBlueAccent,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.chaputLightBlueAccent,
            decorationThickness: 1.25,
          ),
        ),
      );
      if (trailingText.isNotEmpty) {
        spans.add(TextSpan(text: trailingText));
      }
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  int _trimTrailingPunctuation(String value) {
    var end = value.length;
    while (end > 0 && '.,!?;:'.contains(value[end - 1])) {
      end--;
    }
    return end;
  }
}
