import 'dart:math';

/// Exam-style figures drawn on an integer grid.
///
/// Most JNVST mental-ability figures (embedded figures, pattern completion
/// quarters, figure matching, geometrical completion pieces, mirror images)
/// are line drawings on an implicit square grid. Modelling them on a lattice
/// makes the questions' key relations exact rather than approximate:
///   - "is figure T hidden in figure F"  = T's segments ⊆ F's after a shift
///   - "do these two options look alike" = equal canonical keys
///   - turning / mirroring               = exact lattice maps
///
/// Coordinates: lattice points (x, y) with 0 <= x <= w, 0 <= y <= h, y down.
///   segs  - unit segments between neighbouring points (incl. diagonals);
///           longer lines are chains of unit segments
///   cells - filled grid cells (light fill), by top-left corner
///   tris  - black half-cells: (cellX, cellY, corner) = the triangle with its
///           right angle at that corner (0 TL, 1 TR, 2 BR, 3 BL)
///   dots  - black dots at cell centres, by cell
///   rings - small open circles centred on lattice points
class LineFig {
  final int w, h;
  final Set<(int, int, int, int)> segs;
  final Set<(int, int)> cells;
  final Set<(int, int, int)> tris;
  final Set<(int, int)> dots;
  final Set<(int, int)> rings;
  final bool frame;

  LineFig(
    this.w,
    this.h, {
    Set<(int, int, int, int)>? segs,
    Set<(int, int)>? cells,
    Set<(int, int, int)>? tris,
    Set<(int, int)>? dots,
    Set<(int, int)>? rings,
    this.frame = false,
  })  : segs = {for (final s in segs ?? const <(int, int, int, int)>{}) _normSeg(s)},
        cells = {...?cells},
        tris = {...?tris},
        dots = {...?dots},
        rings = {...?rings};

  static (int, int, int, int) _normSeg((int, int, int, int) s) {
    final (x1, y1, x2, y2) = s;
    return (x1 < x2 || (x1 == x2 && y1 <= y2)) ? s : (x2, y2, x1, y1);
  }

  /// Adds a straight line from (x1,y1) to (x2,y2) as unit segments. The line
  /// must be horizontal, vertical or at 45°.
  static Set<(int, int, int, int)> line(int x1, int y1, int x2, int y2) {
    final dx = (x2 - x1).sign, dy = (y2 - y1).sign;
    final steps = max((x2 - x1).abs(), (y2 - y1).abs());
    assert(dx == 0 || dy == 0 || (x2 - x1).abs() == (y2 - y1).abs(), 'not a lattice line');
    return {for (int i = 0; i < steps; i++) _normSeg((x1 + dx * i, y1 + dy * i, x1 + dx * (i + 1), y1 + dy * (i + 1)))};
  }

  LineFig copyWith({
    Set<(int, int, int, int)>? segs,
    Set<(int, int)>? cells,
    Set<(int, int, int)>? tris,
    Set<(int, int)>? dots,
    Set<(int, int)>? rings,
    bool? frame,
  }) =>
      LineFig(w, h,
          segs: segs ?? this.segs,
          cells: cells ?? this.cells,
          tris: tris ?? this.tris,
          dots: dots ?? this.dots,
          rings: rings ?? this.rings,
          frame: frame ?? this.frame);

  // ── transforms (all exact; work in doubled coordinates) ───────────────────

  /// Applies a point map given in doubled coordinates (X = 2x) to every part.
  /// [newW]/[newH] are the resulting lattice dimensions.
  LineFig _map((int, int) Function(int X, int Y) f, int newW, int newH) {
    (int, int) pt(int x, int y) {
      final (X, Y) = f(2 * x, 2 * y);
      return (X ~/ 2, Y ~/ 2);
    }

    (int, int) cellOf(int cx, int cy) {
      final (X, Y) = f(2 * cx + 1, 2 * cy + 1);
      return ((X - 1) ~/ 2, (Y - 1) ~/ 2);
    }

    return LineFig(newW, newH,
        frame: frame,
        segs: {
          for (final (x1, y1, x2, y2) in segs)
            () {
              final (a, b) = pt(x1, y1);
              final (c, d) = pt(x2, y2);
              return (a, b, c, d);
            }(),
        },
        cells: {for (final (x, y) in cells) cellOf(x, y)},
        dots: {for (final (x, y) in dots) cellOf(x, y)},
        rings: {for (final (x, y) in rings) pt(x, y)},
        tris: {
          for (final (cx, cy, k) in tris)
            () {
              const off = [(0, 0), (1, 0), (1, 1), (0, 1)];
              final (ox, oy) = off[k];
              final (nx, ny) = cellOf(cx, cy);
              final (X, Y) = f(2 * (cx + ox), 2 * (cy + oy));
              final corner = off.indexOf((X ~/ 2 - nx, Y ~/ 2 - ny));
              return (nx, ny, corner);
            }(),
        });
  }

  /// Left-right flip (a mirror held on the right side, as in JNVST).
  LineFig mirrorX() => _map((X, Y) => (2 * w - X, Y), w, h);

  /// Top-bottom flip (water image).
  LineFig mirrorY() => _map((X, Y) => (X, 2 * h - Y), w, h);

