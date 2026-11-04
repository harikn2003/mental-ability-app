import 'dart:convert';
import 'dart:ui' show Offset, Size;

import '../morph.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// Pattern: in a 2x2 quarter pattern, the quarter the gap copies turns or
/// flips into the gap. In a 3x3 matrix, a pair of cells shows a change, then
/// the cell beside the gap makes the same change into it; when a layer is
/// two cells combined (Sandia logic), those two cells fly in together and
/// the shapes the rule drops fade away.
Scene? patternScene(ReasoningQuestion q) {
  final p = Morph.plain(q.puzzle);
  final answer = Morph.plain(q.options[q.correctIndex]);
  if (p['type'] == 'quad_pattern') return _quad(p, answer);
  if (p['type'] == 'matrix' && p['cells'] is List) return _matrix(p, answer);
  return null;
}

String _kind(Beat b) => switch (b) {
      TurnBeat(:final degrees, :final part) => 'turn ${((degrees % 360) + 360) % 360} ${part ?? ''}',
      FlipBeat() => 'flip',
      ResizeBeat() => 'resize',
      MoveBeat() => 'move',
      GlideBeat() => 'glide',
      RegroupBeat() => 'regroup',
      SwapBeat(:final changed) => 'swap ${(changed.toList()..sort()).join(',')}',
    };

int _sign(List<Beat> beats) => beats.whereType<TurnBeat>().any((t) => t.degrees < 0) ? -1 : 1;

Scene? _quad(Map<String, dynamic> p, Map<String, dynamic> answer) {
  final tiles = [for (final t in p['tiles'] as List) t is Map ? Morph.plain(t) : null];
  final missing = p['missing'] as int;
  // The quarter the answer is a turned / mirrored copy of (fewest changes).
  (int, List<Beat>)? best;
  for (int i = 0; i < tiles.length; i++) {
    final t = tiles[i];
    if (t == null || i == missing) continue;
    final beats = Morph.diff(t, answer);
    if (beats == null || beats.isEmpty || !beats.every((b) => b is TurnBeat || b is FlipBeat)) continue;
    if (best == null || beats.length < best.$2.length) best = (i, beats);
  }
  if (best == null) return null;
  const size = 72.0, gap = 6.0;
  return Scene(
    extent: const Size(2 * size + gap, 2 * size + gap),
    slots: [
      for (int i = 0; i < tiles.length; i++)
        Slot(figure: i == missing ? null : tiles[i], at: Offset((i % 2) * (size + gap), (i ~/ 2) * (size + gap)), size: size, question: i == missing),
    ],
    steps: [
      FlyStep(best.$1, missing, best.$2, figure: tiles[best.$1], weight: 1.6),
      const RevealStep(),
    ],
    answerSlot: missing,
  );
}

List<Slot> _grid(List<Map<String, dynamic>?> cells, int missing) {
  const size = 60.0, gap = 10.0;
  return [
    for (int i = 0; i < 9; i++)
      Slot(figure: i == missing ? null : cells[i], at: Offset((i % 3) * (size + gap), (i ~/ 3) * (size + gap)), size: size, question: i == missing),
  ];
}

const _extent = Size(3 * 60 + 2 * 10, 3 * 60 + 2 * 10);

Scene? _matrix(Map<String, dynamic> p, Map<String, dynamic> answer) {
  final raw = p['cells'] as List;
  if (raw.length != 9) return null;
  final cells = [for (final c in raw) c is Map && c['empty'] != true ? Morph.plain(c) : null];
  final missing = p['missing'] as int? ?? cells.indexOf(null);
  if (missing < 0) return null;
  return _logic(cells, missing, answer) ?? _byExample(cells, missing, answer);
}

/// A pair of cells that changes the way the gap's neighbour must change:
/// both are shown, example first.
Scene? _byExample(List<Map<String, dynamic>?> cells, int m, Map<String, dynamic> answer) {
  final mr = m ~/ 3, mc = m % 3;
  final sources = <int>[
    for (final d in [-1, 1, -2, 2])
      if (mc + d >= 0 && mc + d < 3) mr * 3 + mc + d,
    for (final d in [-1, 1, -2, 2])
      if (mr + d >= 0 && mr + d < 3) (mr + d) * 3 + mc,
    // Diagonals last (some Sandia rules run along them).
    for (int i = 0; i < 9; i++)
      if (i ~/ 3 != mr && i % 3 != mc) i,
  ];
  (int, int, int, List<Beat>, List<Beat>)? found;
  // First pass wants a real change; the second accepts a plain copy.
  for (final needChange in [true, false]) {
    for (final s in sources) {
      final dr = mr - s ~/ 3, dc = mc - s % 3;
      for (int pr = 0; pr < 3 && found == null; pr++) {
        for (int pc = 0; pc < 3 && found == null; pc++) {
          final qr = pr + dr, qc = pc + dc;
          if (qr < 0 || qr > 2 || qc < 0 || qc > 2) continue;
          final from = pr * 3 + pc, to = qr * 3 + qc;
          // The example is another pair than the answer pair.
          if (from == s) continue;
          if (cells[from] == null || cells[to] == null || cells[s] == null) continue;
          final ref = Morph.diff(cells[from]!, cells[to]!);
          if (ref == null || (needChange && ref.isEmpty)) continue;
          final ans = Morph.diff(cells[s]!, answer, turnSign: _sign(ref));
          if (ans == null) continue;
          if (ans.map(_kind).join('|') != ref.map(_kind).join('|')) continue;
          found = (from, to, s, ref, ans);
        }
      }
      if (found != null) break;
    }
    if (found != null) break;
  }
  if (found == null) return _nearest(cells, m, answer, sources);
  final (from, to, s, ref, ans) = found;
  return Scene(
    extent: _extent,
    slots: _grid(cells, m),
    steps: [
      FlyStep(from, to, ref, figure: cells[from], weight: 1.4),
      PulseStep([to], weight: 0.5),
      FlyStep(s, m, ans, figure: cells[s], weight: 1.4),
      const RevealStep(),
    ],
    answerSlot: m,
  );
}

