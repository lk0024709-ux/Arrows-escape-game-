import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/level_pack.dart';
import 'services/ad_provider.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-first, edge-to-edge: the UI uses SafeArea so notches, status bars
  // and gesture navigation are handled by the layout, not by hard-coded values
  // (prompt §46).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final save = await SaveService.init();
  final pack = LevelPack(save: save);

  runApp(
    ArrowsEscapeApp(
      save: save,
      pack: pack,
      // Swap in a real network provider here; the game never sees it.
      adProvider: save.settings.adsEnabled
          ? const PlaceholderAdProvider()
          : const NoopAdProvider(),
    ),
  );
}
