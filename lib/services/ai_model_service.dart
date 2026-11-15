import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import '../core/constants/app_constants.dart';

/// Loads the two ONNX models and runs them with ONNX Runtime (CPU).
class AiModelService {
  OrtSession? _shelf;
  OrtSession? _product;

  bool get isLoaded => _shelf != null && _product != null;

  Future<void> load() async {
    if (isLoaded) return;
    OrtEnv.instance.init();
    _shelf = await _createSession(AppConstants.shelfModelAsset);
    _product = await _createSession(AppConstants.productModelAsset);
  }

  Future<OrtSession> _createSession(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final options = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(AppConstants.ortThreadsPerModel);
    return OrtSession.fromBuffer(bytes, options);
  }

  /// Runs the shelf (segmentation) model. [decode] must read everything it
  /// needs from the outputs synchronously; they are released afterwards.
  Future<T> runShelf<T>(
    Float32List input,
    T Function(List<OrtValue?> outputs) decode,
  ) =>
      _run(_shelf!, input, decode);

  /// Runs the product (detection) model.
  Future<T> runProduct<T>(
    Float32List input,
    T Function(List<OrtValue?> outputs) decode,
  ) =>
      _run(_product!, input, decode);

  Future<T> _run<T>(
    OrtSession session,
    Float32List input,
    T Function(List<OrtValue?> outputs) decode,
  ) async {
    const s = AppConstants.inputSize;
    final tensor = OrtValueTensor.createTensorWithDataList(input, [1, 3, s, s]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(
        runOptions,
        {AppConstants.inputName: tensor},
      );
      if (outputs == null) throw StateError('Model returned no output.');
      return decode(outputs);
    } finally {
      tensor.release();
      runOptions.release();
      outputs?.forEach((o) => o?.release());
    }
  }

  void dispose() {
    _shelf?.release();
    _product?.release();
    _shelf = null;
    _product = null;
  }
}