String _key(dynamic f) {
  final m = Morph.plain(f as Map);
  return jsonEncode({for (final k in m.keys.toList()..sort()) k: m[k]});
}

List<Map<String, dynamic>> _layers(Map<String, dynamic> cell) =>
    [for (final l in (cell['layers'] as List? ?? const [])) Morph.plain(l as Map)];

List<dynamic> _features(Map<String, dynamic> layer) => layer['features'] as List? ?? const [];

/// Sandia logic: some layer of the answer is two cells of its row or column
/// combined (shapes in either / in both / in only one). Both cells fly into
/// the gap and land on top of each other; then the shapes the rule drops
/// fade out.
Scene? _logic(List<Map<String, dynamic>?> cells, int m, Map<String, dynamic> answer) {
  if (answer['type'] != 'sandia_cell' || answer['layers'] is! List) return null;
  final mr = m ~/ 3, mc = m % 3;
  final pairs = <(int, int)>[
    ([for (int c = 0; c < 3; c++) if (c != mc) mr * 3 + c]).toPair(),
    ([for (int r = 0; r < 3; r++) if (r != mr) r * 3 + mc]).toPair(),
  ];
  final ansLayers = _layers(answer);
  for (final (x, y) in pairs) {
    final a = cells[x], b = cells[y];
    if (a == null || b == null) continue;
    final la = _layers(a), lb = _layers(b);
    if (la.length != ansLayers.length || lb.length != ansLayers.length) continue;
    var logic = false;
    for (int i = 0; i < ansLayers.length; i++) {
      final fa = {for (final f in _features(la[i])) _key(f)}, fb = {for (final f in _features(lb[i])) _key(f)};
      final fz = {for (final f in _features(ansLayers[i])) _key(f)};
      if (fa.length == fb.length && fa.containsAll(fb)) continue;
      bool eq(Set<String> s) => s.length == fz.length && s.containsAll(fz);
      if (eq(fa.union(fb)) || eq(fa.intersection(fb)) || eq(fa.union(fb).difference(fa.intersection(fb)))) logic = true;
    }
    if (!logic) continue;
    // Both cells on top of each other: every layer holds the shapes of both.
    final overlay = <String, dynamic>{
      ...answer,
      'layers': [
        for (int i = 0; i < ansLayers.length; i++)
          {
            ...la[i],
            'features': [
              ..._features(la[i]),
              for (final f in _features(lb[i]))
                if (!_features(la[i]).map(_key).contains(_key(f))) f,
            ],
          },
      ],
    };
    return Scene(
      extent: _extent,
      slots: _grid(cells, m),
      steps: [
        TogetherStep([
          FlyStep(x, m, const [], figure: a, land: overlay),
          FlyStep(y, m, const [], figure: b, land: overlay),
        ], weight: 1.6),
        if (!Morph.same(overlay, answer)) MorphStep(m, [SwapBeat(overlay, answer, {'layers'})], weight: 1.2),
        const RevealStep(),
      ],
      answerSlot: m,
    );
  }
  return null;
}

extension on List<int> {
  (int, int) toPair() => (this[0], this[1]);
}

/// No pair in the grid changes exactly like the gap (a few Sandia grids mix
/// several rules along different lines): the closest neighbour changes into
/// the answer on its own, without an example.
Scene? _nearest(List<Map<String, dynamic>?> cells, int m, Map<String, dynamic> answer, List<int> sources) {
  (int, List<Beat>)? best;
  for (final s in sources.take(4)) {
    if (cells[s] == null) continue;
    final beats = Morph.diff(cells[s]!, answer);
    if (beats == null || beats.length > 5) continue;
    if (best == null || beats.length < best.$2.length) best = (s, beats);
  }
  if (best == null) return null;
  return Scene(
    extent: _extent,
    slots: _grid(cells, m),
    steps: [
      FlyStep(best.$1, m, best.$2, figure: cells[best.$1], weight: 1.6),
      const RevealStep(),
    ],
    answerSlot: m,
  );
}
