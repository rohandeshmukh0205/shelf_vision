import '../core/constants/app_constants.dart';

class DetectionSettings {
  const DetectionSettings({
    this.productConf = AppConstants.defaultProductConf,
    this.shelfConf = AppConstants.defaultShelfConf,
    this.iou = AppConstants.defaultIou,
    this.showMasks = true,
    this.showLabels = true,
  });

  final double productConf;
  final double shelfConf;
  final double iou;
  final bool showMasks;
  final bool showLabels;

  DetectionSettings copyWith({
    double? productConf,
    double? shelfConf,
    double? iou,
    bool? showMasks,
    bool? showLabels,
  }) {
    return DetectionSettings(
      productConf: productConf ?? this.productConf,
      shelfConf: shelfConf ?? this.shelfConf,
      iou: iou ?? this.iou,
      showMasks: showMasks ?? this.showMasks,
      showLabels: showLabels ?? this.showLabels,
    );
  }
}
