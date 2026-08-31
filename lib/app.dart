import 'package:flutter/material.dart';

import 'data/level_pack.dart';
import 'services/ad_provider.dart';
import 'services/save_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';

/// Root widget: owns the services and the settings state.
class ArrowsEscapeApp extends StatefulWidget {
  const ArrowsEscapeApp({
    super.key,
    required this.save,
    required this.pack,
    this.adProvider = const PlaceholderAdProvider(),
  });

  final SaveService save;
  final LevelPack pack;
  final AdProvider adProvider;

  @override
  State<ArrowsEscapeApp> createState() => _ArrowsEscapeAppState();
}

class _ArrowsEscapeAppState extends State<ArrowsEscapeApp> {
  late GameSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.save.settings;
  }

  Future<void> _updateSettings(GameSettings value) async {
    setState(() => _settings = value);
    await widget.save.saveSettings(value);
  }

  AdProvider get _ads =>
      _settings.adsEnabled ? widget.adProvider : const NoopAdProvider();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrows Escape',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(
        save: widget.save,
        pack: widget.pack,
        adProvider: _ads,
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => SettingsScreen(
                settings: _settings,
                onChanged: _updateSettings,
                onResetProgress: () async {
                  await widget.save.resetAll();
                  if (mounted) setState(() {});
                },
              ),
            ),
          );
        },
        onSettingsChanged: _updateSettings,
      ),
    );
  }
}
