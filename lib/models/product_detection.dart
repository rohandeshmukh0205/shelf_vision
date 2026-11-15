import 'dart:ui';

import '../core/constants/app_constants.dart';

/// One detection from the product model: a product or an empty slot.
class ProductDetection {
  const ProductDetection({
    required this.box,
    required this.classId,
    required this.label,
    required this.confidence,
  });

  /// Normalised (0..1) rectangle relative to the upright image.
  final Rect box;
  final int classId;
  final String label;
  final double confidence;

  bool get isEmptySpace => classId == AppConstants.emptyClassId;
  String get percent => '${(confidence * 100).round()}%';
}
