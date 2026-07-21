import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import '../../domain/profile_preview.dart';

class ProfileAvatarHero extends StatelessWidget {
  const ProfileAvatarHero({
    super.key,
    required this.preview,
    required this.width,
    required this.height,
    this.radius = 999,
    this.borderWidth = 2,
    this.bgColor = AppColors.chaputBlack,
    this.enabled = true,
  });

  final ProfilePreview preview;
  final double width;
  final double height;
  final double radius;
  final double borderWidth;
  final Color bgColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.avatarImageUrl;
    final avatar = imageUrl.isEmpty
        ? Container(
            width: width,
            height: height,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          )
        : ChaputCircleAvatar(
            width: width,
            height: height,
            radius: radius,
            borderWidth: borderWidth,
            bgColor: bgColor,
            isDefaultAvatar: preview.isDefaultAvatar,
            imageUrl: imageUrl,
          );

    if (!enabled || preview.id.isEmpty) return avatar;

    return Hero(
      tag: profileAvatarHeroTag(preview.id),
      transitionOnUserGestures: true,
      child: Material(type: MaterialType.transparency, child: avatar),
    );
  }
}
