import 'dart:math';

import 'line_figure.dart';
import 'reasoning_question.dart';

/// Exam-style Figure Analogy (JNVST Part 5), modelled on the 2025 paper
/// (SS256J Q17-20): A : B :: C : ?
///
/// Rule families, each at an easy and a hard setting:
///   turn    - the figure is turned (hard: or mirrored) AND a small marker
///             changes, e.g. a dot becomes a ring (Q17, Q19). Easy: simpler
///             figure, quarter turns only, no mirror-image trap
///   corners - four corner squares with different fills; the fills move to
///             other corners (Q18). Easy: bold fills only, and the wrong
///             move is clearly different from the right one
///   nest    - three shapes in a row become nested one inside another, the
///             row order deciding which is outermost (Q20)
///
/// ANSWER SETS: {right, part A wrong} x {right, part B wrong}, so no option
/// is "the one most like the others" (the original analogy's answer was that
/// option 61% of the time Easy, 100% Hard - measured). No wrong option is a
/// copy of a problem figure.
class AnalogyGenerator {
  static Random _r = Random();

  static void seed(int s) => _r = Random(s);

  static T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  static const families = ['turn', 'corners', 'nest'];

  static ReasoningQuestion? generate({bool hard = false, String? family}) {
    for (int attempt = 0; attempt < 80; attempt++) {
      final f = family ?? _pick(families);
      final built = switch (f) {
        'turn' => _turn(hard),
        'corners' => _corners(hard),
        _ => _nest(hard),
      };
      if (built == null) continue;
      final (a, b, c, correct, wa, wb, wab) = built;
      final opts = [correct, wa, wb, wab];
      final keys = opts.map((o) => o.key).toSet();
      if (keys.length != 4) continue;
      final shown = {a.key, b.key, c.key};
      if ([wa, wb, wab].any((o) => shown.contains(o.key))) continue;
      final order = [0, 1, 2, 3]..shuffle(_r);
      return ReasoningQuestion(
        category: 'analogy',
        type: 'analogy_exam_$f',
        puzzle: {'type': 'analogy', 'rule': f, 'A': a.toMap(), 'B': b.toMap(), 'C': c.toMap()},
        options: [for (final i in order) opts[i].toMap()],
        correctIndex: order.indexOf(0),
      );
    }
    return null;
  }

  // ── turn: turned / mirrored, and a marker changes ─────────────────────────

