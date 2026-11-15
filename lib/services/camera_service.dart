import 'package:camera/camera.dart';
import 'package:flutter/material.dart' show Offset;

/// Thin wrapper around CameraController used by the capture and live screens.
class CameraService {
  CameraController? controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  ResolutionPreset _preset = ResolutionPreset.high;
  bool _audio = true;
  bool _streaming = false;
  int _generation = 0;

  double minZoom = 1.0;
  double maxZoom = 1.0;
  double _zoom = 1.0;
  FlashMode flashMode = FlashMode.off;

  bool get isReady => controller?.value.isInitialized ?? false;
  bool get isRecording => controller?.value.isRecordingVideo ?? false;
  bool get isStreaming => _streaming;
  bool get canSwitch => _cameras.length > 1;
  double get zoom => _zoom;

  int get sensorOrientation =>
      _cameras.isEmpty ? 90 : _cameras[_index].sensorOrientation;

  /// (Re)opens the camera. Safe to call again after [release].
  Future<void> initialize({
    ResolutionPreset preset = ResolutionPreset.high,
    bool enableAudio = true,
  }) async {
    final generation = ++_generation;
    _preset = preset;
    _audio = enableAudio;
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
      if (generation != _generation) return;
      if (_cameras.isEmpty) {
        throw CameraException('noCamera', 'No camera found on this device.');
      }
      final back = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _index = back >= 0 ? back : 0;
    }
    await _open(generation);
  }

  Future<void> _open(int generation) async {
    final old = controller;
    controller = null;
    _streaming = false;
    await old?.dispose();
    if (generation != _generation) return;

    final c = CameraController(
      _cameras[_index],
      _preset,
      enableAudio: _audio,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    controller = c;
    late final double nextMinZoom;
    late final double nextMaxZoom;
    try {
      await c.initialize();
      if (!_isCurrent(c, generation)) return;
      nextMinZoom = await c.getMinZoomLevel();
      if (!_isCurrent(c, generation)) return;
      nextMaxZoom = await c.getMaxZoomLevel();
      if (!_isCurrent(c, generation)) return;
    } catch (_) {
      if (!_isCurrent(c, generation)) return;
      rethrow;
    }
    minZoom = nextMinZoom;
    maxZoom = nextMaxZoom;
    _zoom = minZoom;
    try {
      await c.setFlashMode(flashMode);
    } catch (_) {}
  }

  bool _isCurrent(CameraController c, int generation) =>
      generation == _generation && identical(controller, c);

  Future<void> _openNewCamera() async {
    final generation = ++_generation;
    await _open(generation);
  }

  Future<void> switchCamera() async {
    if (!canSwitch || isRecording) return;
    _index = (_index + 1) % _cameras.length;
    await _openNewCamera();
  }

  Future<void> setZoom(double value) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    final z = value.clamp(minZoom, maxZoom).toDouble();
    if ((z - _zoom).abs() < 0.01) return;
    _zoom = z;
    await c.setZoomLevel(z);
  }

  Future<void> focusAt(Offset normalized) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFocusPoint(normalized);
      await c.setExposurePoint(normalized);
    } catch (_) {}
  }

  Future<void> setFlash(FlashMode mode) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    await c.setFlashMode(mode);
    flashMode = mode;
  }

  Future<void> cycleFlash() async {
    const order = [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.torch,
    ];
    await setFlash(order[(order.indexOf(flashMode) + 1) % order.length]);
  }

  Future<XFile> takePicture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      throw CameraException('notReady', 'Camera is not ready.');
    }
    return c.takePicture();
  }

  Future<void> startRecording() async => controller?.startVideoRecording();

  Future<XFile?> stopRecording() async => controller?.stopVideoRecording();

  Future<void> startStream(void Function(CameraImage) onFrame) async {
    final c = controller;
    if (c == null || !c.value.isInitialized || _streaming) return;
    await c.startImageStream(onFrame);
    _streaming = true;
  }

  Future<void> stopStream() async {
    final c = controller;
    if (c == null || !_streaming) return;
    _streaming = false;
    try {
      await c.stopImageStream();
    } catch (_) {}
  }

  /// Frees the camera (call on pause / dispose).
  Future<void> release() async {
    _generation++;
    final c = controller;
    controller = null;
    _streaming = false;
    await c?.dispose();
  }
}
