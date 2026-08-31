import 'package:arrows_escape_game/core/app_font.dart';
import 'package:arrows_escape_game/core/audio_manager.dart';
import 'package:arrows_escape_game/core/constants.dart';
import 'package:arrows_escape_game/screens/game/game_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both calls are fail-safe: missing assets never crash startup.
  await AudioManager.instance.init();
  final fontFamily = await AppFont.resolve();

  runApp(ArrowEscapeApp(fontFamily: fontFamily));
}

class ArrowEscapeApp extends StatelessWidget {
  const ArrowEscapeApp({super.key, this.fontFamily});

  /// Bundled font family to use, or null to fall back to the platform default.
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrows Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: kInk,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent).copyWith(
          secondary: kMuted,
          surface: Colors.white,
          error: kDanger,
        ),
        fontFamily: fontFamily,
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: kInk),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: const GameScreen(),
    );
  }
}
