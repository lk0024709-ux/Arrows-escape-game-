import 'package:arrows_escape_game/core/audio_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('init is fail-safe when audio assets are missing', () async {
    // No audio files exist in the test asset bundle; init must not throw and
    // must still report as initialized.
    final audio = AudioManager.instance;
    await audio.init();
    expect(audio.isInitialized, isTrue);
  });

  test('play never throws for an unloaded sound', () {
    final audio = AudioManager.instance;
    expect(() => audio.play(GameSound.god), returnsNormally);
    expect(audio.isLoaded(GameSound.god), isFalse);
  });

  test('unloadAll clears loaded buffers without throwing', () {
    final audio = AudioManager.instance;
    expect(() => audio.unloadAll(), returnsNormally);
  });
}
