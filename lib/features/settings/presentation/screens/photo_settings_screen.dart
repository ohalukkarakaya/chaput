import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../me/application/me_controller.dart';
import '../../application/photo_settings_controller.dart';

class PhotoSettingsScreen extends ConsumerWidget {
  const PhotoSettingsScreen({super.key});

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(photoSettingsControllerProvider.notifier);

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (x == null) return;

    final ok = await ctrl.uploadPhotoFromPath(x.path);
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(photoSettingsControllerProvider.notifier);

    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fotoğrafı kaldır?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Profil fotoğrafın silinecek. Devam edilsin mi?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.25)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Kaldır', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (yes != true) return;

    final ok = await ctrl.deletePhoto();
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı kaldırıldı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meControllerProvider);
    final st = ref.watch(photoSettingsControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffEEF2F6),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('‹ Back', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _WhiteCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: meAsync.when(
                        loading: () => const Center(
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (_, __) => const Text('Could not load profile'),
                        data: (me) {
                          final user = me?.user;

                          final defaultAvatar = user?.defaultAvatar ?? '';
                          final profilePhotoUrl = user?.profilePhotoUrl;

                          final hasPhoto = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;

                          final imgUrl = hasPhoto ? profilePhotoUrl! : defaultAvatar;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Profile photo',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasPhoto ? 'This photo is visible on your profile.' : 'You are using a default avatar.',
                                style: TextStyle(color: Colors.black.withOpacity(0.60), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              // square preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  height: 260,
                                  color: Colors.black.withOpacity(0.06),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Eğer gerçek foto ise direkt cover göstermek istersen:
                                      // Image.network(imgUrl, fit: BoxFit.cover)
                                      // Ama default avatar da remote olabiliyor; unify:
                                      Center(
                                        child: ChaputCircleAvatar(
                                          width: 160,
                                          height: 160,
                                          radius: 999,
                                          borderWidth: 2,
                                          bgColor: Colors.black,
                                          isDefaultAvatar: !hasPhoto,
                                          imageUrl: imgUrl,
                                        ),
                                      ),

                                      if (st.isLoading)
                                        Container(
                                          color: Colors.black.withOpacity(0.12),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (st.errorMessage != null) ...[
                                Text(
                                  st.errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // actions
                              SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: st.isLoading ? null : () => _pickAndUpload(context, ref),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: Text(
                                    st.busyAction == 'upload' ? 'Uploading…' : 'Upload new photo',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: (!hasPhoto || st.isLoading) ? null : () => _confirmDelete(context, ref),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: BorderSide(color: Colors.black.withOpacity(0.12)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    st.busyAction == 'delete' ? 'Removing…' : 'Remove photo',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
