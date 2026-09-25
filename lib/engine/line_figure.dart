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
///   arrows - arrowheads: (x1, y1, x2, y2) = a head at (x2, y2) pointing away
///           from (x1, y1) along that unit step (the shaft is an ordinary seg)
///   hatch - striped regions: (cellX, cellY, part, dir); part 0-3 = the
///           half-cell triangle as in [tris], 4 = the whole cell; dir 0 '/',
///           1 '\', 2 '-', 3 '|' (stripe direction)
///   arcs  - quarter circles in DOUBLED coordinates (X = 2x) so a centre can
///           sit on a lattice point, an edge middle or a cell centre:
///           (X, Y, R, q), radius R/2 units, quadrant q 0 NE, 1 SE, 2 SW, 3 NW.
///           A semicircle is two arcs, a circle four.
///   glyphs - small symbols in a cell: (cellX, cellY, name), see [glyphNames]
class LineFig {
  final int w, h;
  final Set<(int, int, int, int)> segs;
  final Set<(int, int)> cells;
  final Set<(int, int, int)> tris;
  final Set<(int, int)> dots;
  final Set<(int, int)> rings;
  final Set<(int, int, int, int)> arrows;
  final Set<(int, int, int, int)> hatch;
  final Set<(int, int, int, int)> arcs;
  final Set<(int, int, String)> glyphs;
  final bool frame;

  LineFig(
    this.w,
    this.h, {
    Set<(int, int, int, int)>? segs,
    Set<(int, int)>? cells,
    Set<(int, int, int)>? tris,
    Set<(int, int)>? dots,
    Set<(int, int)>? rings,
    Set<(int, int, int, int)>? arrows,
    Set<(int, int, int, int)>? hatch,
    Set<(int, int, int, int)>? arcs,
    Set<(int, int, String)>? glyphs,
    this.frame = false,
  })  : segs = {for (final s in segs ?? const <(int, int, int, int)>{}) _normSeg(s)},
        cells = {...?cells},
        tris = {...?tris},
        dots = {...?dots},
        rings = {...?rings},
        arrows = {...?arrows},
        hatch = {...?hatch},
        arcs = {...?arcs},
        glyphs = {...?glyphs};

  /// Quadrant q of an arc as the direction of its middle (y down).
  static const arcQuadrants = [(1, -1), (1, 1), (-1, 1), (-1, -1)];

  /// Stripe direction d of a hatch as a vector (sign-free).
  static const hatchDirs = [(1, -1), (1, 1), (1, 0), (0, 1)];

  /// A full circle of [radius] units centred on lattice point (x, y).
  static Set<(int, int, int, int)> circle(int x, int y, int radius) => {for (int q = 0; q < 4; q++) (2 * x, 2 * y, 2 * radius, q)};

  // ── glyphs ────────────────────────────────────────────────────────────────
  // Each glyph is a tiny drawing in a local box (-2..2, y down): strokes and
  // circles (x, y, r, filled). Turning/mirroring a glyph is done on that
  // drawing and looked up again, so '=' turned becomes '||' exactly and '+'
  // stays '+'.
  static const Map<String, (List<(int, int, int, int)>, List<(int, int, int, bool)>)> glyphShapes = {
    'plus': ([(0, -2, 0, 2), (-2, 0, 2, 0)], []),
    'cross': ([(-2, -2, 2, 2), (-2, 2, 2, -2)], []),
    'star': ([(0, -2, 0, 2), (-2, 0, 2, 0), (-2, -2, 2, 2), (-2, 2, 2, -2)], []),
    'minus': ([(-2, 0, 2, 0)], []),
    'bar': ([(0, -2, 0, 2)], []),
    'eq': ([(-2, -1, 2, -1), (-2, 1, 2, 1)], []),
    'eqv': ([(-1, -2, -1, 2), (1, -2, 1, 2)], []),
    'ring': ([], [(0, 0, 2, false)]),
    'dot': ([], [(0, 0, 1, true)]),
    'pct': ([(-2, 2, 2, -2)], [(-1, -1, 1, false), (1, 1, 1, false)]),
    'pctb': ([(-2, -2, 2, 2)], [(1, -1, 1, false), (-1, 1, 1, false)]),
  };

  static List<String> get glyphNames => glyphShapes.keys.toList();

