import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/detection_result.dart';

/// White card with Shelves / Products / Empty counters and a stock bar.
class DetectionInfoCard extends StatelessWidget {
  const DetectionInfoCard({
    super.key,
    required this.result,
    this.fps,
    this.showStock = true,
    this.compact = false,
  });

  final DetectionResult result;
  final double? fps;
  final bool showStock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stock = result.stockLevel;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Stat(
                icon: Icons.view_agenda_rounded,
                label: 'Shelves',
                value: '${result.shelfCount}',
                color: AppColors.shelf,
                compact: compact,
              ),
              _Stat(
                icon: Icons.inventory_2_rounded,
                label: 'Products',
                value: '${result.productCount}',
                color: AppColors.product,
                compact: compact,
              ),
              _Stat(
                icon: Icons.crop_free_rounded,
                label: 'Empty',
                value: '${result.emptyCount}',
                color: AppColors.empty,
                compact: compact,
              ),
            ],
          ),
          if (showStock && stock != null) ...[
            SizedBox(height: compact ? 8 : 12),
            Row(
              children: [
                const Text('Stock level',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${(stock * 100).round()}%',
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w800)),
              ],
            ),
            SizedBox(height: compact ? 4 : 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stock,
                minHeight: 8,
                backgroundColor: AppColors.skyPale,
                valueColor: const AlwaysStoppedAnimation(AppColors.sky),
              ),
            ),
          ],
          if (fps != null && result.inferenceMs > 0) ...[
            SizedBox(height: compact ? 5 : 8),
            Text(
              '${fps!.toStringAsFixed(1)} FPS  •  ${result.inferenceMs} ms / frame',
              style: TextStyle(
                  color: AppColors.muted, fontSize: compact ? 10 : 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 16 : 18, color: color),
          ),
          SizedBox(height: compact ? 3 : 6),
          Text(value,
              style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          Text(label,
              style: TextStyle(
                  fontSize: compact ? 10 : 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}
