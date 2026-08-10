import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../features/helpers/image_video_helpers/image_video_helpers.dart';
import '../../domain/profile_gallery_photo.dart';

class ProfileGalleryStrip extends StatelessWidget {
  const ProfileGalleryStrip({
    super.key,
    required this.photos,
    required this.isMe,
    required this.isUploading,
    required this.deletingPhotoId,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ProfileGalleryPhoto> photos;
  final bool isMe;
  final bool isUploading;
  final String? deletingPhotoId;
  final VoidCallback onAdd;
  final ValueChanged<ProfileGalleryPhoto> onRemove;

  static const _gap = 8.0;
  static const _maxPhotos = ProfileGalleryPhoto.maxPhotos;
  static const _fallbackMaxWidth = 360.0;
  static const _padding = 10.0;
  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final visiblePhotos = photos.take(_maxPhotos).toList(growable: false);
    final count = visiblePhotos.length;
    if (!isMe && count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMaxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _fallbackMaxWidth;
        final maxWidth = math.max(0.0, rawMaxWidth);
        final tileSize = math.max(
          0.0,
          (maxWidth - (_padding * 2) - (_gap * (_maxPhotos - 1))) / _maxPhotos,
        );
        final panelHeight = tileSize + (_padding * 2);
        final hasAdd = isMe && count < _maxPhotos;
        final photoWidth = count == 0
            ? 0.0
            : count == _maxPhotos
            ? maxWidth
            : (_padding * 2) + (tileSize * count) + (_gap * (count - 1));
        final addWidth = count == 0
            ? maxWidth
            : math.max(0.0, maxWidth - photoWidth - 10);

        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                _GlassPanel(
                  width: math.min(photoWidth, maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < visiblePhotos.length; i++) ...[
                        _GalleryTile(
                          key: ValueKey(visiblePhotos[i].id),
                          photo: visiblePhotos[i],
                          isMe: isMe,
                          isDeleting: deletingPhotoId == visiblePhotos[i].id,
                          onRemove: () => onRemove(visiblePhotos[i]),
                          size: tileSize,
                        ),
                        if (i < visiblePhotos.length - 1)
                          const SizedBox(width: _gap),
                      ],
                    ],
                  ),
                ),
              if (hasAdd && count > 0) const SizedBox(width: 10),
              if (hasAdd)
                _GlassAddButton(
                  width: math.min(addWidth, maxWidth),
                  height: panelHeight,
                  isUploading: isUploading,
                  onTap: onAdd,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ProfileGalleryStrip._radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: width,
          padding: const EdgeInsets.all(ProfileGalleryStrip._padding),
          decoration: BoxDecoration(
            color: AppColors.chaputWhite.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(ProfileGalleryStrip._radius),
            border: Border.all(
              color: AppColors.chaputWhite.withValues(alpha: 0.25),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.photo,
    required this.isMe,
    required this.isDeleting,
    required this.onRemove,
    required this.size,
  });

  final ProfileGalleryPhoto photo;
  final bool isMe;
  final bool isDeleting;
  final VoidCallback onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                ImageVideoHelpers.getFullUrl(photo.photoUrl),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (isMe)
            Positioned(
              top: -7,
              right: -7,
              child: Material(
                color: AppColors.chaputTransparent,
                child: InkWell(
                  onTap: isDeleting ? null : onRemove,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.chaputGrey300.withValues(alpha: 0.92),
                      border: Border.all(
                        color: AppColors.chaputWhite.withValues(alpha: 0.55),
                      ),
                    ),
                    child: isDeleting
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: AppColors.chaputBlack87,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassAddButton extends StatelessWidget {
  const _GlassAddButton({
    required this.width,
    required this.height,
    required this.isUploading,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ProfileGalleryStrip._radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.chaputWhite.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(ProfileGalleryStrip._radius),
            border: Border.all(
              color: AppColors.chaputWhite.withValues(alpha: 0.25),
            ),
          ),
          child: Material(
            color: AppColors.chaputTransparent,
            child: InkWell(
              onTap: isUploading ? null : onTap,
              borderRadius: BorderRadius.circular(ProfileGalleryStrip._radius),
              child: Center(
                child: isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        size: 34,
                        color: AppColors.chaputBlack87,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
