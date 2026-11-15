import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/app_theme.dart';
import '../providers/detection_provider.dart';
import '../services/camera_service.dart';
import '../widgets/camera_controls.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/round_icon_button.dart';
import 'result_screen.dart';

/// Task 1: live preview, capture photo / record video, retake, process.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cam = CameraService();

  bool _videoMode = false;
  bool _busy = false;
  bool _processing = false;
  bool _saving = false;
  String? _error;

  String? _capturedPath;
  bool _capturedIsVideo = false;

  Timer? _timer;
  int _seconds = 0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _cam.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _cam.release();
    } else if (state == AppLifecycleState.resumed && !_cam.isReady) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      await _cam.initialize(preset: ResolutionPreset.high, enableAudio: true);
      _error = null;
    } on CameraException catch (e) {
      _error = e.description ?? e.code;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------- capture
  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final f = await _cam.takePicture();
      _capturedPath = f.path;
      _capturedIsVideo = false;
    } on CameraException catch (e) {
      _toast('Capture failed: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_cam.isRecording) {
        _timer?.cancel();
        final f = await _cam.stopRecording();
        _seconds = 0;
        if (f != null) {
          _capturedPath = f.path;
          _capturedIsVideo = true;
        }
      } else {
        await _cam.startRecording();
        _seconds = 0;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    } on CameraException catch (e) {
      _toast('Recording error: ${e.description ?? e.code}');
    }
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------- review
  Future<void> _retake() async {
    final path = _capturedPath;
    setState(() => _capturedPath = null);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final path = _capturedPath;
    if (path == null) return;
    setState(() => _saving = true);
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      if (_capturedIsVideo) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }
      _toast('Saved to gallery');
    } catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _process() async {
    final path = _capturedPath;
    if (path == null) return;
    final provider = context.read<DetectionProvider>();
    if (!provider.isReady) {
      _toast('AI models are not ready yet.');
      return;
    }
    setState(() => _processing = true);
    final ok = await provider.analyzeImageFile(path);
    if (!mounted) return;
    setState(() => _processing = false);
    if (ok) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ResultScreen()));
    } else {
      _toast('Processing failed. Please try again.');
    }
  }

  // --------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    if (_capturedPath != null) return _buildReview();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? _ErrorView(message: _error!, onRetry: _initCamera)
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_cam.isReady && _cam.controller != null)
                  CameraPreviewWidget(
                    controller: _cam.controller!,
                    onScaleStart: () => _baseZoom = _cam.zoom,
                    onScaleUpdate: (s) async {
                      await _cam.setZoom(_baseZoom * s);
                      if (mounted) setState(() {});
                    },
                    onTapNormalized: _cam.focusAt,
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                _topBar(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: CameraControls(
                    isVideoMode: _videoMode,
                    isRecording: _cam.isRecording,
                    enabled: _cam.isReady && !_busy,
                    onModeChanged: (v) => setState(() => _videoMode = v),
                    onShutter: _videoMode ? _toggleRecording : _takePhoto,
                    leftIcon: _flashIcon,
                    onLeft: () async {
                      try {
                        await _cam.cycleFlash();
                      } catch (_) {}
                      if (mounted) setState(() {});
                    },
                    rightIcon: _cam.canSwitch && !_cam.isRecording
                        ? Icons.cameraswitch_rounded
                        : null,
                    onRight: () async {
                      await _cam.switchCamera();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ],
            ),
    );
  }

  IconData get _flashIcon {
    switch (_cam.flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.highlight_rounded;
    }
  }

  Widget _topBar() {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: _cam.isRecording ? null : () => Navigator.pop(context),
            ),
            if (_cam.isRecording)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('$mm:$ss',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_cam.zoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                        color: AppColors.skyDark,
                        fontWeight: FontWeight.w800)),
              ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    final path = _capturedPath!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_capturedIsVideo ? 'Review video' : 'Review photo'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _retake),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: _capturedIsVideo
                        ? _VideoPreview(path: path)
                        : InteractiveViewer(child: Image.file(File(path))),
                  ),
                ),
              ),
              if (_capturedIsVideo)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'AI processing works on photos. Use Live detection for '
                    'real-time video analysis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _retake,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _capturedIsVideo || _processing
                              ? null
                              : _process,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Process'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_processing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withAlpha(215),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Detecting shelves and products…',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path});
  final String path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _c
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const CircularProgressIndicator();
    return GestureDetector(
      onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
          if (!_c.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded,
                size: 72, color: Colors.white70),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded,
                size: 56, color: AppColors.sky),
            const SizedBox(height: 14),
            const Text('Camera unavailable',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
