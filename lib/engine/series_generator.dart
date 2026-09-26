import 'dart:math';

import 'line_figure.dart';
import 'reasoning_question.dart';

/// Exam-style Figure Series (JNVST Part 4), modelled on the 2025 paper
/// (SS256J Q13-16): three problem figures, find the fourth.
///
/// Rule families, each at an easy and a hard setting:
///   arrow    - an arrow turns while its cross-bars go up/down by one (Q14);
///              easy: it turns 45° a step like a clock hand, bars fixed
///   symbols  - symbols move round the cells of a grid (Q15, Q16)
///   spokes   - lines from the centre appear/disappear one by one (Q13)
///              while a dot moves round
///   turning  - a figure turns while a dot moves round the corners
///
/// ANSWER SETS: every question has two independent parts that change, and
/// the options are {right, part A wrong} x {right, part B wrong}. With the
/// old one-change-per-distractor sets the answer was the option most like
/// the other three 64-100% of the time (measured); in a 2x2 set no option
/// stands out. No option is ever a copy of a problem figure.
class SeriesGenerator {
  static Random _r = Random();

  static void seed(int s) => _r = Random(s);

  static T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  static const families = ['arrow', 'symbols', 'spokes', 'turning'];

  /// Easy (grades 2-3) families: ONE thing changes per step. 'turning' is
  /// Hard only - with the figure the only thing changing, its sole honest
  /// wrong option is the mirror image, too hard at that age.
  static const easyFamilies = ['arrow', 'symbols', 'spokes'];

  static ReasoningQuestion? generate({bool hard = false, String? family}) {
    for (int attempt = 0; attempt < 60; attempt++) {
      final f = family ?? _pick(hard ? families : easyFamilies);
      final built = switch (f) {
        'arrow' => _arrowSeries(hard),
        'symbols' => _symbolSeries(hard),
        'spokes' => _spokeSeries(hard),
        _ => _turningSeries(hard),
      };
      if (built == null) continue;
      final (frames, correct, a, b, ab) = built;
      final opts = [correct, a, b, ab];
      final keys = opts.map((o) => o.key).toSet();
      if (keys.length != 4) continue;
      if (frames.any((fr) => keys.contains(fr.key))) continue;
      final order = [0, 1, 2, 3]..shuffle(_r);
      return ReasoningQuestion(
        category: 'figure_series',
        type: 'series_exam_$f',
        puzzle: {
          'type': 'series',
          'rule': f,
          'sequence': [for (final fr in frames) fr.toMap()],
        },
        options: [for (final i in order) opts[i].toMap()],
        correctIndex: order.indexOf(0),
      );
    }
    return null;
  }

  // ── arrow: turns, cross-bars count up or down ─────────────────────────────

