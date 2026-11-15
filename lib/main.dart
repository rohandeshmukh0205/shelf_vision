import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

export 'app.dart' show ShelfScannerApp;

typedef MyApp = ShelfScannerApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ShelfScannerApp());
}
