// Space Visualisation (lib/engine/space_vis_generator.dart), checked from
// the DRAWINGS alone: the regions each option's lines enclose are found by
// flood fill and compared with the regions of the given pieces. Nothing is
// taken from the generator's own bookkeeping.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/space_vis_generator.dart';

const runs = 300;

/// (x, y, q): quarter q (0 top, 1 right, 2 bottom, 3 left) of unit cell (x, y).
typedef Q = (int, int, int);

/// The closed regions of a line drawing, as sets of quarter-cells. A region
/// is closed if no undrawn edge of the drawing's box lets it leak outside.
List<Set<Q>> regions(LineFig f) {
  bool drawn(int a, int b, int c, int d) => f.segs.contains((a < c || (a == c && b <= d)) ? (a, b, c, d) : (c, d, a, b));
  final seen = <Q>{};
  final out = <Set<Q>>[];
  for (int x = 0; x < f.w; x++) {
    for (int y = 0; y < f.h; y++) {
      for (int q = 0; q < 4; q++) {
        if (seen.contains((x, y, q))) continue;
        final region = <Q>{(x, y, q)};
        seen.add((x, y, q));
        final todo = <Q>[(x, y, q)];
        var leaks = false;
        while (todo.isNotEmpty) {
          final (cx, cy, cq) = todo.removeLast();
          final next = <Q>[];
          // Neighbours in the same cell, through a half-diagonal: quarters
          // q and q+1 meet at corner q+1 (TR, BR, BL, TL); that half-diagonal
          // belongs to the cell's '/' (TR, BL) or '\' (BR, TL) diagonal.
          for (final (other, corner) in [((cq + 1) % 4, (cq + 1) % 4), ((cq + 3) % 4, cq)]) {
            final slash = corner == 1 || corner == 3;
            final blocked = slash ? drawn(cx, cy + 1, cx + 1, cy) : drawn(cx, cy, cx + 1, cy + 1);
            if (!blocked) next.add((cx, cy, other));
          }
          // Neighbour across this quarter's cell side.
          final (a, b, c, d) = [(cx, cy, cx + 1, cy), (cx + 1, cy, cx + 1, cy + 1), (cx, cy + 1, cx + 1, cy + 1), (cx, cy, cx, cy + 1)][cq];
          if (!drawn(a, b, c, d)) {
            const step = [(0, -1), (1, 0), (0, 1), (-1, 0)];
            final nx = cx + step[cq].$1, ny = cy + step[cq].$2;
            if (nx < 0 || ny < 0 || nx >= f.w || ny >= f.h) {
              leaks = true;
            } else {
              next.add((nx, ny, (cq + 2) % 4));
            }
          }
          for (final n in next) {
            if (seen.add(n)) {
              region.add(n);
              todo.add(n);
            }
          }
        }
        if (!leaks) out.add(region);
      }
    }
  }
  return out;
}

/// A region's shape up to position and turning (turnsOnly) or also flipping.
String shapeKey(Set<Q> r, {bool flips = false}) {
  String norm(Iterable<Q> s) {
    final mx = s.map((e) => e.$1).reduce((a, b) => a < b ? a : b), my = s.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
    return ([for (final (x, y, q) in s) '${x - mx},${y - my},$q']..sort()).join(';');
  }

  Iterable<Q> rot(Iterable<Q> s) => [for (final (x, y, q) in s) (-y, x, (q + 1) % 4)];
  Iterable<Q> flip(Iterable<Q> s) => [for (final (x, y, q) in s) (-x, y, q.isOdd ? 4 - q : q)];
  final keys = <String>[];
  for (final start in [r, if (flips) flip(r)]) {
    Iterable<Q> s = start;
    for (int i = 0; i < 4; i++) {
      keys.add(norm(s));
      s = rot(s);
    }
  }
  return (keys..sort()).first;
}

LineFig fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

List<String> pieceKeys(ReasoningQuestion q, {bool flips = false}) => [
      for (final p in q.puzzle['pieces'] as List)
        () {
          final r = regions(fig(p));
          expect(r.length, 1, reason: 'a given piece must be one closed region');
          return shapeKey(r.single, flips: flips);
        }(),
    ]..sort();

List<String> optionKeys(Map<String, dynamic> o, {bool flips = false}) => [for (final r in regions(fig(o))) shapeKey(r, flips: flips)]..sort();

void main() {
  for (final hard in [false, true]) {
    test('${hard ? 'hard' : 'easy'}: exactly one option is made from the pieces', () {
      SpaceVisGenerator.seed(11);
      var central = 0;
      final outlines = <String, int>{};
      for (int i = 0; i < runs; i++) {
        final q = SpaceVisGenerator.generate(hard: hard);
        expect(q, isNotNull, reason: 'generator gave up on run $i');
        outlines[q!.puzzle['outline'] as String] = (outlines[q.puzzle['outline']] ?? 0) + 1;
        final given = pieceKeys(q).join('|');
        final matching = [for (int o = 0; o < 4; o++) if (optionKeys(q.options[o]).join('|') == given) o];
        expect(matching, [q.correctIndex]);

        // Wrong options stay wrong even if the pieces could be flipped over.
        final givenFlip = pieceKeys(q, flips: true).join('|');
        for (int o = 0; o < 4; o++) {
          if (o != q.correctIndex) expect(optionKeys(q.options[o], flips: true).join('|'), isNot(givenFlip));
        }

        // Same outline and same number of pieces everywhere: neither gives
        // the answer away.
        final count = (q.puzzle['pieces'] as List).length;
        final shape = regions(fig(q.options[q.correctIndex])).expand((r) => r).toSet();
        for (final o in q.options) {
          expect(regions(fig(o)).length, count);
          expect(regions(fig(o)).expand((r) => r).toSet(), shape);
        }
        expect(count, hard ? inInclusiveRange(3, 4) : inInclusiveRange(2, 3));

        // Context-blind shortcut: is the answer the option most like the rest?
        final segs = [for (final o in q.options) fig(o).segs];
        final totals = [for (final a in segs) segs.fold<int>(0, (s, b) => s + a.difference(b).length + b.difference(a).length)];
        final best = totals.reduce((a, b) => a < b ? a : b);
        if (totals[q.correctIndex] == best && totals.where((t) => t == best).length == 1) central++;
      }
      // ignore: avoid_print
      print('space_vis ${hard ? 'hard' : 'easy'}: outlines $outlines; answer is the unique most-central option in '
          '${(100 * central / runs).toStringAsFixed(1)}% (chance 25%)');
      expect(central / runs, lessThan(0.35));
    });
  }

  test('routed through QuestionGenerator in both modes', () {
    QuestionGenerator.seed(5);
    QuestionGenerator.resetSession();
    for (final hard in [false, true]) {
      for (int i = 0; i < 20; i++) {
        final q = QuestionGenerator.generate('space_vis', isHardMode: hard);
        expect(q.category, 'space_vis');
        expect(q.puzzle['type'], 'space_vis');
      }
    }
  });
}
