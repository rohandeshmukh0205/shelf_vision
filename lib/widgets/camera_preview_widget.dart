import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-area camera preview (cover fit) with optional overlay, pinch-to-zoom
/// and tap-to-focus hooks.
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.overlay,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onTapNormalized,
  });

  final CameraController controller;
  final Widget? overlay;
  final VoidCallback? onScaleStart;
  final ValueChanged<double>? onScaleUpdate;
  final ValueChanged<Offset>? onTapNormalized;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (!controller.value.isInitialized || size == null) {
      return const ColoredBox(color: Colors.black);
    }
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => onScaleStart?.call(),
        onScaleUpdate: (d) => onScaleUpdate?.call(d.scale),
        onTapUp: (d) => onTapNormalized?.call(Offset(
          d.localPosition.dx / c.maxWidth,
          d.localPosition.dy / c.maxHeight,
        )),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  // preview size is reported in landscape; swap for portrait
                  width: size.height,
                  height: size.width,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      );
    });
  }
}
