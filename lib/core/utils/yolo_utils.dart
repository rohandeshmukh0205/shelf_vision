import 'dart:math' as math;

/// A raw detection in the model's 640x640 input space.
class RawBox {
  RawBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classId,
    this.maskCoeffs,
  });

  final double x1, y1, x2, y2;
  final double score;
  final int classId;
  final List<double>? maskCoeffs;
}

double iou(RawBox a, RawBox b) {
  final ix1 = math.max(a.x1, b.x1);
  final iy1 = math.max(a.y1, b.y1);
  final ix2 = math.min(a.x2, b.x2);
  final iy2 = math.min(a.y2, b.y2);
  final inter = math.max(0.0, ix2 - ix1) * math.max(0.0, iy2 - iy1);
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  final union = areaA + areaB - inter;
  return union <= 0 ? 0.0 : inter / union;
}

/// Class-aware greedy NMS.
List<RawBox> nonMaxSuppression(
  List<RawBox> boxes, {
  required double iouThreshold,
  int maxDetections = 100,
}) {
  final sorted = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final candidates = sorted.length > 600 ? sorted.sublist(0, 600) : sorted;
  final kept = <RawBox>[];
  for (final c in candidates) {
    var keep = true;
    for (final k in kept) {
      if (k.classId == c.classId && iou(k, c) > iouThreshold) {
        keep = false;
        break;
      }
    }
    if (keep) {
      kept.add(c);
      if (kept.length >= maxDetections) break;
    }
  }
  return kept;
}

/// Decodes the main YOLO11 output tensor.
///
/// Ultralytics layout (channels first): [1, 4 + numClasses + numMasks, 8400]
///   rows 0..3  : cx, cy, w, h  (pixels in the 640x640 input)
///   next rows  : class scores (already sigmoid-ed, no objectness)
///   last rows  : mask coefficients (segmentation model only)
/// A transposed [1, 8400, C] layout is also handled.
List<RawBox> decodeYolo(
  Object? output, {
  required int numMasks,
  required double confThreshold,
}) {
  final batch = output as List;
  final first = batch[0] as List;
  final d0 = first.length;
  final d1 = (first[0] as List).length;
  final channelsFirst = d0 < d1;
  final channels = channelsFirst ? d0 : d1;
  final count = channelsFirst ? d1 : d0;
  final numClasses = channels - 4 - numMasks;
  if (numClasses < 1) return const [];

  final rows = <List<double>>[
    for (final r in first) (r as List).cast<double>(),
  ];
  double at(int ch, int i) => channelsFirst ? rows[ch][i] : rows[i][ch];

  final boxes = <RawBox>[];
  for (var i = 0; i < count; i++) {
    var best = -1;
    var bestScore = 0.0;
    for (var c = 0; c < numClasses; c++) {
      final s = at(4 + c, i);
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    if (best < 0 || bestScore < confThreshold) continue;

    final cx = at(0, i), cy = at(1, i), w = at(2, i), h = at(3, i);
    List<double>? coeffs;
    if (numMasks > 0) {
      coeffs = [for (var m = 0; m < numMasks; m++) at(4 + numClasses + m, i)];
    }
    boxes.add(RawBox(
      x1: cx - w / 2,
      y1: cy - h / 2,
      x2: cx + w / 2,
      y2: cy + h / 2,
      score: bestScore,
      classId: best,
      maskCoeffs: coeffs,
    ));
  }
  return boxes;
}
