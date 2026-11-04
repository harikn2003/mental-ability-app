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
  if (p['type'] == 'matrix' && p['cells'] is List) return _matrix(p, answer, [for (final o in q.options) Morph.plain(o)]);
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

/// What changes from [a] to [b], value by value: amounts by how much (turns
/// modulo a full turn), named things (shape, fill...) by what they become; on/off
/// switches by toggling.
/// Two pairs show "the same change" only when these are equal.
const _shades = ['white', 'grey40', 'grey10', 'black'];

Map<String, String> _change(Map a, Map b) {
  final fa = <String, dynamic>{}, fb = <String, dynamic>{};
  void flat(dynamic v, String path, Map<String, dynamic> out) {
    if (v is Map) {
      for (final e in v.entries) {
        flat(e.value, '$path.${e.key}', out);
      }
    } else if (v is List) {
      for (int i = 0; i < v.length; i++) {
        flat(v[i], '$path[$i]', out);
      }
    } else {
      out[path] = v;
    }
  }

  flat(a, '', fa);
  flat(b, '', fb);
  const named = {'shape', 'inner', 'filled', 'mirror', 'missingCorner', 'fill'};
  final out = <String, String>{};
  for (final k in {...fa.keys, ...fb.keys}) {
    final x = fa[k], y = fb[k];
    if (x is num && y is num && !named.contains(k.substring(k.lastIndexOf('.') + 1))) {
      if ((x - y).abs() < 1e-9) continue;
      var d = y - x;
      if (k.endsWith('.rotation')) d %= 4;
      if (k.endsWith('.rot')) d %= 360;
      // Sandia shapes shrink by a share, down to a floor: compare the way.
      out[k] = k.endsWith('.scale') ? (d < 0 ? 'smaller' : 'larger') : 'by ${d.toStringAsFixed(4)}';
    } else if (k.endsWith('.fill') && x != y && _shades.contains(x) && _shades.contains(y)) {
      // Sandia fills step through a cycle of shades: compare the steps.
      out[k] = 'shade by ${(_shades.indexOf(y as String) - _shades.indexOf(x as String)) % _shades.length}';
    } else if (x is bool && y is bool) {
      if (x != y) out[k] = 'toggles';
    } else if ('$x' != '$y') {
      out[k] = 'to $y';
    }
  }
  return out;
}

bool _sameChange(Map a, Map b, Map c, Map d) {
  final x = _change(a, b), y = _change(c, d);
  return x.length == y.length && x.entries.every((e) => y[e.key] == e.value);
}

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

Scene? _matrix(Map<String, dynamic> p, Map<String, dynamic> answer, List<Map<String, dynamic>> options) {
  final raw = p['cells'] as List;
  if (raw.length != 9) return null;
  final cells = [for (final c in raw) c is Map && c['empty'] != true ? Morph.plain(c) : null];
  final missing = p['missing'] as int? ?? cells.indexOf(null);
  if (missing < 0) return null;
  return _logic(cells, missing, answer) ?? _byExample(cells, missing, answer, options);
}

/// A pair of cells that changes the way the gap's neighbour must change:
/// both are shown, example first.
Scene? _byExample(List<Map<String, dynamic>?> cells, int m, Map<String, dynamic> answer, List<Map<String, dynamic>> options) {
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
          if (!_sameChange(cells[from]!, cells[to]!, cells[s]!, answer)) continue;
          found = (from, to, s, ref, ans);
        }
      }
      if (found != null) break;
    }
    if (found != null) break;
  }
  if (found == null) return _byLayers(cells, m, answer, options) ?? _nearest(cells, m, answer, sources);
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

/// One layer of [cell], alone.
Map<String, dynamic> _onlyLayer(Map<String, dynamic> cell, int i) => {
      ...cell,
      'layers': [_layers(cell)[i]],
    };

/// A Sandia layer as one shape and how many copies of it (the copies differ
/// only in where they sit), or null when its shapes differ (logic layers).
Map<String, dynamic>? sandiaSummary(Map<String, dynamic> layer) {
  final f = [for (final x in _features(layer)) Morph.plain(x as Map)..remove('cx')..remove('cy')];
  if (f.isEmpty) return {'count': 0};
  if (f.any((x) => _key(x) != _key(f.first))) return null;
  return {'count': f.length, ...f.first};
}

/// [layer] with the [keys] of its shapes taken from [from]'s shapes.
Map<String, dynamic> _withParts(Map<String, dynamic> layer, Map<String, dynamic> from, Set<String> keys) {
  final src = Morph.plain(_features(from).first as Map);
  return {
    ...layer,
    'features': [
      for (final x in _features(layer)) {...Morph.plain(x as Map), for (final k in keys) k.substring(1): src[k.substring(1)]},
    ],
  };
}

