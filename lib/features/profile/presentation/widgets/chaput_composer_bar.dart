import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/ui/widgets/app_text_context_menu.dart';

class ChatComposerBar extends StatefulWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.onAvatarTap,
    required this.onSend,
    required this.anonEnabled,
    required this.highlightEnabled,
    required this.onOptionsTap,
    required this.onOptionsEmptyTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  final String? avatarUrl;
  final bool isDefaultAvatar;
  final VoidCallback onAvatarTap;

  final bool anonEnabled;
  final bool highlightEnabled;
  final VoidCallback onOptionsTap;
  final VoidCallback onOptionsEmptyTap;

  final VoidCallback onSend;

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _syncHasText();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _syncHasText();
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next == _hasText) return;
    setState(() => _hasText = next);
  }

  void _syncHasText() {
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.chaputBlack.withOpacity(0.55),
            border: Border.all(color: AppColors.chaputWhite.withOpacity(0.10)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _InkAvatarButton(
                  avatarUrl: widget.avatarUrl,
                  isDefaultAvatar: widget.isDefaultAvatar,
                  onTap: widget.onAvatarTap,
                ),
                const SizedBox(width: 10),
                if (widget.anonEnabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.chaputWhite.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.chaputWhite.withOpacity(0.10)),
                    ),
                    child: Text(
                      context.t('chat.anon_label'),
                      style: TextStyle(
                        color: AppColors.chaputWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textInputAction: TextInputAction.send,
                    contextMenuBuilder: appTextContextMenuBuilder,
                    onSubmitted: (_) => widget.onSend(),
                    style: const TextStyle(color: AppColors.chaputWhite, fontSize: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.t('chat.message_hint'),
                      hintStyle: const TextStyle(color: AppColors.chaputWhite54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: !_hasText
                      ? _RoundIconButton(
                          key: const ValueKey('disabled'),
                          icon: Icons.tune,
                          onTap: widget.onOptionsEmptyTap,
                        )
                      : _RoundIconButton(
                          key: const ValueKey('enabled'),
                          icon: Icons.tune,
                          onTap: widget.onOptionsTap,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, super.key});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 22,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.chaputWhite.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.chaputWhite, size: 22),
      ),
    );
  }
}

class _InkAvatarButton extends StatelessWidget {
  const _InkAvatarButton({
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.onTap,
  });

  final String? avatarUrl;
  final bool isDefaultAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 22,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.chaputWhite.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? const ColoredBox(color: AppColors.chaputTransparent)
              : ChaputCircleAvatar(
                  isDefaultAvatar: isDefaultAvatar,
                  imageUrl: avatarUrl!,
                ),
        ),
      ),
    );
  }
}
