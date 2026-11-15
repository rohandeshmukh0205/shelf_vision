import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/detection_provider.dart';
import 'camera_screen.dart';
import 'detection_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showCameraPermissionPrompt());
    });
  }

  Future<void> _showCameraPermissionPrompt() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    var status = await Permission.camera.status;
    if (!mounted || status.isGranted) return;

    final openSettings = status.isPermanentlyDenied || status.isRestricted;
    final continueToRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.photo_camera_rounded, size: 32),
        title: const Text('Allow camera access'),
        content: const Text(
          'Shelf Scanner uses your camera to detect shelf rows, products, '
          'and empty spaces. Your device will ask for camera permission next.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(openSettings ? 'Settings' : 'Continue'),
          ),
        ],
      ),
    );
    if (continueToRequest != true || !mounted) return;

    if (openSettings) {
      await openAppSettings();
      return;
    }

    status = await Permission.camera.request();
    if (!mounted || status.isGranted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Camera access is needed to use live detection and capture.'),
        action: status.isPermanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final provider = context.read<DetectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final ok = await provider.analyzeImageFile(picked.path);
    if (ok) {
      navigator.push(MaterialPageRoute(builder: (_) => const ResultScreen()));
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not analyse this image.')));
    }
  }

  void _needModels(BuildContext context, DetectionProvider p) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(p.status == ModelStatus.loading
          ? 'AI models are still loading…'
          : 'AI models are not ready.'),
      action: p.status == ModelStatus.error
          ? SnackBarAction(label: 'Retry', onPressed: p.initialize)
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DetectionProvider>();

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What would you like to do?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.sensors_rounded,
                      title: 'Live detection',
                      subtitle:
                          'Point the camera at a shelf and see shelves, products and empty spaces in real time.',
                      highlighted: true,
                      onTap: () {
                        if (!p.isReady) return _needModels(context, p);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DetectionScreen()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.photo_camera_rounded,
                      title: 'Capture photo / video',
                      subtitle:
                          'Take a picture or record a video, retake it, then process it with AI.',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CameraScreen())),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.photo_library_rounded,
                      title: 'Analyse from gallery',
                      subtitle:
                          'Pick an existing shelf photo (great for testing the models).',
                      onTap: () {
                        if (!p.isReady) return _needModels(context, p);
                        _pickFromGallery(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.isAnalyzing) const _BusyOverlay(text: 'Analysing image…'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 28, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.skyLight, AppColors.sky],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shelves, color: AppColors.sky, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(AppConstants.appName,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'AI shelf & product detection for supermarkets',
            style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : AppColors.ink;
    final sub = highlighted ? Colors.white.withAlpha(225) : AppColors.muted;
    return Material(
      color: highlighted ? AppColors.sky : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: highlighted ? AppColors.sky : AppColors.border),
            boxShadow: highlighted ? AppTheme.softShadow : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlighted
                      ? Colors.white.withAlpha(50)
                      : AppColors.skyPale,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    color: highlighted ? Colors.white : AppColors.skyDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(color: sub, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white.withAlpha(215),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(text,
                  style: const TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
