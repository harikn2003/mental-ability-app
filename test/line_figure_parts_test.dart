// The exam's drawing vocabulary beyond plain lines (docs: JNVST 2025 SS256J):
// arrowheads, hatching, arcs/curves and small symbols. Each must turn and
// mirror EXACTLY, because answer checking relies on LineFig keys: a mirror
// question is only correct if the "mirror" option really is the mirror image.
//
// Two layers of checks:
//   - model: known single-part cases, group identities, round-trips;
//   - painter: drawing the mirrored/turned figure must give the mirrored/
//     turned picture of the original, pixel for pixel (within anti-aliasing).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/painters/line_figure_painter.dart';

/// A figure using every kind of part, with no symmetry at all.
final LineFig everything = LineFig(4, 4,
    segs: {...LineFig.line(0, 0, 0, 4), ...LineFig.line(0, 4, 3, 4), ...LineFig.line(1, 1, 3, 3), (3, 0, 4, 0)},
    arrows: {(2, 2, 3, 3), (3, 0, 4, 0)},
    hatch: {(1, 0, 4, 0), (3, 2, 1, 2), (2, 3, 3, 1)},
    arcs: {(2, 6, 2, 0), (8, 2, 4, 2), (5, 5, 1, 1)},
    glyphs: {(3, 1, 'pct'), (0, 1, 'eq'), (1, 3, 'plus')},
    dots: {(2, 0)});

void main() {
  group('model', () {
    test('group identities hold with every kind of part', () {
      expect(everything.rot(4).key, everything.key);
      expect(everything.mirrorX().mirrorX().key, everything.key);
      expect(everything.mirrorY().key, everything.mirrorX().rot(2).key);
      // Mirror then turn = turn the other way then mirror.
      expect(everything.mirrorX().rot(1).key, everything.rot(3).mirrorX().key);
      expect(everything.dihedral().map((g) => g.key).toSet().length, 8);
    });

    test('glyphs turn and mirror like the symbols they draw', () {
      String g(LineFig f) => f.glyphs.single.$3;
      LineFig one(String name) => LineFig(1, 1, glyphs: {(0, 0, name)});
      expect(g(one('eq').rot90()), 'eqv');
      expect(g(one('minus').rot90()), 'bar');
      expect(g(one('pct').mirrorX()), 'pctb');
      expect(g(one('pct').rot(2)), 'pct'); // % looks the same upside down
      for (final s in ['plus', 'cross', 'star', 'ring', 'dot']) {
        for (final t in one(s).dihedral()) {
          expect(g(t), s, reason: '$s is fully symmetric');
        }
      }
    });

    test('hatching: mirror swaps / and \\, a quarter turn swaps - and |', () {
      int dir(LineFig f) => f.hatch.single.$4;
      LineFig one(int d) => LineFig(1, 1, hatch: {(0, 0, 4, d)});
      expect(dir(one(0).mirrorX()), 1);
      expect(dir(one(1).mirrorX()), 0);
      expect(dir(one(2).mirrorX()), 2);
      expect(dir(one(2).rot90()), 3);
      expect(dir(one(0).rot90()), 1);
      // A hatched half-cell moves with its corner, like a black triangle.
      final half = LineFig(2, 2, hatch: {(1, 0, 1, 0)}, tris: {(1, 0, 1)});
      final r = half.rot90();
      expect(r.hatch.single.$3, r.tris.single.$3);
    });

    test('arcs: the NE quarter mirrors to NW and turns to SE', () {
      final a = LineFig(2, 2, arcs: {(2, 2, 2, 0)});
      expect(a.mirrorX().arcs, {(2, 2, 2, 3)});
      expect(a.rot90().arcs, {(2, 2, 2, 1)});
      // A full circle in the middle is unchanged by everything.
      final c = LineFig(2, 2, arcs: LineFig.circle(1, 1, 1));
      for (final t in c.dihedral()) {
        expect(t.key, c.key);
      }
    });

    test('arrows: a right-pointing head mirrors to a left-pointing one', () {
      final a = LineFig(2, 1, segs: {(0, 0, 2, 0)}, arrows: {(1, 0, 2, 0)});
      expect(a.mirrorX().arrows, {(1, 0, 0, 0)});
      expect(a.key, isNot(a.mirrorX().key));
    });

    test('normalized/shift keep every part, and embedding sees arcs', () {
      final small = LineFig(2, 2, segs: {(0, 0, 1, 0)}, arcs: {(2, 2, 2, 1)});
      final big = small.shift(3, 1, 6, 5).copyWith(segs: {...small.shift(3, 1, 6, 5).segs, (0, 0, 0, 1)});
      expect(big.embeds(small), isTrue);
      // Same lines, but the arc is in another quadrant: not hidden.
      expect(big.embeds(small.copyWith(arcs: {(2, 2, 2, 0)})), isFalse);
      expect(everything.shift(2, 3, 9, 9).normalized().key, everything.normalized().key);
    });

    test('map round-trip keeps every part', () {
      expect(LineFig.fromMap(everything.toMap()).key, everything.key);
    });
  });

  group('painter', () {
    const size = 120;

    Future<Uint8List> render(WidgetTester tester, LineFig f) async {
      final key = GlobalKey();
      await tester.pumpWidget(Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: CustomPaint(size: Size.square(size.toDouble()), painter: LineFigurePainter(f.toMap())),
          ),
        ),
      ));
      late Uint8List out;
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
        out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        img.dispose();
      });
      return out;
    }

    /// Dark pixel mask, so anti-aliasing differences don't count.
    List<bool> ink(Uint8List px) => [for (int i = 0; i < px.length; i += 4) px[i] < 128];

    /// Share of inked pixels that don't match after [map]ping (x, y).
    double mismatch(List<bool> a, List<bool> b, (int, int) Function(int x, int y) map) {
      var inked = 0, bad = 0;
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final (mx, my) = map(x, y);
          final av = a[y * size + x], bv = b[my * size + mx];
          if (av || bv) inked++;
          if (av != bv) bad++;
        }
      }
      return bad / inked;
    }

    testWidgets('the drawn mirror image is the mirror of the drawing', (tester) async {
      final a = ink(await render(tester, everything));
      final m = ink(await render(tester, everything.mirrorX()));
      expect(mismatch(a, m, (x, y) => (size - 1 - x, y)), lessThan(0.04));
    });

    testWidgets('the drawn quarter turn is the turned drawing', (tester) async {
      final a = ink(await render(tester, everything));
      final r = ink(await render(tester, everything.rot90()));
      // Clockwise on screen: pixel (x, y) goes to (size-1-y, x).
      expect(mismatch(a, r, (x, y) => (size - 1 - y, x)), lessThan(0.04));
    });

    testWidgets('each new part actually draws something', (tester) async {
      final blank = ink(await render(tester, LineFig(4, 4)));
      expect(blank.where((b) => b), isEmpty);
      for (final f in [
        LineFig(4, 4, arrows: {(1, 2, 2, 2)}),
        LineFig(4, 4, hatch: {(1, 1, 4, 0)}),
        LineFig(4, 4, arcs: {(4, 4, 2, 0)}),
        for (final g in LineFig.glyphNames) LineFig(4, 4, glyphs: {(1, 1, g)}),
      ]) {
        expect(ink(await render(tester, f)).where((b) => b).length, greaterThan(8), reason: f.key);
      }
    });
  });
}
