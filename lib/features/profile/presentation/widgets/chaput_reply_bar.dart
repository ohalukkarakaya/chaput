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
  });

  final Future<void> Function(String text, bool whisper) onSend;
  final VoidCallback onWhisperPaywall;
  final bool canWhisper;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;

  @override
  State<ChaputReplyBar> createState() => _ChaputReplyBarState();
}

class _ChaputReplyBarState extends State<ChaputReplyBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _whisper = false;

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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final whisper = _whisper;
    if (whisper && !widget.canWhisper) {
      widget.onWhisperPaywall();
      return;
    }
    _controller.clear();
    await widget.onSend(text, whisper);
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) {
      widget.onFocus?.call();
    } else {
      widget.onBlur?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: BlackGlass(
        radius: 18,
        opacity: 0.65,
        borderOpacity: 0.15,
        child: Row(
          children: [
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                if (!widget.canWhisper) {
                  widget.onWhisperPaywall();
                  return;
                }
                setState(() => _whisper = !_whisper);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _whisper ? Colors.white : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  'Fısılda',
                  style: TextStyle(
                    color: _whisper ? Colors.black : Colors.white,
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
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz...',
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
