import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/detection_result.dart';
import '../models/detection_settings.dart';
import '../services/detection_service.dart';

enum ModelStatus { idle, loading, ready, error }

class DetectionProvider extends ChangeNotifier {
  DetectionProvider({DetectionService? service})
      : _service = service ?? DetectionService();

  final DetectionService _service;

  // model state
  ModelStatus _status = ModelStatus.idle;
  String? _error;

  // settings
  DetectionSettings _settings = const DetectionSettings();

  // live detection state
  DetectionResult _liveResult = DetectionResult.empty;
  List<ShelfDetection> _liveShelves = const [];
  bool _busy = false;
  bool _livePaused = false;
  int _frameCounter = 0;
  double _fps = 0;
  DateTime? _lastResultAt;

  // still-image state
  bool _analyzing = false;
  ui.Image? _staticImage;
  DetectionResult? _staticResult;

  ModelStatus get status => _status;
  bool get isReady => _status == ModelStatus.ready;
  String? get error => _error;
  DetectionSettings get settings => _settings;
  DetectionResult get liveResult => _liveResult;
  bool get livePaused => _livePaused;
  double get fps => _fps;
  bool get isAnalyzing => _analyzing;
  ui.Image? get staticImage => _staticImage;
  DetectionResult? get staticResult => _staticResult;

  Future<void> initialize() async {
    if (_status == ModelStatus.loading || _status == ModelStatus.ready) return;
    _status = ModelStatus.loading;
    _error = null;
    notifyListeners();
    try {
      await _service.loadModels();
      _status = ModelStatus.ready;
    } catch (e, st) {
      debugPrint('Model load failed: $e\n$st');
      _status = ModelStatus.error;
      _error = 'Could not load the AI models.\n'
          'Check that shelf_model.onnx and product_model.onnx are in '
          'assets/models/.\n\n$e';
    }
    notifyListeners();
  }

  void updateSettings(DetectionSettings s) {
    _settings = s;
    notifyListeners();
  }

  // ------------------------------------------------------------------ live
  Future<void> onCameraFrame(CameraImage image, int sensorOrientation) async {
    if (!isReady || _busy || _livePaused) return;
    _busy = true;
    try {
      final rotation =
          AppConstants.frameRotationOverride ?? sensorOrientation;
      final runShelf = _frameCounter % AppConstants.shelfEveryNFrames == 0;
      final result = await _service.detectCameraFrame(
        image,
        rotation: rotation,
        settings: _settings,
        runShelf: runShelf,
        cachedShelves: _liveShelves,
      );
      _frameCounter++;
      if (_livePaused) return;
      _liveShelves = result.shelves;
      _liveResult = result;

      final now = DateTime.now();
      if (_lastResultAt != null) {
        final dt = now.difference(_lastResultAt!).inMilliseconds;
        if (dt > 0) {
          final inst = 1000 / dt;
          _fps = _fps == 0 ? inst : _fps * 0.7 + inst * 0.3;
        }
      }
      _lastResultAt = now;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Live detection error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  void setLivePaused(bool paused) {
    _livePaused = paused;
    notifyListeners();
  }

  void clearLive({bool notify = true}) {
    _liveResult = DetectionResult.empty;
    _liveShelves = const [];
    _frameCounter = 0;
    _fps = 0;
    _lastResultAt = null;
    _livePaused = false;
    if (notify) notifyListeners();
  }

  // ------------------------------------------------------------ still image
  /// Runs both models on a photo file. Returns true on success.
  Future<bool> analyzeImageFile(String path) async {
    if (!isReady) return false;
    _analyzing = true;
    notifyListeners();
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: AppConstants.maxAnalyzeWidth,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Could not decode image.');

      final result = await _service.detectRgba(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        img.width,
        img.height,
        settings: _settings,
      );
      _staticImage?.dispose();
      _staticImage = img;
      _staticResult = result;
      return true;
    } catch (e, st) {
      debugPrint('Analyze error: $e\n$st');
      _error = e.toString();
      return false;
    } finally {
      _analyzing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _staticImage?.dispose();
    _service.dispose();
    super.dispose();
  }
}
