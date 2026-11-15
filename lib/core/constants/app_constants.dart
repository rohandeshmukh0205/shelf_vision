import 'package:camera/camera.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Shelf Scanner';

  // ---- Model files (put your exported ONNX files here) ----
  static const String shelfModelAsset = 'assets/models/shelf_model.onnx';
  static const String productModelAsset = 'assets/models/product_model.onnx';

  // ---- Model I/O (Ultralytics ONNX export defaults) ----
  static const int inputSize = 640;
  static const String inputName = 'images';
  static const int maskChannels = 32; // YOLO11-seg prototype masks

  // ---- Class names. ORDER MUST MATCH `model.names` printed by export script.
  static const List<String> shelfLabels = ['row'];
  static const List<String> productLabels = ['empty', 'product'];
  static const int emptyClassId = 0; // index of "empty" in productLabels

  // ---- Default thresholds ----
  static const double defaultProductConf = 0.35;
  static const double defaultShelfConf = 0.35;
  static const double defaultIou = 0.45;

  // ---- Real-time tuning ----
  /// Shelf (segmentation) model is heavier; run it every N analysed frames
  /// and reuse the last shelf result in between.
  static const int shelfEveryNFrames = 3;
  static const ResolutionPreset liveResolution = ResolutionPreset.medium;
  static const int ortThreadsPerModel = 2;

  /// Rotation (0/90/180/270) applied to camera frames before inference.
  /// null = use the camera's sensor orientation (correct for portrait).
  /// If boxes appear rotated/misplaced on your phone, try 90 / 270.
  static const int? frameRotationOverride = null;

  // ---- Still-image analysis ----
  static const int maxAnalyzeWidth = 1280;
}