  static String _glyphKey(List<(int, int, int, int)> strokes, List<(int, int, int, bool)> circles) {
    final s = [for (final (a, b, c, d) in strokes) (a < c || (a == c && b <= d)) ? '$a,$b,$c,$d' : '$c,$d,$a,$b']..sort();
    final c = [for (final e in circles) '$e']..sort();
    return '${s.join(';')}|${c.join(';')}';
  }

  static final Map<String, String> _glyphByKey = {
    for (final e in glyphShapes.entries) _glyphKey(e.value.$1, e.value.$2): e.key,
  };

  /// The glyph [name] after the linear map (x, y) -> (a x + b y, c x + d y).
  static String _mapGlyph(String name, int a, int b, int c, int d) {
    final (strokes, circles) = glyphShapes[name]!;
    (int, int) m(int x, int y) => (a * x + b * y, c * x + d * y);
    final key = _glyphKey([
      for (final (x1, y1, x2, y2) in strokes)
        () {
          final (p, q) = m(x1, y1);
          final (r, s) = m(x2, y2);
          return (p, q, r, s);
        }(),
    ], [
      for (final (x, y, rad, f) in circles)
        () {
          final (p, q) = m(x, y);
          return (p, q, rad, f);
        }(),
    ]);
    return _glyphByKey[key] ?? (throw StateError('glyph $name has no image under ($a $b; $c $d)'));
  }

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
    Set<(int, int, int, int)>? arrows,
    Set<(int, int, int, int)>? hatch,
    Set<(int, int, int, int)>? arcs,
    Set<(int, int, String)>? glyphs,
    bool? frame,
  }) =>
      LineFig(w, h,
          segs: segs ?? this.segs,
          cells: cells ?? this.cells,
          tris: tris ?? this.tris,
          dots: dots ?? this.dots,
          rings: rings ?? this.rings,
          arrows: arrows ?? this.arrows,
          hatch: hatch ?? this.hatch,
          arcs: arcs ?? this.arcs,
          glyphs: glyphs ?? this.glyphs,
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

    // The map's linear part (all our maps are turns/flips: entries 0 or ±1).
    final (o1, o2) = f(0, 0);
    final (e1x, e1y) = f(2, 0);
    final (e2x, e2y) = f(0, 2);
    final la = (e1x - o1) ~/ 2, lc = (e1y - o2) ~/ 2, lb = (e2x - o1) ~/ 2, ld = (e2y - o2) ~/ 2;
    (int, int) lin(int x, int y) => (la * x + lb * y, lc * x + ld * y);

    const off = [(0, 0), (1, 0), (1, 1), (0, 1)];
    int corner(int cx, int cy, int k) {
      final (ox, oy) = off[k];
      final (nx, ny) = cellOf(cx, cy);
      final (X, Y) = f(2 * (cx + ox), 2 * (cy + oy));
      return off.indexOf((X ~/ 2 - nx, Y ~/ 2 - ny));
    }

    int hatchDir(int d) {
      final (vx, vy) = lin(hatchDirs[d].$1, hatchDirs[d].$2);
      final i = hatchDirs.indexOf((vx, vy));
      return i >= 0 ? i : hatchDirs.indexOf((-vx, -vy));
    }

    return LineFig(newW, newH,
        frame: frame,
        arrows: {
          for (final (x1, y1, x2, y2) in arrows)
            () {
              final (a, b) = pt(x1, y1);
              final (c, d) = pt(x2, y2);
              return (a, b, c, d);
            }(),
        },
        hatch: {
          for (final (cx, cy, part, d) in hatch)
            () {
              final (nx, ny) = cellOf(cx, cy);
              return (nx, ny, part == 4 ? 4 : corner(cx, cy, part), hatchDir(d));
            }(),
        },
        arcs: {
          for (final (X, Y, R, q) in arcs)
            () {
              final (nX, nY) = f(X, Y);
              return (nX, nY, R, arcQuadrants.indexOf(lin(arcQuadrants[q].$1, arcQuadrants[q].$2)));
            }(),
        },
        glyphs: {
          for (final (cx, cy, g) in glyphs)
            () {
              final (nx, ny) = cellOf(cx, cy);
              return (nx, ny, _mapGlyph(g, la, lb, lc, ld));
            }(),
        },
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
              final (nx, ny) = cellOf(cx, cy);
              return (nx, ny, corner(cx, cy, k));
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
    return 'w$w,h$h,f$frame|${s(segs).join()}|${s(cells).join()}|${s(tris).join()}|${s(dots).join()}|${s(rings).join()}'
        '|${s(arrows).join()}|${s(hatch).join()}|${s(arcs).join()}|${s(glyphs).join()}';
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
    for (final (x, y) in [
      ...cells,
      ...dots,
      for (final (x, y, _) in tris) (x, y),
      for (final (x, y, _, _) in hatch) (x, y),
      for (final (x, y, _) in glyphs) (x, y),
    ]) {
      xs..add(x)..add(x + 1);
      ys..add(y)..add(y + 1);
    }
    for (final (x, y) in rings) {
      xs.add(x);
      ys.add(y);
    }
    for (final (x1, y1, x2, y2) in arrows) {
      xs..add(x1)..add(x2);
      ys..add(y1)..add(y2);
    }
    // An arc's extent (centre to its quadrant corner), rounded out to whole
    // lattice units.
    for (final (X, Y, R, q) in arcs) {
      final (sx, sy) = arcQuadrants[q];
      for (final v in [X, X + sx * R]) {
        xs..add((v / 2).floor())..add((v / 2).ceil());
      }
      for (final v in [Y, Y + sy * R]) {
        ys..add((v / 2).floor())..add((v / 2).ceil());
      }
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
      rings: {for (final (x, y) in rings) (x + dx, y + dy)},
      arrows: {for (final (a, b, c, d) in arrows) (a + dx, b + dy, c + dx, d + dy)},
      hatch: {for (final (x, y, p, d) in hatch) (x + dx, y + dy, p, d)},
      arcs: {for (final (x, y, r, q) in arcs) (x + 2 * dx, y + 2 * dy, r, q)},
      glyphs: {for (final (x, y, g) in glyphs) (x + dx, y + dy, g)});

  /// Key identifying the figure up to turning (not flipping) and position.
  String get rotationClassKey => ([for (int r = 0; r < 4; r++) rot(r).shapeKey]..sort()).first;

  /// True if every line and arc of [t] appears in this figure after some
  /// shift - i.e. [t] is hidden in this figure at the same size and
  /// orientation.
  bool embeds(LineFig t) {
    final tn = t.normalized();
    if (tn.segs.isEmpty && tn.arcs.isEmpty) return false;
    for (int dx = 0; dx <= w - tn.w; dx++) {
      for (int dy = 0; dy <= h - tn.h; dy++) {
        if (tn.segs.every((s) => segs.contains((s.$1 + dx, s.$2 + dy, s.$3 + dx, s.$4 + dy))) &&
            tn.arcs.every((a) => arcs.contains((a.$1 + 2 * dx, a.$2 + 2 * dy, a.$3, a.$4)))) {
          return true;
        }
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
        if (arrows.isNotEmpty) 'arrows': [for (final (a, b, c, d) in arrows) [a, b, c, d]],
        if (hatch.isNotEmpty) 'hatch': [for (final (x, y, p, d) in hatch) [x, y, p, d]],
        if (arcs.isNotEmpty) 'arcs': [for (final (x, y, r, q) in arcs) [x, y, r, q]],
        if (glyphs.isNotEmpty) 'glyphs': [for (final (x, y, g) in glyphs) [x, y, g]],
      };

  static LineFig fromMap(Map<String, dynamic> m) {
    List<List<int>> l(String k) => [for (final e in (m[k] as List? ?? const [])) (e as List).cast<int>()];
    return LineFig(m['w'] as int, m['h'] as int,
        frame: m['frame'] as bool? ?? false,
        segs: {for (final s in l('segs')) (s[0], s[1], s[2], s[3])},
        cells: {for (final c in l('cells')) (c[0], c[1])},
        tris: {for (final t in l('tris')) (t[0], t[1], t[2])},
        dots: {for (final d in l('dots')) (d[0], d[1])},
        rings: {for (final r in l('rings')) (r[0], r[1])},
        arrows: {for (final a in l('arrows')) (a[0], a[1], a[2], a[3])},
        hatch: {for (final a in l('hatch')) (a[0], a[1], a[2], a[3])},
        arcs: {for (final a in l('arcs')) (a[0], a[1], a[2], a[3])},
        glyphs: {for (final g in (m['glyphs'] as List? ?? const [])) ((g as List)[0] as int, g[1] as int, g[2] as String)});
  }
}
