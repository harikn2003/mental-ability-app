// geo_completion piece geometry (lib/painters/geo_piece_path.dart) and the
// generator's "same shape once turned" classes, checked against the real
// outlines the app draws.

import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/painters/geo_piece_path.dart';

const _rect = Rect.fromLTWH(0, 0, 200, 200);
const _cuts = {0: 8, 1: 4, 2: 4}; // shape -> number of cuts

bool _inWhole(int shape, Offset p) {
  switch (shape) {
    case 0:
      return _rect.contains(p);
    case 1: // triangle (l,b) (cx,t) (r,b)
      final path = Path()
        ..moveTo(_rect.left, _rect.bottom)
        ..lineTo(_rect.center.dx, _rect.top)
        ..lineTo(_rect.right, _rect.bottom)
        ..close();
      return path.contains(p);
    default:
      return (p - _rect.center).distance <= _rect.width / 2;
  }
}

/// Occupancy grid of a piece over its own bounding box (step 2px).
List<List<bool>> _grid(Path p) {
  final b = p.getBounds();
  const step = 2.0;
  final w = (b.width / step).round(), h = (b.height / step).round();
  return [
    for (int y = 0; y < h; y++) [for (int x = 0; x < w; x++) p.contains(Offset(b.left + (x + 0.5) * step, b.top + (y + 0.5) * step))]
  ];
}

List<List<bool>> _rot(List<List<bool>> g) {
  final h = g.length, w = h == 0 ? 0 : g[0].length;
  return [for (int x = 0; x < w; x++) [for (int y = h - 1; y >= 0; y--) g[y][x]]];
}

/// Same shape once turned (not flipped)? Allows a thin boundary mismatch.
bool _congruent(Path a, Path b) {
  final gb = _grid(b);
  var ga = _grid(a);
  for (int r = 0; r < 4; r++) {
    if (ga.length == gb.length && ga.isNotEmpty && ga[0].length == gb[0].length) {
      var diff = 0, total = 0;
      for (int y = 0; y < ga.length; y++) {
        for (int x = 0; x < ga[0].length; x++) {
          if (ga[y][x] != gb[y][x]) diff++;
          if (ga[y][x] || gb[y][x]) total++;
        }
      }
      if (diff <= max(8, total * 0.03)) return true;
    }
    ga = _rot(ga);
  }
  return false;
}

void main() {
  test('every cut splits its shape into two pieces that exactly complete it', () {
    for (final e in _cuts.entries) {
      for (int cut = 0; cut < e.value; cut++) {
        final p0 = GeoPiecePath.of(e.key, cut, 0, _rect), p1 = GeoPiecePath.of(e.key, cut, 1, _rect);
        var both = 0, gaps = 0, stray = 0;
        // Irregular offsets so no sample sits exactly on a cut line (the
        // diagonals, the triangle's medians, the notch lines), where a point
        // is on both pieces' edge and counts as inside both.
        for (double y = 2.71; y < 200; y += 4) {
          for (double x = 1.37; x < 200; x += 4) {
            final p = Offset(x, y);
            final in0 = p0.contains(p), in1 = p1.contains(p);
            if (in0 && in1) both++;
            if (_inWhole(e.key, p) && !in0 && !in1) gaps++;
            if (!_inWhole(e.key, p) && (in0 || in1)) stray++;
          }
        }
        // A few boundary samples can land either way; real mismatches are
        // whole regions (cut 6 used to overlap by ~240 samples).
        expect(both, lessThan(12), reason: 'shape ${e.key} cut $cut: pieces overlap');
        expect(gaps, lessThan(12), reason: 'shape ${e.key} cut $cut: pieces leave a gap');
        expect(stray, lessThan(12), reason: 'shape ${e.key} cut $cut: piece outside the shape');
      }
    }
  });

  test('geoPieceClass matches real "same shape once turned"', () {
    final pieces = [
      for (final e in _cuts.entries)
        for (int cut = 0; cut < e.value; cut++)
          for (int piece = 0; piece < 2; piece++) (e.key, cut, piece)
    ];
    for (int i = 0; i < pieces.length; i++) {
      for (int j = i + 1; j < pieces.length; j++) {
        final (s1, c1, p1) = pieces[i];
        final (s2, c2, p2) = pieces[j];
        final sameClass = QuestionGenerator.geoPieceClass(s1, c1, p1) == QuestionGenerator.geoPieceClass(s2, c2, p2);
        final same = _congruent(GeoPiecePath.of(s1, c1, p1, _rect), GeoPiecePath.of(s2, c2, p2, _rect));
        expect(sameClass, same, reason: '($s1,$c1,$p1) vs ($s2,$c2,$p2): class says $sameClass, outlines say $same');
      }
    }
  });

  test('no geo question offers a wrong piece the same shape as the answer (Easy and Hard)', () {
    for (final hard in [false, true]) {
      QuestionGenerator.resetSession();
      for (int i = 0; i < 300; i++) {
        final q = QuestionGenerator.generate('geo_completion', isHardMode: hard);
        if (q.type != 'geo_jigsaw') continue; // exam-style grid items: exam_style_test.dart
        final classes = [
          for (final o in q.options) QuestionGenerator.geoPieceClass(o['shape'] as int, o['cut'] as int, o['piece'] as int)
        ];
        expect(classes.toSet().length, 4, reason: 'hard=$hard options $classes');
      }
    }
  });
}