  /// Directions 0-7, clockwise from "up", 45° apart (y down).
  static const dir8 = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)];

  /// Arrow through the centre of a 6x6 box: ring on the tail, head at the
  /// front, [bars] cross-bars from the tail end.
  static LineFig arrow(int d, int bars) {
    final (vx, vy) = dir8[d % 8];
    final (tx, ty) = (3 - 2 * vx, 3 - 2 * vy);
    final (hx, hy) = (3 + 2 * vx, 3 + 2 * vy);
    final segs = {...LineFig.line(tx, ty, hx, hy)};
    // Cross-bar: perpendicular, one unit either side (a 45° bar on a
    // diagonal arrow), at 1, 2, 3 steps from the tail.
    final (wx, wy) = (-vy, vx);
    for (int t = 1; t <= bars; t++) {
      final px = tx + t * vx, py = ty + t * vy;
      segs.addAll(LineFig.line(px - wx, py - wy, px + wx, py + wy));
    }
    return LineFig(6, 6, frame: true, segs: segs, arrows: {(hx - vx, hy - vy, hx, hy)}, rings: {(tx, ty)});
  }

  static (List<LineFig>, LineFig, LineFig, LineFig, LineFig)? _arrowSeries(bool hard) {
    if (!hard) return _easyArrow();
    final turn = _pick([1, -1, 3, -3]);
    final d0 = _r.nextInt(8);
    final up = _r.nextBool();
    final bars = up ? [0, 1, 2, 3] : [3, 2, 1, 0];
    final dirs = [for (int i = 0; i < 4; i++) (d0 + turn * i) % 8];
    // Wrong turn: one step too far, or turned the other way. Never the
    // third figure's direction or the exact opposite (which shares the shaft).
    final wrongDirs = {(dirs[3] + turn) % 8, (dirs[2] - turn) % 8}
      ..removeWhere((w) => w == dirs[3] || w == dirs[2] || w == (dirs[3] + 4) % 8);
    if (wrongDirs.isEmpty) return null;
    final w = _pick(wrongDirs.toList());
    final wb = bars[2]; // bars didn't change
    return (
      [for (int i = 0; i < 3; i++) arrow(dirs[i], bars[i])],
      arrow(dirs[3], bars[3]),
      arrow(w, bars[3]),
      arrow(dirs[3], wb),
      arrow(w, wb),
    );
  }

  /// Easy: the arrow turns like a clock hand, 45° a step, and nothing else
  /// changes. Wrong options: one step too far, and an extra cross-bar.
  static (List<LineFig>, LineFig, LineFig, LineFig, LineFig)? _easyArrow() {
    final turn = _pick([1, -1]);
    final d0 = _r.nextInt(8);
    final bars = 1 + _r.nextInt(2);
    final dirs = [for (int i = 0; i < 5; i++) (d0 + turn * i) % 8];
    final wb = bars + _pick<int>(const [1, -1]);
    return (
      [for (int i = 0; i < 3; i++) arrow(dirs[i], bars)],
      arrow(dirs[3], bars),
      arrow(dirs[4], bars),
      arrow(dirs[3], wb),
      arrow(dirs[4], wb),
    );
  }

  // ── symbols moving round the cells of a grid ──────────────────────────────

  static const symbolPool = ['plus', 'cross', 'ring', 'star', 'eq', 'minus', 'pct', 'dot'];

  /// Border cells of a w x h grid, clockwise from the top-left.
  static List<(int, int)> ring(int w, int h) {
    final out = <(int, int)>[];
    for (int x = 0; x < w; x++) {
      out.add((x, 0));
    }
    for (int y = 1; y < h; y++) {
      out.add((w - 1, y));
    }
    for (int x = w - 2; x >= 0; x--) {
      out.add((x, h - 1));
    }
    for (int y = h - 2; y >= 1; y--) {
      out.add((0, y));
    }
    return out;
  }

  static LineFig _grid(int w, int h, bool lines, Map<(int, int), String> cells) => LineFig(w, h,
      frame: true,
      segs: lines
          ? {
              for (int x = 1; x < w; x++) ...LineFig.line(x, 0, x, h),
              for (int y = 1; y < h; y++) ...LineFig.line(0, y, w, y),
            }
          : {},
      glyphs: {for (final e in cells.entries) (e.key.$1, e.key.$2, e.value)});

  static (List<LineFig>, LineFig, LineFig, LineFig, LineFig)? _symbolSeries(bool hard) {
    // Easy: 2x2 with dividing lines, every cell filled, one step (Q15).
    // Hard: 3x2 or 3x3 border (Q16-like), four symbols among empty cells,
    // one or two steps; a 3x3 grid may hold a centre symbol that stays put.
    final (w, h) = hard ? _pick([(3, 2), (3, 3)]) : (2, 2);
    final lines = !hard || _r.nextBool();
    final cycle = ring(w, h);
    final n = cycle.length;
    final step = (hard && n == 8 ? _pick([1, 2]) : 1) * (_r.nextBool() ? 1 : -1);
    final symbols = [...symbolPool]..shuffle(_r);
    final slots = [for (int i = 0; i < n; i++) i]..shuffle(_r);
    // Easy: just two symbols to follow; hard: four.
    final count = hard ? 4 : 2;
    final start = <int, String>{for (int i = 0; i < count; i++) slots[i]: symbols[i]};
    final centre = w == 3 && h == 3 && _r.nextBool() ? symbols[4] : null;

    Map<(int, int), String> at(Map<int, String> m) => {
          for (final e in m.entries) cycle[e.key]: e.value,
          (1, 1): ?centre,
        };
    Map<int, String> moved(int k) => {for (final e in start.entries) ((e.key + step * k) % n + n) % n: e.value};

    final answer = moved(3);
    // Wrong options: two different pairs of neighbouring cells swapped.
    final pairs = [for (int i = 0; i < n; i++) (i, (i + 1) % n)]
      ..retainWhere((p) => answer[p.$1] != answer[p.$2])
      ..shuffle(_r);
    (int, int)? first, second;
    for (final p in pairs) {
      if (first == null) {
        first = p;
      } else if ({p.$1, p.$2}.intersection({first.$1, first.$2}).isEmpty) {
        second = p;
        break;
      }
    }
    if (first == null || second == null) return null;
    Map<int, String> swap(Map<int, String> m, (int, int) p) {
      final out = {...m}..remove(p.$1)..remove(p.$2);
      if (m[p.$1] != null) out[p.$2] = m[p.$1]!;
      if (m[p.$2] != null) out[p.$1] = m[p.$2]!;
      return out;
    }

    return (
      [for (int k = 0; k < 3; k++) _grid(w, h, lines, at(moved(k)))],
      _grid(w, h, lines, at(answer)),
      _grid(w, h, lines, at(swap(answer, first))),
      _grid(w, h, lines, at(swap(answer, second))),
      _grid(w, h, lines, at(swap(swap(answer, first), second))),
    );
  }

  // ── spokes appear / disappear, a dot moves round ─────────────────────────

  /// The 8 spoke ends of a 4x4 box, clockwise from the top.
  static const spokeEnds = [(2, 0), (4, 0), (4, 2), (4, 4), (2, 4), (0, 4), (0, 2), (0, 0)];

  /// Cells between the spokes where the dot sits, clockwise from the top.
  /// Each is a quarter turn of the previous one about the centre.
  static const dotCells = [(1, 0), (3, 1), (2, 3), (0, 2)];

  /// Corner cells of the turning family's 6x6 box, clockwise from the
  /// top-left.
  static const cornerCells = [(0, 0), (5, 0), (5, 5), (0, 5)];

  static LineFig _spokes(Set<int> spokes, int dot) => LineFig(4, 4,
      frame: true,
      segs: {for (final s in spokes) ...LineFig.line(2, 2, spokeEnds[s].$1, spokeEnds[s].$2)},
      dots: {dotCells[dot]});

  static (List<LineFig>, LineFig, LineFig, LineFig, LineFig)? _spokeSeries(bool hard) {
    final remove = hard && _r.nextBool();
    final s = (hard ? _pick([1, 2, 3]) : 1) * (_r.nextBool() ? 1 : -1);
    final a0 = _r.nextInt(8);
    final changed = [for (int i = 0; i < 4; i++) ((a0 + s * i) % 8 + 8) % 8];
    if (changed.toSet().length < 4) return null;
    // Spokes present before anything changes: adding starts from one or
    // two other spokes; removing starts from the full set minus a couple.
    final others = [for (int i = 0; i < 8; i++) if (!changed.contains(i)) i]..shuffle(_r);
    final base = remove ? {...changed, ...others.skip(hard ? 2 : 1)} : {...others.take(1 + _r.nextInt(2))};
    Set<int> at(int k) => remove ? base.difference(changed.take(k).toSet()) : {...base, ...changed.take(k)};

    // Easy: the dot stays put - the spokes are the one thing changing.
    final dStep = hard ? _pick([1, 2]) * (_r.nextBool() ? 1 : -1) : 0;
    final d0 = _r.nextInt(4);
    int dot(int k) => ((d0 + dStep * k) % 4 + 4) % 4;

    // Wrong spoke: the one after next (skipped a place), or the spoke on
    // the other side of the last change.
    final nextWrong = ((changed[3] + s) % 8 + 8) % 8;
    final backWrong = ((changed[2] - s) % 8 + 8) % 8;
    final wrongs = <Set<int>>[
      for (final x in [nextWrong, backWrong])
        if (remove) at(2).difference({x}) else {...at(2), x},
    ]..removeWhere((set) => set.length != at(3).length || set.containsAll(at(3)));
    if (wrongs.isEmpty) return null;
    final wrongSpokes = _pick(wrongs);
    // Wrong dot: didn't move, or moved one step too far.
    final wrongDot = hard
        ? _pick([dot(2), ((dot(3) + dStep) % 4 + 4) % 4].where((d) => d != dot(3)).toList())
        : (dot(3) + 1) % 4; // easy: the dot moved when it shouldn't have

    return (
      [for (int k = 0; k < 3; k++) _spokes(at(k), dot(k))],
      _spokes(at(3), dot(3)),
      _spokes(wrongSpokes, dot(3)),
      _spokes(at(3), wrongDot),
      _spokes(wrongSpokes, wrongDot),
    );
  }

  // ── a figure turns, a dot moves round the corners ─────────────────────────

  static const _steps4 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)];

  /// A connected, fully asymmetric stroke figure on the inner points 1..5
  /// of a 6x6 box, so turning it about the centre keeps it inside and it
  /// never reaches the corner cells the dot moves through.
  static LineFig? _innerFigure() {
    for (int attempt = 0; attempt < 50; attempt++) {
      final segs = <(int, int, int, int)>{};
      final pts = <(int, int)>[(1 + _r.nextInt(5), 1 + _r.nextInt(5))];
      final count = 6 + _r.nextInt(3);
      for (int guard = 0; segs.length < count && guard < 100; guard++) {
        final (x, y) = _pick(pts);
        final (dx, dy) = _pick(_steps4);
        final nx = x + dx, ny = y + dy;
        if (nx < 1 || ny < 1 || nx > 5 || ny > 5) continue;
        if (segs.add(LineFig.line(x, y, nx, ny).first)) pts.add((nx, ny));
      }
      // A black corner makes the turn easy to follow, as in the exam.
      final f = LineFig(6, 6, segs: segs, tris: _r.nextBool() ? {(1 + _r.nextInt(4), 1 + _r.nextInt(4), _r.nextInt(4))} : {});
      // Big enough to read as a figure, not a speck.
      final n = f.normalized();
      if (n.w < 3 || n.h < 3) continue;
      if (f.dihedral().map((g) => g.key).toSet().length == 8) return f;
    }
    return null;
  }

  static LineFig _turning(LineFig fig, int corner) =>
      fig.copyWith(frame: true, dots: {cornerCells[corner]});

  static (List<LineFig>, LineFig, LineFig, LineFig, LineFig)? _turningSeries(bool hard) {
    final f = _innerFigure();
    if (f == null) return null;
    final turn = _pick([1, 3]);
    // Easy: the dot goes round the same way as the figure; hard: the other
    // way, or two corners at a time.
    final dStep = hard ? _pick([turn == 1 ? -1 : 1, 2]) : (turn == 1 ? 1 : -1);
    final c0 = _r.nextInt(4);
    int corner(int k) => ((c0 + dStep * k) % 4 + 4) % 4;
    final figs = [for (int k = 0; k < 4; k++) f.rot(turn * k)];
    // Wrong figure: the mirror image of the right one (the classic trap).
    final wrongFig = figs[3].mirrorX();
    final wrongCorner = _pick([corner(2), ((corner(3) + dStep) % 4 + 4) % 4].where((c) => c != corner(3)).toList());
    return (
      [for (int k = 0; k < 3; k++) _turning(figs[k], corner(k))],
      _turning(figs[3], corner(3)),
      _turning(wrongFig, corner(3)),
      _turning(figs[3], wrongCorner),
      _turning(wrongFig, wrongCorner),
    );
  }
}
