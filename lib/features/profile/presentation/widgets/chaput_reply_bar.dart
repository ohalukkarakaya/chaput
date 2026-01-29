import 'package:flutter/material.dart';
import 'black_glass.dart';

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
  });

  final Future<void> Function(String text, bool whisper) onSend;

  final VoidCallback? onFocus;
  final VoidCallback? onBlur;

  final Future<void> Function() onWhisperPaywall;
  final bool canWhisper;
  final bool whisperMode;
  final Future<void> Function() onToggleWhisper;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: BlackGlass(
        radius: 18,
        opacity: 0.65,
        borderOpacity: 0.15,
        child: Row(
          children: [
            const SizedBox(width: 10),

            // ✅ Fısılda butonu artık parent state’ine bağlı
            GestureDetector(
              onTap: () async {
                // Eğer parent canWhisper false ise bile,
                // parent onToggleWhisper içinde fresh check + paywall yapabilir.
                // Ama sen ister burada "kısa yol" bırak:
                if (!widget.canWhisper && !isWhisper) {
                  widget.onWhisperPaywall();
                  return;
                }
                widget.onToggleWhisper();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isWhisper ? Colors.white : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  'Fısılda',
                  style: TextStyle(
                    color: isWhisper ? Colors.black : Colors.white,
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
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: isWhisper ? 'Fısıltı mesajı...' : 'Mesaj yaz...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
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
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}