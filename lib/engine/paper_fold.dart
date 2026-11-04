/// Paper-folding geometry shared by the Punch Hole generators and the answer
/// explanation (which replays the folds backwards). Coordinates are the unit
/// square; fold codes: 'v' right half over left, 'h' bottom over top,
/// 'd' over the main diagonal, 'a' over the anti-diagonal.
class PaperFold {
  /// The older single-panel questions' `fold_axis`: 0 vertical, 1 horizontal,
  /// 2 both (the top-left quarter is left).
  static const Map<int, List<String>> legacyAxisFolds = {
    0: ['v'],
    1: ['h'],
    2: ['v', 'h'],
  };

  /// The folds a punch-hole puzzle makes, in order.
  static List<String> foldsOf(Map puzzle) {
    final folds = puzzle['folds'] as List?;
    if (folds != null) return folds.cast<String>().toList();
    return List.of(legacyAxisFolds[(puzzle['fold_axis'] as num?)?.toInt() ?? 0] ?? const ['v']);
  }

  static (double, double) reflect(String fold, double x, double y) => switch (fold) {
        'v' => (1 - x, y),
        'h' => (x, 1 - y),
        'd' => (y, x),
        _ => (1 - y, 1 - x),
      };

  /// Triangle direction 0 up, 1 right, 2 down, 3 left, reflected by [fold].
  static int reflectDir(String fold, int dir) {
    const v = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    final (dx, dy) = v[dir];
    final r = switch (fold) {
      'v' => (-dx, dy),
      'h' => (dx, -dy),
      'd' => (dy, dx),
      _ => (-dy, -dx),
    };
    return v.indexOf(r);
  }

  /// Unfolds [holes] by undoing [folds] last-first, optionally skipping one
  /// fold ([skip]) and optionally NOT flipping triangle directions.
  static List<Map<String, dynamic>> unfold(List holes, List<String> folds, {int? skip, bool flipShapes = true}) {
    var cur = [for (final h in holes) Map<String, dynamic>.from(h as Map)];
    for (int i = folds.length - 1; i >= 0; i--) {
      if (i == skip) continue;
      final f = folds[i];
      cur = [
        ...cur,
        for (final h in cur)
          () {
            final (x, y) = reflect(f, (h['x'] as num).toDouble(), (h['y'] as num).toDouble());
            return {
              ...h,
              'x': x,
              'y': y,
              if (flipShapes && h['shape'] == 'tri') 'dir': reflectDir(f, (h['dir'] as num).toInt()),
            };
          }(),
      ];
    }
    return cur;
  }

  /// Order-independent key of a set of holes (position to 0.01, shape, and a
  /// triangle's direction).
  static String holesKey(List holes) => ([
        for (final h in holes)
          '${((h['x'] as num) * 100).round()},${((h['y'] as num) * 100).round()},${h['shape'] ?? 'circle'},${h['shape'] == 'tri' ? h['dir'] : ''}'
      ]..sort())
          .join(';');
}