  static const _steps = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)];

  /// Markers look the same however they're turned, so only their place and
  /// kind carry information.
  static const markers = ['dot', 'ring', 'cross', 'plus', 'star'];

  /// Turns / flips by index: 0-3 quarter turns, 4-7 mirror then turn.
  static LineFig transform(LineFig f, int t) => t < 4 ? f.rot(t) : f.mirrorX().rot(t - 4);

  static LineFig? _strokeFigure({bool hard = true}) {
    for (int attempt = 0; attempt < 60; attempt++) {
      final segs = <(int, int, int, int)>{};
      final pts = <(int, int)>[(_r.nextInt(5), _r.nextInt(5))];
      // Easy: a simpler figure, easier to turn in your head.
      final count = hard ? 6 + _r.nextInt(3) : 4 + _r.nextInt(2);
      for (int guard = 0; segs.length < count && guard < 120; guard++) {
        final (x, y) = _pick(pts);
        final (dx, dy) = _pick(_steps);
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx > 4 || ny > 4) continue;
        if (segs.add(LineFig.line(x, y, nx, ny).first)) pts.add((nx, ny));
      }
      final f = LineFig(4, 4, segs: segs);
      if (f.normalized().w >= 3 && f.normalized().h >= 3 && f.dihedral().map((g) => g.key).toSet().length == 8) return f;
    }
    return null;
  }

  static LineFig _marked(LineFig f, (int, int) cell, String marker) => f.copyWith(glyphs: {(cell.$1, cell.$2, marker)});

  static (LineFig, LineFig, LineFig, LineFig, LineFig, LineFig, LineFig)? _turn(bool hard) {
    final f1 = _strokeFigure(hard: hard), f2 = _strokeFigure(hard: hard);
    if (f1 == null || f2 == null || f1.key == f2.key) return null;
    // The rule: easy turns; hard also flips (the mirror-image trap flips
    // round - the right answer is the flipped one).
    // Easy: a quarter turn either way; hard: also flips and turn + flip.
    final t = hard ? _pick([4, 5, 6, 7, 1, 3]) : _pick([1, 3]);
    // Wrong transform. Hard: the mirror image of the right one, or another
    // turn. Easy: turned the other way - upside-down compared with the
    // answer, so it's clearly different; the mirror-image trap (the
    // hardest discrimination in the app) is kept for Hard.
    final wrongs = hard ? [t < 4 ? t + 4 : t - 4, (t + 2) % 4 + (t < 4 ? 0 : 4)] : [(t + 2) % 4];
    final w = _pick(wrongs.where((x) => x != t).toList());
    final (m1, m2) = () {
      final ms = [...markers]..shuffle(_r);
      return (ms[0], ms[1]);
    }();
    // The marker goes in a cell no diagonal stroke crosses, so it never
    // sits on a line (straight strokes only run along cell edges).
    (int, int)? freeCell(LineFig f) {
      final free = [
        for (int x = 0; x < 4; x++)
          for (int y = 0; y < 4; y++)
            if (!f.segs.contains((x, y, x + 1, y + 1)) && !f.segs.contains((x, y + 1, x + 1, y))) (x, y),
      ];
      return free.isEmpty ? null : _pick(free);
    }

    final cell1 = freeCell(f1), cell2 = freeCell(f2);
    if (cell1 == null || cell2 == null) return null;
    final a = _marked(f1, cell1, m1);
    // The marker rides along with the figure, changing kind on the way.
    LineFig after(LineFig f, (int, int) cell, int tr, String marker) {
      final moved = transform(_marked(f, cell, 'dot'), tr);
      final (x, y, _) = moved.glyphs.single;
      return moved.copyWith(glyphs: {(x, y, marker)});
    }

    final b = after(f1, cell1, t, m2);
    final c = _marked(f2, cell2, m1);
    return (
      a, b, c,
      after(f2, cell2, t, m2), // right turn, marker changed
      after(f2, cell2, w, m2), // wrong turn
      after(f2, cell2, t, m1), // marker not changed
      after(f2, cell2, w, m1), // both
    );
  }

  // ── corners: the four corner fills move round ─────────────────────────────

  /// Corner cells of a 4x4 box, clockwise from the top-left.
  static const cornerCells = [(0, 0), (3, 0), (3, 3), (0, 3)];

  /// What can fill a corner square.
  static const fills = ['black', 'hatch', 'lines', 'plain', 'dot', 'cross'];

  static LineFig cornerFigure(List<String> content) {
    final segs = <(int, int, int, int)>{
      ...LineFig.line(1, 1, 3, 1), ...LineFig.line(3, 1, 3, 3), ...LineFig.line(3, 3, 1, 3), ...LineFig.line(1, 3, 1, 1),
    };
    final tris = <(int, int, int)>{}, hatch = <(int, int, int, int)>{}, dots = <(int, int)>{};
    final glyphs = <(int, int, String)>{};
    for (int i = 0; i < 4; i++) {
      final (x, y) = cornerCells[i];
      segs.addAll(LineFig.cellBoundary({(x, y)}));
      switch (content[i]) {
        case 'black':
          tris.addAll({(x, y, 0), (x, y, 2)});
        case 'hatch':
          hatch.add((x, y, 4, 0));
        case 'lines':
          hatch.add((x, y, 4, 2));
        case 'dot':
          dots.add((x, y));
        case 'cross':
          glyphs.add((x, y, 'cross'));
      }
    }
    return LineFig(4, 4, segs: segs, tris: tris, hatch: hatch, dots: dots, glyphs: glyphs);
  }

  /// Corner moves as "content at corner i goes to corner p[i]".
  static const moves = {
    'cw': [1, 2, 3, 0],
    'ccw': [3, 0, 1, 2],
    'half': [2, 3, 0, 1],
    'leftRight': [1, 0, 3, 2],
    'topBottom': [3, 2, 1, 0],
    'diagonal': [2, 1, 0, 3],
    'antiDiagonal': [0, 3, 2, 1],
  };

  static List<String> move(List<String> content, List<int> p) {
    final out = List<String>.filled(4, '');
    for (int i = 0; i < 4; i++) {
      out[p[i]] = content[i];
    }
    return out;
  }

  static (LineFig, LineFig, LineFig, LineFig, LineFig, LineFig, LineFig)? _corners(bool hard) {
    final rule = hard ? _pick(['half', 'diagonal', 'antiDiagonal', 'cw', 'ccw']) : _pick(['cw', 'leftRight', 'topBottom']);
    // The tempting wrong move: the other direction / the other swap.
    const confusions = {
      'cw': ['ccw', 'half'],
      'ccw': ['cw', 'half'],
      'half': ['cw', 'ccw'],
      'leftRight': ['topBottom', 'cw'],
      'topBottom': ['leftRight', 'ccw'],
      'diagonal': ['antiDiagonal', 'half'],
      'antiDiagonal': ['diagonal', 'half'],
    };
    // Easy: the wrong move is a clearly different one (clockwise vs half
    // turn, not clockwise vs anticlockwise).
    const easyConfusions = {'cw': 'half', 'leftRight': 'topBottom', 'topBottom': 'leftRight'};
    final wrong = hard ? _pick(confusions[rule]!) : easyConfusions[rule]!;
    // Easy: only the four boldest fills - no look-alikes (hatched vs lined
    // vs cross) to tell apart at a glance.
    final palette = hard ? fills : const ['black', 'dot', 'hatch', 'plain'];
    final pool = [...palette]..shuffle(_r);
    final ca = pool.take(4).toList();
    final cc = ([...palette]..shuffle(_r)).take(4).toList();
    if (ca.join() == cc.join()) return null;
    final right = move(cc, moves[rule]!), bad = move(cc, moves[wrong]!);
    // Second mistake: two neighbouring corners' fills the wrong way round.
    final i = _r.nextInt(4), j = (i + 1) % 4;
    List<String> swapped(List<String> c) => [...c]
      ..[i] = c[j]
      ..[j] = c[i];
    return (
      cornerFigure(ca),
      cornerFigure(move(ca, moves[rule]!)),
      cornerFigure(cc),
      cornerFigure(right),
      cornerFigure(bad),
      cornerFigure(swapped(right)),
      cornerFigure(swapped(bad)),
    );
  }

  // ── nest: a row of shapes becomes shapes inside shapes ────────────────────

  /// Shapes that stay easy to tell apart when drawn small in the row. (An
  /// octagon was tried and dropped: at row size it looked like the circle.)
  /// shape() can still draw 'octagon'.
  static const kinds = ['circle', 'square', 'diamond'];

  /// Outline of [kind] centred on (cx, cy), half-width h (h even).
  static LineFig shape(String kind, int cx, int cy, int h, int w, int hh) {
    switch (kind) {
      case 'circle':
        return LineFig(w, hh, arcs: LineFig.circle(cx, cy, h));
      case 'square':
        return LineFig(w, hh, segs: {
          ...LineFig.line(cx - h, cy - h, cx + h, cy - h), ...LineFig.line(cx + h, cy - h, cx + h, cy + h),
          ...LineFig.line(cx + h, cy + h, cx - h, cy + h), ...LineFig.line(cx - h, cy + h, cx - h, cy - h),
        });
      case 'diamond':
        return LineFig(w, hh, segs: {
          ...LineFig.line(cx, cy - h, cx + h, cy), ...LineFig.line(cx + h, cy, cx, cy + h),
          ...LineFig.line(cx, cy + h, cx - h, cy), ...LineFig.line(cx - h, cy, cx, cy - h),
        });
      default: // octagon: a square with its corners cut at 45°
        final c = h ~/ 2;
        final pts = [(cx - c, cy - h), (cx + c, cy - h), (cx + h, cy - c), (cx + h, cy + c), (cx + c, cy + h), (cx - c, cy + h), (cx - h, cy + c), (cx - h, cy - c)];
        return LineFig(w, hh, segs: {
          for (int k = 0; k < 8; k++) ...LineFig.line(pts[k].$1, pts[k].$2, pts[(k + 1) % 8].$1, pts[(k + 1) % 8].$2),
        });
    }
  }

  static LineFig _merge(Iterable<LineFig> parts, int w, int h) =>
      LineFig(w, h, segs: {for (final p in parts) ...p.segs}, arcs: {for (final p in parts) ...p.arcs});

  /// Three shapes side by side, left to right.
  static LineFig row(List<String> ks) => _merge([for (int i = 0; i < 3; i++) shape(ks[i], 5 + 10 * i, 5, 4, 30, 10)], 30, 10);

  /// Shapes nested, outermost first (half-widths 8, 4, 2 - each fits inside
  /// any other kind at the next size up).
  static const nestSizes = [8, 4, 2];
  static LineFig nested(List<String> outerFirst) => _merge([for (int i = 0; i < 3; i++) shape(outerFirst[i], 8, 8, nestSizes[i], 16, 16)], 16, 16);

  /// levels[i] = how deep the row's i-th shape goes (0 outermost).
  static List<String> nestByLevels(List<String> rowKinds, List<int> levels) {
    final out = List<String>.filled(3, '');
    for (int i = 0; i < 3; i++) {
      out[levels[i]] = rowKinds[i];
    }
    return out;
  }

  static (LineFig, LineFig, LineFig, LineFig, LineFig, LineFig, LineFig)? _nest(bool hard) {
    const allLevels = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];
    final levels = hard ? _pick(allLevels) : _pick(const [[2, 1, 0], [0, 1, 2]]); // Q20: left innermost
    // Same three shapes in both rows, in a different order (as in Q20).
    final ka = [...kinds]..shuffle(_r);
    final kc = [...kinds]..shuffle(_r);
    if (ka.join() == kc.join()) return null;
    final right = nestByLevels(kc, levels);
    // Mistakes: outer and middle the wrong way round; middle and inner.
    List<String> swap(List<String> o, int x, int y) => [...o]
      ..[x] = o[y]
      ..[y] = o[x];
    return (
      row(ka),
      nested(nestByLevels(ka, levels)),
      row(kc),
      nested(right),
      nested(swap(right, 0, 1)),
      nested(swap(right, 1, 2)),
      nested(swap(swap(right, 0, 1), 1, 2)),
    );
  }
}
