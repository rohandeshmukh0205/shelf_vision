import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/detection_settings.dart';
import '../providers/detection_provider.dart';
import '../services/camera_service.dart';
import '../widgets/camera_controls.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/detection_info_card.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/round_icon_button.dart';
import 'result_screen.dart';

/// Tasks 3-5: real-time shelf + product detection on the live camera feed.
class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  final CameraService _cam = CameraService();
  late final DetectionProvider _provider;

  String? _error;
  bool _snapping = false;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<DetectionProvider>();
    _provider.clearLive(notify: false);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.clearLive(notify: false);
    _cam.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cam.release();
    } else if (state == AppLifecycleState.resumed && !_cam.isReady) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      await _cam.initialize(
        preset: AppConstants.liveResolution,
        enableAudio: false,
      );
      _error = null;
      if (mounted) setState(() {});
      await _beginStream();
    } on CameraException catch (e) {
      _error = e.description ?? e.code;
      if (mounted) setState(() {});
    } catch (e) {
      _error = e.toString();
      if (mounted) setState(() {});
    }
  }

  Future<void> _beginStream() async {
    if (!mounted) return;
    await _cam.startStream(
      (image) => _provider.onCameraFrame(image, _cam.sensorOrientation),
    );
  }

  Future<void> _snapshot() async {
    if (_snapping || !_cam.isReady) return;
    setState(() => _snapping = true);
    try {
      await _cam.stopStream();
      final file = await _cam.takePicture();
      final ok = await _provider.analyzeImageFile(file.path);
      if (ok && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ResultScreen()));
      } else if (mounted) {
        _toast('Could not analyse the snapshot.');
      }
    } catch (e) {
      _toast('Snapshot failed: $e');
    } finally {
      if (mounted) {
        setState(() => _snapping = false);
        await _beginStream();
      }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final torchOn = _cam.flashMode == FlashMode.torch;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_rounded,
                        size: 56, color: AppColors.sky),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _start, child: const Text('Try again')),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back')),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_cam.isReady && _cam.controller != null)
                  Consumer<DetectionProvider>(
                    builder: (context, p, _) => CameraPreviewWidget(
                      controller: _cam.controller!,
                      onScaleStart: () => _baseZoom = _cam.zoom,
                      onScaleUpdate: (s) => _cam.setZoom(_baseZoom * s),
                      onTapNormalized: _cam.focusAt,
                      overlay: DetectionOverlay(
                        result: p.liveResult,
                        cover: true,
                        showMasks: p.settings.showMasks,
                        showLabels: p.settings.showLabels,
                      ),
                    ),
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                _topBar(torchOn),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Consumer<DetectionProvider>(
                    builder: (context, p, _) => CameraControls(
                      compact: true,
                      enabled: _cam.isReady && !_snapping,
                      onShutter: _snapshot,
                      leftIcon: p.livePaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onLeft: () => p.setLivePaused(!p.livePaused),
                      rightIcon: torchOn
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      onRight: () async {
                        try {
                          await _cam.setFlash(
                              torchOn ? FlashMode.off : FlashMode.torch);
                        } catch (_) {}
                        if (mounted) setState(() {});
                      },
                      header: DetectionInfoCard(
                        result: p.liveResult,
                        fps: p.fps,
                        compact: true,
                      ),
                    ),
                  ),
                ),
                if (_snapping)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withAlpha(200),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _topBar(bool torchOn) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
            Consumer<DetectionProvider>(
              builder: (context, p, _) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle,
                        size: 10,
                        color: p.livePaused ? Colors.grey : AppColors.product),
                    const SizedBox(width: 8),
                    Text(
                      p.livePaused ? 'Paused' : 'Live detection',
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
            RoundIconButton(icon: Icons.tune_rounded, onTap: _openSettings),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<DetectionProvider>(
      builder: (context, p, _) {
        final s = p.settings;
        void set(DetectionSettings n) => p.updateSettings(n);

        Widget slider(String label, double value, ValueChanged<double> onChanged,
            {double min = 0.1, double max = 0.9}) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const Spacer(),
                  Text(value.toStringAsFixed(2),
                      style: const TextStyle(
                          color: AppColors.skyDark,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              Slider(value: value, min: min, max: max, onChanged: onChanged),
            ],
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 14),
                const Text('Detection settings',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 10),
                slider('Product confidence', s.productConf,
                    (v) => set(s.copyWith(productConf: v))),
                slider('Shelf confidence', s.shelfConf,
                    (v) => set(s.copyWith(shelfConf: v))),
                slider('Overlap (NMS IoU)', s.iou,
                    (v) => set(s.copyWith(iou: v)),
                    min: 0.2, max: 0.8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show shelf masks'),
                  value: s.showMasks,
                  onChanged: (v) => set(s.copyWith(showMasks: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show labels & scores'),
                  value: s.showLabels,
                  onChanged: (v) => set(s.copyWith(showLabels: v)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
