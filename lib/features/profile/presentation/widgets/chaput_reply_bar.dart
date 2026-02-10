import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'black_glass.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ChaputReplyBar extends StatefulWidget {
  const ChaputReplyBar({
    super.key,
    required this.onSend,
    required this.onWhisperPaywall,
    required this.canWhisper,
    this.onFocus,
    this.onBlur,
    required this.whisperMode,
    required this.onToggleWhisper,
    this.replyAuthor,
    this.replyBody,
    this.onClearReply,
  });

  final Future<void> Function(String text, bool whisper) onSend;

  final VoidCallback? onFocus;
  final VoidCallback? onBlur;

  final Future<void> Function() onWhisperPaywall;
  final bool canWhisper;
  final bool whisperMode;
  final Future<void> Function() onToggleWhisper;
  final String? replyAuthor;
  final String? replyBody;
  final VoidCallback? onClearReply;

  @override
  State<ChaputReplyBar> createState() => _ChaputReplyBarState();
}

class _ChaputReplyBarState extends State<ChaputReplyBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) {
      widget.onFocus?.call();
    } else {
      widget.onBlur?.call();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final whisper = widget.whisperMode;

    _controller.clear();
    await widget.onSend(text, whisper);
  }

  @override
  Widget build(BuildContext context) {
    final isWhisper = widget.whisperMode;
    final showReply = widget.replyBody != null && widget.replyBody!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: BlackGlass(
        radius: 18,
        opacity: 0.65,
        borderOpacity: 0.15,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showReply)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.chaputWhite.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.chaputWhite.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.replyAuthor ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.chaputWhite.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.replyBody ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.chaputWhite.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onClearReply,
                        child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 14, color: AppColors.chaputWhite.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            Row(
              children: [
                const SizedBox(width: 10),

                // ✅ Fısılda butonu artık parent state’ine bağlı
                GestureDetector(
                  onTap: () async {
                    widget.onToggleWhisper();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isWhisper ? AppColors.chaputWhite : AppColors.chaputWhite.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.chaputWhite.withOpacity(0.18)),
                    ),
                    child: Text(
                      context.t('chat.whisper_label'),
                      style: TextStyle(
                        color: isWhisper ? AppColors.chaputBlack : AppColors.chaputWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: AppColors.chaputWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: isWhisper ? context.t('chat.whisper_hint') : context.t('chat.message_input_hint'),
                      hintStyle: TextStyle(color: AppColors.chaputWhite.withOpacity(0.4)),
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: AppColors.chaputWhite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