  /// Quarter turn clockwise (as seen on screen, y pointing down).
  LineFig rot90() => _map((X, Y) => (2 * h - Y, X), h, w);

  LineFig rot(int quarterTurns) {
    var f = this;
    for (int i = 0; i < ((quarterTurns % 4) + 4) % 4; i++) {
      f = f.rot90();
    }
    return f;
  }

  /// The 8 turns/flips of this figure (identity first).
  List<LineFig> dihedral() => [
        for (int r = 0; r < 4; r++) rot(r),
        for (int r = 0; r < 4; r++) mirrorX().rot(r),
      ];

  // ── comparison ─────────────────────────────────────────────────────────────

  /// Exact visual key: same key <=> the painter draws the same picture.
  String get key {
    List<String> s(Iterable<Object> xs) => xs.map((e) => '$e').toList()..sort();
    return 'w$w,h$h,f$frame|${s(segs).join()}|${s(cells).join()}|${s(tris).join()}|${s(dots).join()}|${s(rings).join()}';
  }

  /// Key ignoring position: the figure shifted so its content starts at 0,0.
  String get shapeKey => normalized().key;

  /// The content shifted to the top-left and the lattice shrunk to fit.
  LineFig normalized() {
    final xs = <int>[], ys = <int>[];
    for (final (x1, y1, x2, y2) in segs) {
      xs..add(x1)..add(x2);
      ys..add(y1)..add(y2);
    }
    for (final (x, y) in [...cells, ...dots, for (final (x, y, _) in tris) (x, y)]) {
      xs..add(x)..add(x + 1);
      ys..add(y)..add(y + 1);
    }
    for (final (x, y) in rings) {
      xs.add(x);
      ys.add(y);
    }
    if (xs.isEmpty) return LineFig(0, 0);
    final mx = xs.reduce(min), my = ys.reduce(min);
    return shift(-mx, -my, xs.reduce(max) - mx, ys.reduce(max) - my);
  }

  LineFig shift(int dx, int dy, int newW, int newH) => LineFig(newW, newH,
      frame: frame,
      segs: {for (final (a, b, c, d) in segs) (a + dx, b + dy, c + dx, d + dy)},
      cells: {for (final (x, y) in cells) (x + dx, y + dy)},
      tris: {for (final (x, y, k) in tris) (x + dx, y + dy, k)},
      dots: {for (final (x, y) in dots) (x + dx, y + dy)},
      rings: {for (final (x, y) in rings) (x + dx, y + dy)});

  /// Key identifying the figure up to turning (not flipping) and position.
  String get rotationClassKey => ([for (int r = 0; r < 4; r++) rot(r).shapeKey]..sort()).first;

  /// True if every segment of [t] appears in this figure after some shift -
  /// i.e. [t] is hidden in this figure at the same size and orientation.
  bool embeds(LineFig t) {
    final tn = t.normalized();
    if (tn.segs.isEmpty) return false;
    for (int dx = 0; dx <= w - tn.w; dx++) {
      for (int dy = 0; dy <= h - tn.h; dy++) {
        if (tn.segs.every((s) => segs.contains((s.$1 + dx, s.$2 + dy, s.$3 + dx, s.$4 + dy)))) return true;
      }
    }
    return false;
  }

  /// Segments separating filled cells from unfilled ones (and the outside).
  static Set<(int, int, int, int)> cellBoundary(Set<(int, int)> cells) {
    final out = <(int, int, int, int)>{};
    for (final (x, y) in cells) {
      if (!cells.contains((x, y - 1))) out.add((x, y, x + 1, y));
      if (!cells.contains((x, y + 1))) out.add((x, y + 1, x + 1, y + 1));
      if (!cells.contains((x - 1, y))) out.add((x, y, x, y + 1));
      if (!cells.contains((x + 1, y))) out.add((x + 1, y, x + 1, y + 1));
    }
    return out;
  }

  // ── serialisation (option / puzzle maps) ──────────────────────────────────

  Map<String, dynamic> toMap() => {
        'type': 'line_fig',
        'w': w,
        'h': h,
        'frame': frame,
        'segs': [for (final (a, b, c, d) in segs) [a, b, c, d]],
        'cells': [for (final (x, y) in cells) [x, y]],
        'tris': [for (final (x, y, k) in tris) [x, y, k]],
        'dots': [for (final (x, y) in dots) [x, y]],
        'rings': [for (final (x, y) in rings) [x, y]],
      };

  static LineFig fromMap(Map<String, dynamic> m) {
    List<List<int>> l(String k) => [for (final e in (m[k] as List? ?? const [])) (e as List).cast<int>()];
    return LineFig(m['w'] as int, m['h'] as int,
        frame: m['frame'] as bool? ?? false,
        segs: {for (final s in l('segs')) (s[0], s[1], s[2], s[3])},
        cells: {for (final c in l('cells')) (c[0], c[1])},
        tris: {for (final t in l('tris')) (t[0], t[1], t[2])},
        dots: {for (final d in l('dots')) (d[0], d[1])},
        rings: {for (final r in l('rings')) (r[0], r[1])});
  }
}
