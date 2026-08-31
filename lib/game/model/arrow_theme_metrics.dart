/// Visual + physical metrics shared by the renderer, the collision system and
/// the generator (prompt §8, §9, §14).
///
/// Defaults follow the master prompt:
/// * `thickness` is expressed in grid cells (0.26 ≈ a slim, elegant line)
/// * `headLength = thickness * 2.8` (prompt example: 2.4)
/// * `headWidth  = thickness * 2.0` (prompt example: 1.8)
/// * `minGap     = thickness * 2.5` (prompt §14: minimum path spacing ≥ 2.5T)
class ArrowMetrics {
  const ArrowMetrics({
    this.thickness = 0.26,
    this.headLengthFactor = 2.8,
    this.headWidthFactor = 2.0,
    this.minGapFactor = 2.5,
  });

  /// Stroke width of the path, in grid cells.
  final double thickness;

  final double headLengthFactor;
  final double headWidthFactor;

  /// Minimum free space between two unrelated paths (prompt §14).
  final double minGapFactor;

  double get headLength => thickness * headLengthFactor;
  double get headWidth => thickness * headWidthFactor;

  /// Minimum surface-to-surface distance enforced at generation time.
  double get minGap => thickness * minGapFactor;

  /// Half stroke, used to inflate centre lines into collision boxes.
  double get halfThickness => thickness / 2;

  ArrowMetrics copyWith({
    double? thickness,
    double? headLengthFactor,
    double? headWidthFactor,
    double? minGapFactor,
  }) =>
      ArrowMetrics(
        thickness: thickness ?? this.thickness,
        headLengthFactor: headLengthFactor ?? this.headLengthFactor,
        headWidthFactor: headWidthFactor ?? this.headWidthFactor,
        minGapFactor: minGapFactor ?? this.minGapFactor,
      );

  Map<String, dynamic> toJson() => {
        'thickness': thickness,
        'headLengthFactor': headLengthFactor,
        'headWidthFactor': headWidthFactor,
        'minGapFactor': minGapFactor,
      };

  factory ArrowMetrics.fromJson(Map<String, dynamic> json) => ArrowMetrics(
        thickness: (json['thickness'] as num?)?.toDouble() ?? 0.26,
        headLengthFactor:
            (json['headLengthFactor'] as num?)?.toDouble() ?? 2.8,
        headWidthFactor: (json['headWidthFactor'] as num?)?.toDouble() ?? 2.0,
        minGapFactor: (json['minGapFactor'] as num?)?.toDouble() ?? 2.5,
      );
}
