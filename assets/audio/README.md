# Audio

Place audio files here for the game's sound effects (e.g. `swoosh_18.mp3`,
`success.mp3`, `block.mp3`, `hint.mp3`, `underwater.mp3`, `god.mp3`,
`boss.mp3`).

The audio manager (`lib/core/audio_manager.dart`) loads every file defensively
inside try/catch, so **missing or zero-byte** files are skipped without ever
crashing initialization.
