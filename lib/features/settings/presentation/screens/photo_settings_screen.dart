import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../me/application/me_controller.dart';
import '../../application/photo_settings_controller.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

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
        SnackBar(content: Text(context.t('photo.updated'))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(photoSettingsControllerProvider.notifier);

    final yes = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.chaputBlack.withOpacity(0.25),
      builder: (_) => Dialog(
        backgroundColor: AppColors.chaputTransparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.chaputBlack.withOpacity(0.78),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.chaputWhite.withOpacity(0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('photo.remove_title'),
                    style: TextStyle(
                      color: AppColors.chaputWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('photo.remove_body'),
                    style: TextStyle(
                      color: AppColors.chaputWhite.withOpacity(0.72),
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
                            foregroundColor: AppColors.chaputWhite,
                            side: BorderSide(color: AppColors.chaputWhite.withOpacity(0.25)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(context.t('common.cancel'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.chaputWhite,
                            foregroundColor: AppColors.chaputBlack,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(context.t('common.remove'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
        SnackBar(content: Text(context.t('photo.removed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meControllerProvider);
    final st = ref.watch(photoSettingsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
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
                        child: Text(context.t('common.back'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                        error: (_, __) => Text(context.t('photo.load_failed')),
                        data: (me) {
                          final user = me?.user;

                          final defaultAvatar = user?.defaultAvatar ?? '';
                          final profilePhotoUrl = user?.profilePhotoUrl;

                          final hasPhoto = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;

                          final imgUrl = hasPhoto ? profilePhotoUrl! : defaultAvatar;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.t('photo.title'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasPhoto
                                    ? context.t('photo.visible_hint')
                                    : context.t('photo.default_hint'),
                                style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.60), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              // square preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  height: 260,
                                  color: AppColors.chaputBlack.withOpacity(0.06),
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
                                          bgColor: AppColors.chaputBlack,
                                          isDefaultAvatar: !hasPhoto,
                                          imageUrl: imgUrl,
                                        ),
                                      ),

                                      if (st.isLoading)
                                        Container(
                                          color: AppColors.chaputBlack.withOpacity(0.12),
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
                                  context.t(st.errorMessage!),
                                  style: const TextStyle(color: AppColors.chaputMaterialRed, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // actions
                              SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: st.isLoading ? null : () => _pickAndUpload(context, ref),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.chaputBlack,
                                    foregroundColor: AppColors.chaputWhite,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: Text(
                                    st.busyAction == 'upload'
                                        ? context.t('photo.uploading')
                                        : context.t('photo.upload'),
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
                                    foregroundColor: AppColors.chaputBlack,
                                    side: BorderSide(color: AppColors.chaputBlack.withOpacity(0.12)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    st.busyAction == 'delete'
                                        ? context.t('photo.removing')
                                        : context.t('photo.remove'),
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
        color: AppColors.chaputWhite.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: AppColors.chaputBlack.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
