import 'package:flutter/material.dart';

import '../../../features/helpers/image_video_helpers/image_video_helpers.dart';
import '../../constants/app_colors.dart';
import '../../utils/parse_default_avatar_url.dart';
import 'chaput_default_avatar.dart';
import 'data/default_avatar_url_model.dart';

class ChaputCircleAvatar extends StatefulWidget {
  final bool isDefaultAvatar;
  final String imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final Color? bgColor;
  final double borderWidth;

  const ChaputCircleAvatar(
    {
      super.key,
      required this.isDefaultAvatar,
      required this.imageUrl,
      this.width = 40.0,
      this.height = 40.0,
      this.radius = 100.0,
      this.bgColor = AppColors.chaputWhite,
      this.borderWidth = 4.0
    }
  );

  @override
  State<ChaputCircleAvatar> createState() => _ChaputCircleAvatarState();
}

class _ChaputCircleAvatarState extends State<ChaputCircleAvatar> {
  @override
  Widget build(BuildContext context) {

    DefaultAvatarUrl? defaultAvatarUrlObject;
    bool isErrorOccured = false;

    if( widget.isDefaultAvatar ){
      setState(() { defaultAvatarUrlObject = parseDefaultAvatarUrl(widget.imageUrl); });
    }

    if(
      widget.isDefaultAvatar
      && ( defaultAvatarUrlObject == null || defaultAvatarUrlObject!.isInvalidUrl )
    ){
      setState(() { isErrorOccured = true; });
    }

    return Container(
      height: widget.height,
      width: widget.width,
      padding: EdgeInsets.all( widget.borderWidth ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all( Radius.circular( widget.radius ) ),
        color: widget.bgColor,
      ),
      child: widget.isDefaultAvatar && !isErrorOccured
              ? ChaputDefaultAvatar(
                backgroundImagePath: defaultAvatarUrlObject!.backgroundPath,
                avatarImagePath: defaultAvatarUrlObject!.avatarPath,
                width: widget.width!,
                height: widget.height!,
                borderRadius: widget.radius,
              )
              : !( widget.isDefaultAvatar) && isErrorOccured
                  ? const SizedBox()
                  : ClipRRect(
                    borderRadius: BorderRadius.all( Radius.circular( widget.radius ) ),
                    child: Image.network(
                      ImageVideoHelpers.getFullUrl(widget.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  )
    );
  }
}
