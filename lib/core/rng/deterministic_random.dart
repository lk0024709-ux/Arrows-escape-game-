import 'dart:math' as math;

/// Deterministic, seedable pseudo random generator (SplitMix64).
///
/// The whole game is reproducible: the same `(seed, difficulty)` pair always
/// produces the exact same level, on every device and every platform.
class DeterministicRandom {
  DeterministicRandom(this.seed) : _state = _mixSeed(seed);

  final int seed;
  int _state;

  static int _mixSeed(int seed) {
    var s = seed & 0xFFFFFFFFFFFFFFFF;
    // Scramble the low bits so sequential seeds are not correlated.
    s ^= 0x9E3779B97F4A7C15;
    s = (s ^ (s >>> 30)) * 0xBF58476D1CE4E5B9;
    s = (s ^ (s >>> 27)) * 0x94D049BB133111EB;
    return (s ^ (s >>> 31)) & 0xFFFFFFFFFFFFFFFF;
  }

  /// Raw 64-bit unsigned value.
  int nextInt64() {
    _state = (_state + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return (z ^ (z >>> 31)) & 0xFFFFFFFFFFFFFFFF;
  }

  /// Uniform integer in `[0, max)`.
  int nextInt(int max) => max <= 1 ? 0 : nextInt64() % max;

  /// Uniform integer in `[min, max]` (inclusive).
  int nextIntRange(int min, int max) =>
      max <= min ? min : min + nextInt(max - min + 1);

  /// Uniform double in `[0, 1)`.
  double nextDouble() => (nextInt64() >>> 11) / (1 << 53);

  /// Uniform double in `[min, max)`.
  double nextDoubleRange(double min, double max) => min + nextDouble() * (max - min);

  bool nextBool([double trueProbability = 0.5]) => nextDouble() < trueProbability;

  /// Uniform element pick.
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Weighted pick; `weights` must be the same length as `items`.
  T weightedPick<T>(List<T> items, List<double> weights) {
    assert(items.length == weights.length);
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    if (total <= 0) return pick(items);
    var r = nextDouble() * total;
    for (var i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r <= 0) return items[i];
    }
    return items.last;
  }

  /// In-place Fisher–Yates shuffle.
  List<T> shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = items[i];
      items[i] = items[j];
      items[j] = t;
    }
    return items;
  }

  /// Derive an independent child generator (used for per-attempt sub-seeds).
  DeterministicRandom fork(int salt) =>
      DeterministicRandom(_mixHash(seed, salt));

  static int _mixHash(int a, int b) {
    var h = (a & 0xFFFFFFFFFFFFFFFF) ^ ((b & 0xFFFFFFFFFFFFFFFF) * 0x9E3779B97F4A7C15);
    h = (h ^ (h >>> 33)) * 0xFF51AFD7ED558CCD;
    h = (h ^ (h >>> 33)) * 0xC4CEB9FE1A85EC53;
    return (h ^ (h >>> 33)) & 0xFFFFFFFFFFFFFFFF;
  }

  /// Stable 32-bit string hash (used for daily seeds such as `2026-08-31`).
  static int hashString(String value) {
    var h = 0x811C9DC5;
    for (var i = 0; i < value.length; i++) {
      h ^= value.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Deterministic Gaussian-ish value in `[0,1]` (sum of uniforms, cheap).
  double nextBell() =>
      (nextDouble() + nextDouble() + nextDouble()) / 3.0;

  /// Utility used by the generator for "spread out" scoring.
  static double distanceWeightedScore(double d, double ideal) =>
      1.0 / (1.0 + (d - ideal).abs());

  /// Convenience alias for algorithms that want a `math.Random`-like API.
  double get nextGaussian {
    // Box–Muller, deterministic from two uniforms.
    final u1 = nextDouble() < 1e-12 ? 1e-12 : nextDouble();
    final u2 = nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}
