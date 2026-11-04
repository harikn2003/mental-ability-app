import 'dart:math' show max, min;
import 'dart:ui' show Offset, Size;

import '../line_figure.dart';
import '../morph.dart';
import '../morph_line.dart';
import '../reasoning_question.dart';
import '../scene.dart';
import '../space_vis_generator.dart';

typedef _Seg = (int, int, int, int);

_Seg _norm(int a, int b, int c, int d) => (a < c || (a == c && b <= d)) ? (a, b, c, d) : (c, d, a, b);

/// The unit segments of a quarter's edges (as the generator draws them).
List<_Seg> _edges(Quarter t) {
  final (x, y, q) = t;
  final corners = [(2 * x, 2 * y), (2 * x + 2, 2 * y), (2 * x + 2, 2 * y + 2), (2 * x, 2 * y + 2)];
  final (p1, p2) = (corners[q], corners[(q + 1) % 4]);
  final c = (2 * x + 1, 2 * y + 1);
  final mid = ((p1.$1 + p2.$1) ~/ 2, (p1.$2 + p2.$2) ~/ 2);
  return [
    _norm(p1.$1, p1.$2, mid.$1, mid.$2),
    _norm(mid.$1, mid.$2, p2.$1, p2.$2),
    _norm(p1.$1, p1.$2, c.$1, c.$2),
    _norm(p2.$1, p2.$2, c.$1, c.$2),
  ];
}

/// The flip and/or turn that brings [piece] (drawn as [shape]) upright as
/// [upright] (key [key]): turns before flips, as the line diff orders them.
/// Pieces are compared by shape, not by where they sit in the lattice.
List<Beat>? _turnInto(Map<String, dynamic> piece, LineFig shape, String key, Map<String, dynamic> upright, int m) {
  final ways = shape.dihedral();
  for (final g in [0, 1, 3, 2, 4, 5, 7, 6]) {
    if (ways[g].shapeKey != key) continue;
    final beats = <Beat>[];
    var cur = piece;
    final quarters = switch (g % 4) { 1 => 1, 3 => -1, 2 => 2, _ => 0 };
    if (g >= 4) {
      final mirrored = quarters == 0 ? upright : {...shape.mirrorX().normalized().shift(0, 0, m, m).toMap(), 'center': true};
      if (!Morph.same(cur, mirrored)) beats.add(FlipBeat(cur, mirrored));
      cur = mirrored;
    }
    if (quarters != 0 && !Morph.same(cur, upright)) beats.add(TurnBeat(cur, upright, 90.0 * quarters));
    return beats;
  }
  return null;
}

/// Space Visualisation: the answer figure is cut along its lines into
/// regions; each given piece turns (or flips) to match its region, then
/// slides into place in the "?", which keeps every piece landed so far.
Scene? spaceVisScene(ReasoningQuestion q) {
  final p = Morph.plain(q.puzzle);
  final name = p['outline'];
  if (name is! String || !SpaceVisGenerator.outlines.containsKey(name) || p['pieces'] is! List) return null;
  final answer = Morph.plain(q.options[q.correctIndex]);
  if (answer['type'] != 'line_fig') return null;
  final a = LineFig.fromMap(answer);
  final pieces = [for (final x in p['pieces'] as List) Morph.plain(x as Map)];

  // The answer's lines, back in the generator's (unnormalised) lattice.
  final base = SpaceVisGenerator.outline(name);
  final outer = SpaceVisGenerator.boundary(base);
  final minX = outer.map((s) => min(s.$1, s.$3)).reduce(min), minY = outer.map((s) => min(s.$2, s.$4)).reduce(min);
  final lines = {for (final (x1, y1, x2, y2) in a.segs) _norm(x1 + minX, y1 + minY, x2 + minX, y2 + minY)};

  // Regions: quarters joined across every edge that isn't a line.
  final parent = {for (final t in base) t: t};
  Quarter find(Quarter t) => parent[t] == t ? t : (parent[t] = find(parent[t]!));
  final byEdge = <_Seg, List<Quarter>>{};
  for (final t in base) {
    for (final e in _edges(t)) {
      (byEdge[e] ??= []).add(t);
    }
  }
  for (final e in byEdge.entries) {
    if (e.value.length == 2 && !lines.contains(e.key)) parent[find(e.value[0])] = find(e.value[1]);
  }
  final regions = <Quarter, Set<Quarter>>{};
  for (final t in base) {
    (regions[find(t)] ??= {}).add(t);
  }
  if (regions.length != pieces.length) return null;

  // Everything is drawn on a square lattice, so pieces keep one scale; a
  // non-square answer sits centred in it, as the painter draws it.
  final m = max(a.w, a.h);
  if ((m - a.w).isOdd || (m - a.h).isOdd) return null;
  final ox = (m - a.w) ~/ 2 - minX, oy = (m - a.h) ~/ 2 - minY;

  final left = regions.values.toList();
  final flies = <FlyStep>[];
  final landed = <_Seg>{};
  for (int j = 0; j < pieces.length; j++) {
    final piece = {...pieces[j], 'w': m, 'h': m};
    final shape = LineFig.fromMap(piece);
    FlyStep? fly;
    for (final r in left) {
      final fig = SpaceVisGenerator.pieceFigure(r);
      final upright = {...fig.shift(0, 0, m, m).toMap(), 'center': true};
      final turn = _turnInto(piece, shape, fig.shapeKey, upright, m);
      if (turn == null) continue;
      final rx = r.expand(_edges).map((s) => min(s.$1, s.$3)).reduce(min), ry = r.expand(_edges).map((s) => min(s.$2, s.$4)).reduce(min);
      final placed = fig.shift(rx + ox, ry + oy, m, m);
      final placedMap = placed.toMap();
      landed.addAll(placed.segs);
      final last = j == pieces.length - 1;
      fly = FlyStep(j, pieces.length, [
        ...turn,
        if (!Morph.same(upright, placedMap)) MoveBeat(MorphLine.uncentred(upright), placedMap),
      ], figure: piece, land: last ? answer : LineFig(m, m, segs: {...landed}).toMap(), weight: 1.3);
      left.remove(r);
      break;
    }
    if (fly == null) return null;
    flies.add(fly);
  }

  const size = 60.0, gap = 12.0, big = 130.0;
  final width = max(pieces.length * (size + gap) - gap, big);
  return Scene(
    extent: Size(width, size + 20 + big),
    slots: [
      for (int j = 0; j < pieces.length; j++) Slot(figure: {...pieces[j], 'w': m, 'h': m}, at: Offset(j * (size + gap), 0), size: size),
      Slot(at: Offset((width - big) / 2, size + 20), size: big, question: true),
    ],
    steps: [...flies, const RevealStep()],
    answerSlot: pieces.length,
  );
}
