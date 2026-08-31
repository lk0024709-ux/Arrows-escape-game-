# Tangled Arrows Escape / Maze Untangle 2D Puzzle Game

A complete, production-ready 2D puzzle game built in Flutter from scratch, matching the exact visual style of fixed polyline arrows mapped across a matrix dot grid.

---

## Architecture & Navigation Flow

1. **Intro / Splash Screen**: Asset caching, player progress loading from local storage, seamless cross-fade to Home.
2. **Home Dashboard**:
   - Primary "Play" CTA navigating to the latest unlocked level.
   - Level Selection route button.
   - Daily Rewards System: Persistent streak calculation using local storage.
   - Settings Drawer/Modal: Audio, Haptics, and performance toggles.
3. **Level Selection Screen**: Scrollable GridView showing locked, unlocked, and completed levels with star ratings.
4. **Game Screen**: Top HUD (Level, Hearts/Lives count, Hint balance, Settings button), Interactive Game Canvas, Bottom power-up controls.

---

## Game Branding & Launcher Icon Setup

Configured using `flutter_launcher_icons` in `pubspec.yaml` to generate clean, adaptive Android & iOS launcher icons:
- **Foreground**: Minimalist tangled arrow vector glyph (`assets/icon/app_icon_foreground.png`).
- **Background**: Matching flat white/light theme `#FFFFFF`.
- **Support**: Android Adaptive Icons (`adaptive_icon_background` & `adaptive_icon_foreground`).

### Manual Setup & Generation Commands

```bash
flutter pub get
dart run flutter_launcher_icons
```

This automatically generates standard and adaptive launcher icons across Android (`res/mipmap-*`) and iOS.

---

## Dot Matrix Physics & Coordinate Space

- **Base Grid**: Uniform 2D integer grid of Grey Dots rendered dynamically based on screen dimensions:
  - `dotSpacing = canvasWidth / (gridCols + 1)`
  - `Pixel Point: Offset((col + 1) * dotSpacing, (row + 1) * dotSpacing)`
- **Discrete Polyline Structure**: Every arrow path is strictly locked to integer coordinates: `List<Point<int>>` segments. Lines and turns snap perfectly to dot centers.

---

## Raycast Collision & Escape Mechanics

- **Tap Registration**: Detect tap proximity to nearest arrow polyline.
- **Path Clearance (Raycasting)**:
  - On tap, project an integer grid ray from the arrow's head point along its exit direction (`UP`, `DOWN`, `LEFT`, `RIGHT`) to the grid boundary.
  - If **ANY** active segment of another arrow occupies any coordinate along this ray: Path is **BLOCKED**. Trigger a localized wobble/shake animation, flash the arrow red, and decrement player life/heart.
  - If the ray path is entirely empty to the boundary: Path is **CLEAR**. Trigger escape sequence.
- **Snake Extrusion Escape Animation**:
  - Uses Flutter's `ui.PathMetrics` and `extractPath()` driven by `AnimationController`.
  - Dynamically shrinks the path tail-to-head along its exact turns to smoothly exit the grid off-screen.
  - Removes arrow from active state and checks level win condition (`active arrows == 0`).

---

## CustomPainter Rendering

- Render faint grey circular dots at all grid intersection points.
- Draw arrow segments using thick stroke widths, `StrokeCap.round`, and `StrokeJoin.round`.
- Draw a sharp vector triangle arrowhead at the final coordinate, rotated precisely to the facing direction.

---

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Run the game:
   ```bash
   flutter run
   ```
