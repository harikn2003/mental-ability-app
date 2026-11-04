// Pattern: the 2x2 quarter that the answer copies flips or turns into the
// gap; in a 3x3 matrix, a pair of cells that changes the same way is shown
// first, then the same change lands in the "?" (or, for a logic layer, the
// two cells that combine fly in together).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/scene.dart';

import 'explain_helpers.dart';

List<String> _moves(List<Beat> beats) => [
      for (final b in beats)
        switch (b) {
          TurnBeat(:final degrees, :final part) => 'turn ${((degrees % 360) + 360) % 360} ${part ?? ''}',
          FlipBeat() => 'flip',
          ResizeBeat() => 'resize',
          MoveBeat() => 'move',
          GlideBeat() => 'glide',
          RegroupBeat() => 'regroup',
          SwapBeat(:final changed) => 'swap ${(changed.toList()..sort()).join(',')}',
        },
    ];

/// What changes from [a] to [b], value by value: amounts by how much (turns
/// modulo a full turn), named things (shape, fill...) by what they become; on/off
/// switches by toggling. Two pairs make
/// "the same change" only if these are equal.
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
  final out = <String, String>{};
  for (final k in {...fa.keys, ...fb.keys}) {
    final x = fa[k], y = fb[k];
    final key = k.substring(k.lastIndexOf('.') + 1);
    const named = {'shape', 'inner', 'filled', 'mirror', 'missingCorner', 'fill'};
    if (x is num && y is num && !named.contains(key)) {
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

/// Layers that fly into the gap without an example first.
var _bare = 0;

/// A Sandia layer as one shape and how many copies of it (copies differ only
/// in where they sit).
Map<String, dynamic> _summary(dynamic layer) {
  final f = [for (final x in (layer as Map)['features'] as List) Morph.plain(x as Map)..remove('cx')..remove('cy')];
  return f.isEmpty ? {'count': 0} : {'count': f.length, ...f.first};
}

Map<String, String> _layerChange(dynamic a, dynamic b) => _change(_summary(a), _summary(b));

/// Deciding parts no line of the grid gives.
var _unfixed = 0;

/// Some line through the gap (two cells back, one back) gives part [k] of the
/// answer's layer [i]: the same step again, or the same value all along.
bool _derivable(List<Map<String, dynamic>> cells, int m, dynamic answerLayer, int i, String k) {
  for (final (dr, dc) in const [(0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, 1), (-1, 1), (1, -1)]) {
    final (sr, sc, er, ec) = (m ~/ 3 - dr, m % 3 - dc, m ~/ 3 - 2 * dr, m % 3 - 2 * dc);
    if ([sr, sc, er, ec].any((v) => v < 0 || v > 2)) continue;
    final s = (cells[sr * 3 + sc]['layers'] as List)[i], e = (cells[er * 3 + ec]['layers'] as List)[i];
    final step = _layerChange(e, s)[k], into = _layerChange(s, answerLayer)[k];
    if (step == into) return true;
  }
  return false;
}

/// The parts of layer [i] that tell the options apart.
Set<String> _deciding(List<Map<String, dynamic>> options, int i) => {
      for (final o in options.skip(1)) ..._layerChange((options.first['layers'] as List)[i], (o['layers'] as List)[i]).keys,
    };

/// Layer by layer: each layer of the answer flies in from a neighbour of the
/// gap and lands on the layers already there. An example before it (one step
/// further back along the same line) changes every deciding part that the
/// layer changes on its way in, by the same amounts. Parts the gap then takes
/// on after two cells of a line pulse are the same in both of those cells.
void _checkLayers(ReasoningQuestion q, List<SceneStep> steps, int missing) {
  final cells = [for (final c in q.puzzle['cells'] as List) Morph.plain(c as Map)];
  final options = [for (final o in q.options) Morph.plain(o)];
  final layers = options[q.correctIndex]['layers'] as List;
  final flies = steps.whereType<FlyStep>().toList();
  final into = [for (final f in flies) if (f.to == missing) f];
  expect(into, hasLength(layers.length), reason: 'one layer at a time');
  for (int i = 0; i < into.length; i++) {
    final f = into[i];
    final landed = (f.land!['layers'] as List);
    expect(landed, hasLength(i + 1), reason: 'layers land in order');
    final mine = (cells[f.from]['layers'] as List)[i];
    expect(Morph.same((f.figure!['layers'] as List).single as Map, mine as Map), isTrue, reason: 'layer $i flies from cell ${f.from}');
    final dr = missing ~/ 3 - f.from ~/ 3, dc = missing % 3 - f.from % 3;
    expect(dr.abs() <= 1 && dc.abs() <= 1, isTrue, reason: 'layer $i comes from a neighbour');
    final keys = _deciding(options, i);
    final k = flies.indexOf(f);
    final ex = k > 0 && flies[k - 1].to == f.from ? flies[k - 1] : null;
    final gapChange = {for (final e in _layerChange(mine, landed[i]).entries) if (keys.contains(e.key)) e.key: e.value};
    final exChange = ex == null ? const <String, String>{} : _layerChange((cells[ex.from]['layers'] as List)[i], mine);
    if (ex == null) {
      _bare++;
    } else {
      expect((ex.from ~/ 3, ex.from % 3), (f.from ~/ 3 - dr, f.from % 3 - dc), reason: 'the example is one step back along the same line');
      expect(Morph.same(ex.land!, cells[f.from]), isTrue, reason: 'the example lands on the cell that flies next');
      expect(gapChange.keys.any((k) => exChange[k] == gapChange[k]), isTrue, reason: 'layer $i: the example explains nothing');
    }
    // A deciding part the layer changes unlike its example: no line of the
    // grid gives it (the grid doesn't fix it).
    for (final k in gapChange.keys) {
      if (exChange[k] == gapChange[k] || k == '.count') continue;
      expect(_derivable(cells, missing, layers[i], i, k), isFalse, reason: 'layer $i: $k changes without the example that shows it');
      _unfixed++;
    }
  }
  // Parts taken on down a line: both pulsed cells already have them.
  for (int k = 1; k < steps.length; k++) {
    final s = steps[k], p = steps[k - 1];
    if (s is! MorphStep || s.slot != missing) continue;
    expect(p, isA<PulseStep>());
    final pair = (p as PulseStep).slots;
    expect(pair, hasLength(2));
    final (e, n) = (pair[0], pair[1]);
    expect((missing ~/ 3 - n ~/ 3, missing % 3 - n % 3), (n ~/ 3 - e ~/ 3, n % 3 - e % 3), reason: 'the pulsed cells are a line through the gap');
    final before = s.beats.first.from['layers'] as List, after = s.beats.last.to['layers'] as List;
    final i = after.length - 1;
    final taken = _layerChange(before[i], after[i]);
    expect(taken, isNotEmpty);
    final want = _summary(after[i]);
    for (final key in taken.keys) {
      final name = key.substring(1);
      expect([_summary((cells[e]['layers'] as List)[i])[name], _summary((cells[n]['layers'] as List)[i])[name]], [want[name], want[name]],
          reason: 'layer $i takes on $name from cells $e and $n');
    }
  }
}

void main() {
  test('every pattern question', () {
    final alone = <String, int>{}, byLayers = <String, int>{};
    checkTopic('pattern', {
      'pattern_quarter', 'matrix_shape_cycle', 'matrix_dot_rotation', 'matrix_inner_shape', 'matrix_dual_rule', 'sandia_full_matrix',
    }, rule: (q, scene) {
      final missing = q.puzzle['missing'] as int? ?? 8;
      expect(scene.answerSlot, missing, reason: 'the answer lands in the gap');
      final flies = scene.steps.whereType<FlyStep>().toList() + [for (final t in scene.steps.whereType<TogetherStep>()) ...t.steps.whereType<FlyStep>()];
      if (q.type == 'pattern_quarter') {
        final fly = flies.single;
        expect(fly.to, missing);
        expect(fly.beats.every((b) => b is TurnBeat || b is FlipBeat), isTrue, reason: 'a quarter is a turned or mirrored copy');
        return;
      }
      final together = scene.steps.whereType<TogetherStep>().toList();
      if (together.isNotEmpty) {
        // Logic: two cells of the gap's row or column fly in and combine.
        final pair = together.single.steps.whereType<FlyStep>().toList();
        expect(pair, hasLength(2));
        final row = missing ~/ 3, col = missing % 3;
        final same = pair.every((f) => f.from ~/ 3 == row) || pair.every((f) => f.from % 3 == col);
        expect(same, isTrue, reason: '${q.type}: combined cells not in one row or column');
        return;
      }
      if (flies.any((f) => f.land != null)) {
        _checkLayers(q, scene.steps, missing);
        byLayers[q.type] = (byLayers[q.type] ?? 0) + 1;
        return;
      }
      if (flies.length == 1) {
        // No pair changes like the gap (rare mixed-rule Sandia grids): the
        // nearest neighbour changes into the answer on its own.
        // (Dual-rule grids whose dots hit the generator's cap of 4 break
        // the count progression, so no pair shows the gap's change.)
        expect(q.type, anyOf('sandia_full_matrix', 'matrix_dual_rule'), reason: '${q.type}: no example pair');
        expect(flies.single.to, missing);
        alone[q.type] = (alone[q.type] ?? 0) + 1;
        if (q.type == 'sandia_full_matrix') {
          // Only when the grid gives none of the parts that tell the options
          // apart (the generator left them free): nothing honest to show.
          final cells = [for (final c in q.puzzle['cells'] as List) Morph.plain(c as Map)];
          final options = [for (final o in q.options) Morph.plain(o)];
          final layers = options[q.correctIndex]['layers'] as List;
          for (int i = 0; i < layers.length; i++) {
            for (final k in _deciding(options, i).difference({'.count'})) {
              expect(_derivable(cells, missing, layers[i], i, k), isFalse, reason: 'layer $i: the grid gives $k, but it is not shown');
            }
          }
        }
        return;
      }
      // Example pair first, then the same change into the gap.
      expect(flies, hasLength(2));
      final (ref, ans) = (flies.first, flies.last);
      expect(ans.to, missing);
      final dr = (ref.to ~/ 3) - (ref.from ~/ 3), dc = (ref.to % 3) - (ref.from % 3);
      expect((missing ~/ 3) - (ans.from ~/ 3), dr, reason: 'the example pair is a different step');
      expect((missing % 3) - (ans.from % 3), dc, reason: 'the example pair is a different step');
      expect(_moves(ans.beats), _moves(ref.beats), reason: '${q.type}: the example changes differently');
      final cells = [for (final c in q.puzzle['cells'] as List) Morph.plain(c as Map)];
      expect(_change(cells[ans.from], q.options[q.correctIndex]), _change(cells[ref.from], cells[ref.to]),
          reason: '${q.type}: the example changes by other amounts than the gap');
    });
    // Sandia grids whose layers follow different lines are explained layer by
    // layer; left out are only grids that don't fix what decides the answer.
    expect(alone['sandia_full_matrix'] ?? 0, lessThanOrEqualTo(10), reason: 'too many Sandia grids without an example: $alone (by layers: $byLayers)');
    expect(byLayers.keys, everyElement('sandia_full_matrix'));
    // ignore: avoid_print
    print('by layers: $byLayers, alone: $alone, layers without example: $_bare, parts the grid does not fix: $_unfixed');
    expect(alone['matrix_dual_rule'] ?? 0, lessThanOrEqualTo(5), reason: 'too many dual-rule grids without an example pair: $alone');
  });
}