/// Sandia layers, and the parts of one layer, follow lines of their own (the
/// shape copied along the row, the shade down the column, a turn along a
/// diagonal), so no whole cell changes like the gap. The answer is built one
/// layer at a time, using only the parts that tell the options apart:
/// - a line of the gap whose step (two cells back to one back) changes some
///   of those parts as the gap's neighbour on the line must: the step flies
///   as an example, then the neighbour's layer flies into the gap and lands
///   on the layers already there;
/// - parts that stay the same down a line: that line's two cells pulse and
///   the gap takes them on (one line after another);
/// - a layer none of this explains flies in from its nearest neighbour.
/// Parts no line gives (the grid doesn't fix them) change as the layer flies.
Scene? _byLayers(List<Map<String, dynamic>?> cells, int m, Map<String, dynamic> answer, List<Map<String, dynamic>> options) {
  if (answer['type'] != 'sandia_cell' || answer['layers'] is! List) return null;
  final ans = _layers(answer);
  bool fits(Map<String, dynamic>? c) => c != null && c['type'] == 'sandia_cell' && c['layers'] is List && _layers(c).length == ans.length;
  if (!options.every(fits) || !cells.every((c) => c == null || fits(c))) return null;
  final mr = m ~/ 3, mc = m % 3;
  int? at(int r, int c) => r < 0 || r > 2 || c < 0 || c > 2 ? null : r * 3 + c;
  // The gap's lines, nearest first: row, column, diagonals: (neighbour, one further).
  final lines = <(int, int)>[
    for (final (dr, dc) in const [(0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, 1), (-1, 1), (1, -1)])
      if (at(mr - dr, mc - dc) case final s? when cells[s] != null)
        if (at(mr - 2 * dr, mc - 2 * dc) case final e? when cells[e] != null) (s, e),
  ];
  if (lines.isEmpty) return null;
  Map<String, String>? change(Map<String, dynamic> a, Map<String, dynamic> b) {
    final x = sandiaSummary(a), y = sandiaSummary(b);
    return x == null || y == null ? null : _change(x, y);
  }

  final steps = <SceneStep>[];
  var gap = <Map<String, dynamic>>[]; // the layers in the gap so far
  Map<String, dynamic> gapCell() => {...answer, 'layers': gap};
  var explained = false;
  for (int i = 0; i < ans.length; i++) {
    Map<String, dynamic> layer(int c) => _layers(cells[c]!)[i];
    Map<String, dynamic> alone(Map<String, dynamic> l) => {...answer, 'layers': [l]};
    final deciding = <String>{};
    for (final o in options) {
      final c = change(ans[i], _layers(o)[i]);
      if (c == null) return null;
      deciding.addAll(c.keys);
    }
    // The line whose step changes the most deciding parts as the gap needs.
    (int, int, Set<String>)? best;
    for (final (s, e) in lines) {
      final step = change(layer(e), layer(s)), into = change(layer(s), ans[i]);
      if (step == null || into == null) continue;
      final keys = {for (final k in deciding) if (step[k] != null && step[k] == into[k]) k};
      if (keys.isNotEmpty && (best == null || keys.length > best.$3.length)) best = (s, e, keys);
    }
    // Lines down which the remaining parts stay the same (not the count:
    // copies can't be taken on one part at a time).
    var rest = deciding.difference(best?.$3 ?? const {})..remove('.count');
    final copies = <(int, int, Set<String>)>[];
    while (rest.isNotEmpty) {
      (int, int, Set<String>)? pick;
      for (final (s, e) in lines) {
        final a = change(layer(e), layer(s)), b = change(layer(s), ans[i]);
        if (a == null || b == null) continue;
        final keys = {for (final k in rest) if (a[k] == null && b[k] == null) k};
        if (keys.isNotEmpty && (pick == null || keys.length > pick.$3.length)) pick = (s, e, keys);
      }
      if (pick == null) break;
      copies.add(pick);
      rest = rest.difference(pick.$3);
    }
    final s = best?.$1 ?? lines.first.$1;
    if (best == null && copies.isEmpty) {
      // No line explains any of its deciding parts: no example for this layer.
      final beats = Morph.diff(_onlyLayer(cells[s]!, i), alone(ans[i]));
      if (beats == null || beats.length > 5) return null;
      gap = [...gap, ans[i]];
      steps.add(FlyStep(s, m, beats, figure: _onlyLayer(cells[s]!, i), land: gapCell(), weight: 1.1));
      continue;
    }
    // It lands with the copied parts still as they are in the neighbour.
    var cur = _withParts(ans[i], layer(s), {for (final c in copies) ...c.$3});
    final beats = Morph.diff(_onlyLayer(cells[s]!, i), alone(cur));
    if (beats == null || beats.length > 5) return null;
    if (best != null) {
      final e = best.$2;
      final ref = Morph.diff(_onlyLayer(cells[e]!, i), _onlyLayer(cells[s]!, i));
      if (ref == null || ref.isEmpty || ref.length > 5) return null;
      steps.addAll([
        FlyStep(e, s, ref, figure: _onlyLayer(cells[e]!, i), land: cells[s], weight: 1.1),
        PulseStep([s], weight: 0.4),
      ]);
      explained = true;
    }
    gap = [...gap, cur];
    steps.add(FlyStep(s, m, beats, figure: _onlyLayer(cells[s]!, i), land: gapCell(), weight: 1.1));
    for (final (cs, ce, keys) in copies) {
      final before = gapCell();
      cur = _withParts(cur, ans[i], keys);
      gap = [...gap.sublist(0, i), cur];
      final take = Morph.diff(before, gapCell());
      if (take == null || take.length > 5) return null;
      // (Already right when the neighbour that flew in has them too: the
      // line still pulses, with the gap, to show they match.)
      steps.addAll([
        if (take.isEmpty) PulseStep([ce, cs, m], weight: 0.5) else PulseStep([ce, cs], weight: 0.5),
        if (take.isNotEmpty) MorphStep(m, take, weight: 0.8),
      ]);
      explained = true;
    }
    if (!Morph.same(cur, ans[i])) return null;
    gap = [...gap.sublist(0, i), ans[i]];
  }
  if (!explained) return null; // nothing explained: plain fallback
  return Scene(extent: _extent, slots: _grid(cells, m), steps: [...steps, const RevealStep()], answerSlot: m);
}

bool _mapEq(Map<String, String> a, Map<String, String> b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

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
