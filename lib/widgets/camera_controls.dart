import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Bottom control panel: [left] [shutter] [right], with optional
/// PHOTO / VIDEO toggle above.
class CameraControls extends StatelessWidget {
  const CameraControls({
    super.key,
    required this.onShutter,
    this.isVideoMode = false,
    this.isRecording = false,
    this.enabled = true,
    this.onModeChanged,
    this.leftIcon,
    this.onLeft,
    this.rightIcon,
    this.onRight,
    this.header,
    this.compact = false,
  });

  final VoidCallback onShutter;
  final bool isVideoMode;
  final bool isRecording;
  final bool enabled;

  /// When null the PHOTO/VIDEO toggle is hidden.
  final ValueChanged<bool>? onModeChanged;
  final IconData? leftIcon;
  final VoidCallback? onLeft;
  final IconData? rightIcon;
  final VoidCallback? onRight;

  /// Optional widget shown above the buttons (e.g. a stats card).
  final Widget? header;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        compact ? 8 : 14,
        compact ? 14 : 20,
        compact ? 10 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.sky.withAlpha(40),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[
              header!,
              SizedBox(height: compact ? 8 : 14)
            ],
            if (onModeChanged != null && !isRecording) ...[
              _ModeToggle(isVideo: isVideoMode, onChanged: onModeChanged!),
              const SizedBox(height: 14),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SideButton(
                  icon: leftIcon,
                  onTap: onLeft,
                  compact: compact,
                ),
                _Shutter(
                  isVideo: isVideoMode,
                  isRecording: isRecording,
                  onTap: enabled ? onShutter : null,
                  compact: compact,
                ),
                _SideButton(
                  icon: rightIcon,
                  onTap: onRight,
                  compact: compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({this.icon, this.onTap, this.compact = false});
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 52.0;
    if (icon == null) return SizedBox(width: size, height: size);
    return Material(
      color: AppColors.skyPale,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: AppColors.skyDark),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.isVideo,
    required this.isRecording,
    required this.onTap,
    required this.compact,
  });

  final bool isVideo;
  final bool isRecording;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isVideo ? Colors.red : AppColors.sky;
    final size = compact ? 68.0 : 76.0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: color,
              shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isRecording ? BorderRadius.circular(10) : null,
            ),
            child: isRecording
                ? null
                : const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isVideo, required this.onChanged});
  final bool isVideo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, bool video) => GestureDetector(
          onTap: () => onChanged(video),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.sky : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.skyDark,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.skyPale,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('PHOTO', !isVideo, false),
          chip('VIDEO', isVideo, true),
        ],
      ),
    );
  }
}
