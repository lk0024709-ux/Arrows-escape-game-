# Fonts

Place a bundled font here (e.g. `arrows_escape.ttf` / `arrows_escape.otf`) to
override the default UI font.

The app's font loader (`lib/core/app_font.dart`) reads candidates from this
directory. Missing or **zero-byte** files are handled gracefully — they are
skipped and the app falls back to the platform default font (or a Google font
in builds that link `google_fonts`), so an empty or corrupt font asset never
crashes startup.
