import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.link,

    /// Title ve subtitle (opsiyonel)
    this.title,
    this.subtitle,

    /// Paylaş butonu gösterilsin mi?
    this.showShareButton = true,
  });

  final String link;
  final String? title;
  final String? subtitle;
  final bool showShareButton;

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xffE9EEF3);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(bg, Colors.white, 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🆕 TITLE + SUBTITLE YAN YANA
          if (title != null || subtitle != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (title != null && subtitle != null)
                  const SizedBox(width: 8),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
              ],
            ),

          if (title != null || subtitle != null)
            const SizedBox(height: 8),

          // 🔗 Link satırı
          Row(
            children: [
              // Kopyala
              IconButton(
                tooltip: 'Kopyala',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link kopyalandı')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),

              const SizedBox(width: 6),

              // Link
              Expanded(
                child: SelectableText(
                  link,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.68),
                  ),
                ),
              ),

              // Paylaş (opsiyonel)
              if (showShareButton) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      link,
                      subject: 'Chaput linki',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text(
                    'Paylaş',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}