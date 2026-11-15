import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/detection_result.dart';
import '../providers/detection_provider.dart';
import '../widgets/detection_info_card.dart';
import '../widgets/detection_overlay.dart';

/// Shows the analysed still image with boxes, summary and detection list.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DetectionProvider>();
    final image = p.staticImage;
    final result = p.staticResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Detection result')),
      body: (image == null || result == null)
          ? const Center(child: Text('No result yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: AppColors.skyPale,
                    child: AspectRatio(
                      aspectRatio: image.width / image.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(image: image, fit: BoxFit.fill),
                          DetectionOverlay(
                            result: result,
                            cover: false,
                            showMasks: p.settings.showMasks,
                            showLabels: p.settings.showLabels,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _Legend(),
                const SizedBox(height: 14),
                DetectionInfoCard(result: result),
                const SizedBox(height: 6),
                Center(
                  child: Text('Inference: ${result.inferenceMs} ms',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11.5)),
                ),
                const SizedBox(height: 14),
                _DetectionList(result: result),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
                ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(t,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        item(AppColors.shelf, 'Shelf'),
        item(AppColors.product, 'Product'),
        item(AppColors.empty, 'Empty space'),
      ],
    );
  }
}

class _DetectionList extends StatelessWidget {
  const _DetectionList({required this.result});
  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final products = [...result.products]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    const maxItems = 30;

    Widget row(Color color, String label, String conf) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.ink, fontWeight: FontWeight.w600))),
              Text(conf,
                  style: const TextStyle(
                      color: AppColors.skyDark, fontWeight: FontWeight.w800)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detections',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          for (var i = 0; i < result.shelves.length; i++)
            row(AppColors.shelf, 'Shelf ${i + 1}', result.shelves[i].percent),
          for (final d in products.take(maxItems))
            row(d.isEmptySpace ? AppColors.empty : AppColors.product,
                d.label, d.percent),
          if (products.length > maxItems)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+ ${products.length - maxItems} more',
                  style: const TextStyle(color: AppColors.muted)),
            ),
          if (result.shelves.isEmpty && products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing detected. Try a clearer photo or lower '
                  'the confidence thresholds in Live detection → settings.',
                  style: TextStyle(color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}
