import 'dart:ui';

import 'product_detection.dart';

/// One shelf row from the segmentation model.
class ShelfDetection {
  const ShelfDetection({
    required this.box,
    required this.confidence,
    this.maskRuns = const [],
  });

  /// Normalised (0..1) bounding box.
  final Rect box;
  final double confidence;

  /// Segmentation mask as horizontal runs of normalised rectangles.
  final List<Rect> maskRuns;

  String get percent => '${(confidence * 100).round()}%';
}

class DetectionResult {
  const DetectionResult({
    required this.shelves,
    required this.products,
    required this.imageWidth,
    required this.imageHeight,
    required this.inferenceMs,
  });

  static const DetectionResult empty = DetectionResult(
    shelves: [],
    products: [],
    imageWidth: 0,
    imageHeight: 0,
    inferenceMs: 0,
  );

  final List<ShelfDetection> shelves;
  final List<ProductDetection> products;

  /// Size of the upright image the normalised boxes refer to.
  final int imageWidth;
  final int imageHeight;
  final int inferenceMs;

  int get shelfCount => shelves.length;
  int get productCount => products.where((p) => !p.isEmptySpace).length;
  int get emptyCount => products.where((p) => p.isEmptySpace).length;

  /// Share of slots that are filled (products / (products + empty)).
  double? get stockLevel {
    final total = productCount + emptyCount;
    return total == 0 ? null : productCount / total;
  }
}
