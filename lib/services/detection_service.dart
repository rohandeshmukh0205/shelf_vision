import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/yolo_utils.dart';
import '../models/detection_result.dart';
import '../models/detection_settings.dart';
import '../models/product_detection.dart';
import 'ai_model_service.dart';
import 'image_processing_service.dart';

/// Orchestrates: preprocess -> run both models -> decode -> DetectionResult.
class DetectionService {
  DetectionService({AiModelService? ai, ImageProcessingService? images})
      : _ai = ai ?? AiModelService(),
        _images = images ?? ImageProcessingService();

  final AiModelService _ai;
  final ImageProcessingService _images;

  bool get isReady => _ai.isLoaded;

  Future<void> loadModels() => _ai.load();

  /// Live camera frame. If [runShelf] is false the [cachedShelves] are reused.
  Future<DetectionResult> detectCameraFrame(
    CameraImage frame, {
    required int rotation,
    required DetectionSettings settings,
    required bool runShelf,
    List<ShelfDetection> cachedShelves = const [],
  }) async {
    final sw = Stopwatch()..start();
    final pre = await _images.fromCameraImage(frame, rotation);
    return _infer(pre, settings, runShelf, cachedShelves, sw);
  }

  /// Decoded still image (RGBA bytes).
  Future<DetectionResult> detectRgba(
    Uint8List rgba,
    int width,
    int height, {
    required DetectionSettings settings,
  }) async {
    final sw = Stopwatch()..start();
    final pre = await _images.fromRgba(rgba, width, height);
    return _infer(pre, settings, true, const [], sw);
  }

  Future<DetectionResult> _infer(
    PreprocessedInput pre,
    DetectionSettings settings,
    bool runShelf,
    List<ShelfDetection> cachedShelves,
    Stopwatch sw,
  ) async {
    final productFuture = _ai.runProduct(
      pre.tensor,
      (outs) => _decodeProducts(outs, pre, settings),
    );
    final Future<List<ShelfDetection>> shelfFuture = runShelf
        ? _ai.runShelf(pre.tensor, (outs) => _decodeShelves(outs, pre, settings))
        : Future.value(cachedShelves);

    final products = await productFuture;
    final shelves = await shelfFuture;

    return DetectionResult(
      shelves: shelves,
      products: products,
      imageWidth: pre.width,
      imageHeight: pre.height,
      inferenceMs: sw.elapsedMilliseconds,
    );
  }

  // ---------------------------------------------------------------- products
  List<ProductDetection> _decodeProducts(
    List<OrtValue?> outs,
    PreprocessedInput pre,
    DetectionSettings settings,
  ) {
    final raw = decodeYolo(
      outs[0]!.value,
      numMasks: 0,
      confThreshold: settings.productConf,
    );
    final kept = nonMaxSuppression(
      raw,
      iouThreshold: settings.iou,
      maxDetections: 150,
    );
    final labels = AppConstants.productLabels;
    return [
      for (final b in kept)
        ProductDetection(
          box: pre.normalizedRect(b.x1, b.y1, b.x2, b.y2),
          classId: b.classId,
          label: b.classId < labels.length ? labels[b.classId] : 'class ${b.classId}',
          confidence: b.score,
        ),
    ];
  }

  // ----------------------------------------------------------------- shelves
  List<ShelfDetection> _decodeShelves(
    List<OrtValue?> outs,
    PreprocessedInput pre,
    DetectionSettings settings,
  ) {
    final raw = decodeYolo(
      outs[0]!.value,
      numMasks: AppConstants.maskChannels,
      confThreshold: settings.shelfConf,
    );
    final kept = nonMaxSuppression(
      raw,
      iouThreshold: settings.iou,
      maxDetections: 10,
    );

    List? protos;
    if (settings.showMasks && outs.length > 1 && outs[1] != null) {
      protos = (outs[1]!.value as List)[0] as List; // [32][160][160]
    }

    return [
      for (final b in kept)
        ShelfDetection(
          box: pre.normalizedRect(b.x1, b.y1, b.x2, b.y2),
          confidence: b.score,
          maskRuns: protos == null ? const [] : _maskRuns(b, protos, pre),
        ),
    ];
  }

  /// mask = sigmoid(coeffs . protos) > 0.5  <=>  coeffs . protos > 0,
  /// computed only inside the box, returned as horizontal runs of rects.
  List<Rect> _maskRuns(RawBox b, List protos, PreprocessedInput pre) {
    final coeffs = b.maskCoeffs;
    if (coeffs == null) return const [];
    final k = coeffs.length;
    final protoH = (protos[0] as List).length;
    final protoW = ((protos[0] as List)[0] as List).length;
    final strideX = pre.inputSize / protoW;
    final strideY = pre.inputSize / protoH;

    final x0 = math.max(0, (b.x1 / strideX).floor());
    final x1 = math.min(protoW, (b.x2 / strideX).ceil());
    final y0 = math.max(0, (b.y1 / strideY).floor());
    final y1 = math.min(protoH, (b.y2 / strideY).ceil());

    final runs = <Rect>[];
    for (var y = y0; y < y1; y++) {
      final rows = [
        for (var m = 0; m < k; m++) ((protos[m] as List)[y] as List).cast<double>(),
      ];
      var runStart = -1;
      for (var x = x0; x <= x1; x++) {
        var on = false;
        if (x < x1) {
          var sum = 0.0;
          for (var m = 0; m < k; m++) {
            sum += coeffs[m] * rows[m][x];
          }
          on = sum > 0;
        }
        if (on && runStart < 0) {
          runStart = x;
        } else if (!on && runStart >= 0) {
          runs.add(Rect.fromLTRB(
            pre.normX(runStart * strideX),
            pre.normY(y * strideY),
            pre.normX(x * strideX),
            pre.normY((y + 1) * strideY),
          ));
          runStart = -1;
        }
      }
    }
    return runs;
  }

  void dispose() => _ai.dispose();
}
