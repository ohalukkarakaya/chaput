import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/widgets/glass_cta_button.dart';
import '../../../feedback/presentation/widgets/global_feedback_trigger.dart';
import '../../application/photo_upload_preparer.dart';
import '../../application/square_photo_crop.dart';

Future<PreparedPhotoUpload?> showPhotoCropScreen(
  BuildContext context, {
  required String path,
}) => showGeneralDialog<PreparedPhotoUpload>(
  context: context,
  useRootNavigator: false,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 280),
  // A popup keeps the underlying profile mounted and avoids the page-route
  // suspension that would dispose and recreate its native tree renderer.
  pageBuilder: (_, _, _) => PhotoCropScreen(path: path),
  transitionBuilder: (_, animation, _, child) => SlideTransition(
    position: animation.drive(
      Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    ),
    child: child,
  ),
);

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.path});

  final String path;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  ui.Image? _image;
  SquarePhotoCrop? _crop;
  Rect? _gestureStartRect;
  Offset _gestureStartFocalPoint = Offset.zero;
  bool _saving = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          // Bound memory even when a platform picker returns a full-size image.
          final ratio = math.min(
            1.0,
            4096 / math.max(descriptor.width, descriptor.height),
          );
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * ratio).round()),
            targetHeight: math.max(1, (descriptor.height * ratio).round()),
          );
          try {
            final frame = await codec.getNextFrame();
            if (!mounted) {
              frame.image.dispose();
              return;
            }
            setState(() {
              _image = frame.image;
              _crop = SquarePhotoCrop(
                Size(_image!.width.toDouble(), _image!.height.toDouble()),
              );
            });
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorKey = 'errors.image_decode_failed');
      }
    }
  }

  Future<void> _confirm() async {
    if (_saving || _image == null || _crop == null) return;
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    try {
      final result = await exportSquarePhoto(_image!, _crop!.rect);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorKey = 'photo.crop_failed';
        });
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FeedbackGestureBlocker(child: _buildEditor(context));

  Widget _buildEditor(BuildContext context) {
    final crop = _crop;
    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: context.t('common.cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          context.t('photo.crop_title'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.chaputWhite.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                            color: AppColors.chaputBlack.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.t('photo.crop_hint'),
                            style: TextStyle(
                              color: AppColors.chaputBlack.withValues(
                                alpha: 0.60,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (_image == null || crop == null) {
                                  return Center(
                                    child: _errorKey == null
                                        ? const CircularProgressIndicator(
                                            color: AppColors.chaputBlack,
                                          )
                                        : const Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                          ),
                                  );
                                }
                                return Semantics(
                                  label: context.t('photo.crop_hint'),
                                  child: GestureDetector(
                                    key: const Key('photo-crop-viewport'),
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: _saving
                                        ? null
                                        : (details) {
                                            _gestureStartRect = crop.rect;
                                            _gestureStartFocalPoint =
                                                details.localFocalPoint;
                                          },
                                    onScaleUpdate: _saving
                                        ? null
                                        : (details) {
                                            if (_gestureStartRect == null) {
                                              return;
                                            }
                                            setState(
                                              () => crop.updateGesture(
                                                startRect: _gestureStartRect!,
                                                startFocalPoint:
                                                    _gestureStartFocalPoint,
                                                focalPoint:
                                                    details.localFocalPoint,
                                                viewportSide:
                                                    constraints.maxWidth,
                                                scale: details.scale,
                                              ),
                                            );
                                          },
                                    child: CustomPaint(
                                      painter: _CropPainter(_image!, crop.rect),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.zoom_out_rounded,
                                color: AppColors.chaputBlack,
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1,
                                  max: SquarePhotoCrop.maxZoom,
                                  value: (crop?.zoom ?? 1).clamp(
                                    1.0,
                                    SquarePhotoCrop.maxZoom,
                                  ),
                                  activeColor: AppColors.chaputBlack,
                                  inactiveColor: AppColors.chaputBlack
                                      .withValues(alpha: 0.10),
                                  semanticFormatterCallback: (value) =>
                                      '${value.toStringAsFixed(1)}×',
                                  onChanged: crop == null || _saving
                                      ? null
                                      : (value) =>
                                            setState(() => crop.setZoom(value)),
                                ),
                              ),
                              const Icon(
                                Icons.zoom_in_rounded,
                                color: AppColors.chaputBlack,
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: crop == null || _saving
                                ? null
                                : () => setState(crop.reset),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.chaputBlack,
                            ),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: Text(context.t('photo.crop_reset')),
                          ),
                          if (_errorKey != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              context.t(_errorKey!),
                              style: const TextStyle(
                                color: AppColors.chaputErrorRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GlassCtaButton(
                    text: context.t('photo.crop_confirm'),
                    enabled: crop != null,
                    isLoading: _saving,
                    onTap: _confirm,
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

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.crop);

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = AppColors.chaputWhite);
    canvas.drawImageRect(
      image,
      crop,
      bounds,
      Paint()..filterQuality = FilterQuality.high,
    );
    final grid = Paint()
      ..color = AppColors.chaputWhite.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final offset = size.width * i / 3;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), grid);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), grid);
    }
    canvas.drawRect(
      bounds.deflate(1),
      Paint()
        ..color = AppColors.chaputWhite.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      image != oldDelegate.image || crop != oldDelegate.crop;
}
