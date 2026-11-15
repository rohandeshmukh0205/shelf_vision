import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/detection_result.dart';

/// Draws shelf masks/boxes and product boxes over an image or camera preview.
///
/// [cover] = true  -> mapping for a BoxFit.cover camera preview
/// [cover] = false -> mapping for an image shown at its exact aspect ratio
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.result,
    this.cover = true,
    this.showMasks = true,
    this.showLabels = true,
  });

  final DetectionResult result;
  final bool cover;
  final bool showMasks;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DetectionPainter(
            result: result,
            cover: cover,
            showMasks: showMasks,
            showLabels: showLabels,
          ),
        ),
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter({
    required this.result,
    required this.cover,
    required this.showMasks,
    required this.showLabels,
  });

  final DetectionResult result;
  final bool cover;
  final bool showMasks;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (result.imageWidth == 0 || result.imageHeight == 0) return;

    final iw = result.imageWidth.toDouble();
    final ih = result.imageHeight.toDouble();
    final scale = cover
        ? math.max(size.width / iw, size.height / ih)
        : math.min(size.width / iw, size.height / ih);
    final ox = (size.width - iw * scale) / 2;
    final oy = (size.height - ih * scale) / 2;

    Rect map(Rect r) => Rect.fromLTRB(
          ox + r.left * iw * scale,
          oy + r.top * ih * scale,
          ox + r.right * iw * scale,
          oy + r.bottom * ih * scale,
        );

    // 1) shelf masks
    if (showMasks) {
      final fill = Paint()
        ..color = AppColors.shelf.withAlpha(48)
        ..isAntiAlias = false;
      for (final s in result.shelves) {
        if (s.maskRuns.isEmpty) continue;
        final path = Path();
        for (final run in s.maskRuns) {
          path.addRect(map(run));
        }
        canvas.drawPath(path, fill);
      }
    }

    // 2) shelf boxes
    final shelfPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.shelf;
    for (final s in result.shelves) {
      final r = map(s.box);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)), shelfPaint);
      _label(canvas, size, 'Shelf ${s.percent}', r, AppColors.shelf, 12);
    }

    // 3) products / empty slots
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in result.products) {
      final r = map(p.box);
      final color = p.isEmptySpace ? AppColors.empty : AppColors.product;
      boxPaint.color = color;
      canvas.drawRect(r, boxPaint);
      if (showLabels && r.width > 46 && r.height > 18) {
        _label(canvas, size, '${p.label} ${p.percent}', r, color, 10);
      }
    }
  }

  void _label(Canvas canvas, Size size, String text, Rect box, Color color,
      double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(40, box.width));

    const padH = 5.0, padV = 2.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    var top = box.top - h;
    if (top < 0) top = box.top;
    final left = box.left.clamp(0.0, math.max(0.0, size.width - w)).toDouble();
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(5),
    );
    canvas.drawRRect(bg, Paint()..color = color);
    tp.paint(canvas, Offset(left + padH, top + padV));
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter old) =>
      old.result != result ||
      old.cover != cover ||
      old.showMasks != showMasks ||
      old.showLabels != showLabels;
}
