import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';

import '../core/constants/app_constants.dart';

/// A 1x3x640x640 float tensor plus the info needed to map boxes back.
class PreprocessedInput {
  const PreprocessedInput({
    required this.tensor,
    required this.width,
    required this.height,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.inputSize,
  });

  final Float32List tensor;

  /// Size of the upright source image.
  final int width;
  final int height;

  /// Letterbox parameters.
  final double scale;
  final double padX;
  final double padY;
  final int inputSize;

  double normX(double px) =>
      ((px - padX) / scale / width).clamp(0.0, 1.0).toDouble();
  double normY(double py) =>
      ((py - padY) / scale / height).clamp(0.0, 1.0).toDouble();

  Rect normalizedRect(double x1, double y1, double x2, double y2) =>
      Rect.fromLTRB(normX(x1), normY(y1), normX(x2), normY(y2));
}

class _YuvJob {
  _YuvJob({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotation,
    required this.inputSize,
  });
  final int width, height;
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;
  final int rotation;
  final int inputSize;
}

class _RgbaJob {
  _RgbaJob(this.rgba, this.width, this.height, this.inputSize);
  final Uint8List rgba;
  final int width, height, inputSize;
}

/// Camera frame / image -> letterboxed, normalised CHW tensor.
/// Heavy loops run in a background isolate to keep the UI smooth.
class ImageProcessingService {
  Future<PreprocessedInput> fromCameraImage(CameraImage image, int rotation) {
    final job = _YuvJob(
      width: image.width,
      height: image.height,
      y: image.planes[0].bytes,
      u: image.planes[1].bytes,
      v: image.planes[2].bytes,
      yRowStride: image.planes[0].bytesPerRow,
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      rotation: rotation,
      inputSize: AppConstants.inputSize,
    );
    return Isolate.run(() => _preprocessYuv(job));
  }

  Future<PreprocessedInput> fromRgba(Uint8List rgba, int width, int height) {
    final job = _RgbaJob(rgba, width, height, AppConstants.inputSize);
    return Isolate.run(() => _preprocessRgba(job));
  }
}

const double _padValue = 114 / 255; // Ultralytics letterbox grey

PreprocessedInput _preprocessYuv(_YuvJob j) {
  final s = j.inputSize;
  final rot = j.rotation % 360;
  final swap = rot == 90 || rot == 270;
  final w = swap ? j.height : j.width; // upright size
  final h = swap ? j.width : j.height;

  final scale = math.min(s / w, s / h);
  final newW = math.max(1, (w * scale).round());
  final newH = math.max(1, (h * scale).round());
  final padX = (s - newW) ~/ 2;
  final padY = (s - newH) ~/ 2;

  final plane = s * s;
  final out = Float32List(3 * plane);
  out.fillRange(0, out.length, _padValue);

  final uxs = Int32List(newW);
  for (var dx = 0; dx < newW; dx++) {
    uxs[dx] = math.min(w - 1, ((dx + 0.5) / scale).floor());
  }

  final sw = j.width;
  final sh = j.height;
  final yMax = j.y.length - 1;
  final uMax = j.u.length - 1;
  final vMax = j.v.length - 1;

  for (var dy = 0; dy < newH; dy++) {
    final uy = math.min(h - 1, ((dy + 0.5) / scale).floor());
    final rowBase = (padY + dy) * s + padX;
    for (var dx = 0; dx < newW; dx++) {
      final ux = uxs[dx];
      int sx;
      int sy;
      switch (rot) {
        case 90:
          sx = uy;
          sy = sh - 1 - ux;
          break;
        case 180:
          sx = sw - 1 - ux;
          sy = sh - 1 - uy;
          break;
        case 270:
          sx = sw - 1 - uy;
          sy = ux;
          break;
        default:
          sx = ux;
          sy = uy;
      }

      final yv = j.y[math.min(yMax, sy * j.yRowStride + sx)];
      final uvIndex = (sy >> 1) * j.uvRowStride + (sx >> 1) * j.uvPixelStride;
      final u = j.u[math.min(uMax, uvIndex)] - 128;
      final v = j.v[math.min(vMax, uvIndex)] - 128;

      var r = yv + 1.402 * v;
      var g = yv - 0.344136 * u - 0.714136 * v;
      var b = yv + 1.772 * u;
      r = r < 0 ? 0 : (r > 255 ? 255 : r);
      g = g < 0 ? 0 : (g > 255 ? 255 : g);
      b = b < 0 ? 0 : (b > 255 ? 255 : b);

      final idx = rowBase + dx;
      out[idx] = r / 255;
      out[plane + idx] = g / 255;
      out[2 * plane + idx] = b / 255;
    }
  }

  return PreprocessedInput(
    tensor: out,
    width: w,
    height: h,
    scale: scale,
    padX: padX.toDouble(),
    padY: padY.toDouble(),
    inputSize: s,
  );
}

PreprocessedInput _preprocessRgba(_RgbaJob j) {
  final s = j.inputSize;
  final w = j.width;
  final h = j.height;
  final scale = math.min(s / w, s / h);
  final newW = math.max(1, (w * scale).round());
  final newH = math.max(1, (h * scale).round());
  final padX = (s - newW) ~/ 2;
  final padY = (s - newH) ~/ 2;

  final plane = s * s;
  final out = Float32List(3 * plane);
  out.fillRange(0, out.length, _padValue);

  final sxs = Int32List(newW);
  for (var dx = 0; dx < newW; dx++) {
    sxs[dx] = math.min(w - 1, ((dx + 0.5) / scale).floor());
  }

  for (var dy = 0; dy < newH; dy++) {
    final sy = math.min(h - 1, ((dy + 0.5) / scale).floor());
    final rowBase = (padY + dy) * s + padX;
    final srcRow = sy * w;
    for (var dx = 0; dx < newW; dx++) {
      final p = (srcRow + sxs[dx]) * 4;
      final idx = rowBase + dx;
      out[idx] = j.rgba[p] / 255;
      out[plane + idx] = j.rgba[p + 1] / 255;
      out[2 * plane + idx] = j.rgba[p + 2] / 255;
    }
  }

  return PreprocessedInput(
    tensor: out,
    width: w,
    height: h,
    scale: scale,
    padX: padX.toDouble(),
    padY: padY.toDouble(),
    inputSize: s,
  );
}
