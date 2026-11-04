// The morph engine: the difference between two figures as a chain of single
// changes, every link a real figure, ending exactly on the target.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

/// The chain law: [beats] lead from [a] to [b] link by link, and each
/// beat's frames at 0 and 1 are its own ends.
void expectChain(List<Beat>? beats, Map a, Map b, {int maxBeats = 5, String why = ''}) {
  expect(beats, isNotNull, reason: 'no explanation for $why\n${jsonEncode(a)}\n${jsonEncode(b)}');
  if (Morph.same(a, b)) {
    expect(beats, isEmpty, reason: why);
    return;
  }
  expect(beats, isNotEmpty, reason: why);
  expect(beats!.length, lessThanOrEqualTo(maxBeats), reason: '$why: ${beats.map((x) => x.runtimeType)}');
  expect(Morph.same(beats.first.from, a), isTrue, reason: '$why: chain does not start at the source');
  for (int i = 0; i + 1 < beats.length; i++) {
    expect(Morph.same(beats[i].to, beats[i + 1].from), isTrue, reason: '$why: link $i broken');
  }
  expect(Morph.same(beats.last.to, b), isTrue, reason: '$why: chain does not end at the target');
  for (final beat in beats) {
    expect(Morph.same(Morph.frame(beat, 0), beat.from), isTrue, reason: '$why: frame 0 of ${beat.runtimeType}');
    expect(Morph.same(Morph.frame(beat, 1), beat.to), isTrue, reason: '$why: frame 1 of ${beat.runtimeType}');
    expect(() => Morph.frame(beat, 0.5), returnsNormally);
    expect(Morph.same(beat.from, beat.to), isFalse, reason: '$why: a beat that changes nothing');
  }
}

/// A round trip like a saved session's: JSON, then Map<dynamic, dynamic>.
Map _saved(Map m) {
  dynamic deep(dynamic v) => v is Map ? <dynamic, dynamic>{for (final e in v.entries) e.key: deep(e.value)} : v is List ? [for (final x in v) deep(x)] : v;
  return deep(jsonDecode(jsonEncode(m))) as Map;
}

Map<String, dynamic> _c(Map<String, dynamic> over) =>
    {'shape': 8, 'filled': false, 'rotation': 0, 'mirror': false, 'dots': 0, 'inner': 0, 'lines': 0, 'missingCorner': 0, ...over};

Iterable<ReasoningQuestion> _gen(String cat, bool Function(ReasoningQuestion) ok, {int n = 300}) sync* {
  for (final d in Difficulty.values) {
    QuestionGenerator.seed(21);
    for (int i = 0; i < n; i++) {
      final q = QuestionGenerator.generate(cat, difficulty: d);
      if (ok(q)) yield q;
    }
  }
}

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from(v as Map);

void main() {
  group('classic shapes', () {
    test('a turn', () {
      final beats = Morph.diff(_c({'rotation': 1}), _c({'rotation': 3}));
      expectChain(beats, _c({'rotation': 1}), _c({'rotation': 3}));
      expect(beats!.single, isA<TurnBeat>());
      expect((beats.single as TurnBeat).degrees, 180);
      expect((Morph.diff(_c({'rotation': 3}), _c({'rotation': 0}))!.single as TurnBeat).degrees, 90);
      expect((Morph.diff(_c({'rotation': 0}), _c({'rotation': 3}))!.single as TurnBeat).degrees, -90);
    });

    test('turnSign picks the way of a half turn', () {
      expect((Morph.diff(_c({'rotation': 0}), _c({'rotation': 2}), turnSign: -1)!.single as TurnBeat).degrees, -180);
    });

    test('the half-way frame is half turned', () {
      final beat = Morph.diff(_c({'rotation': 3}), _c({'rotation': 0}))!.single;
      expect(Morph.frame(beat, 0.5)['rotation'], 3.5);
    });

    test('fill, dots and shape are one swap each, in order', () {
      final a = _c({'shape': 2, 'dots': 2}), b = _c({'shape': 5, 'filled': true, 'dots': 4, 'rotation': 1});
      final beats = Morph.diff(a, b);
      expectChain(beats, a, b);
      expect([for (final x in beats!) x is SwapBeat ? x.changed.single : x.runtimeType.toString()], ['shape', 'TurnBeat', 'filled', 'dots']);
    });

    test('a mirror image is a flip', () {
      expect(Morph.diff(_c({}), _c({'mirror': true}))!.single, isA<FlipBeat>());
    });

    test('same figure, no beats (rotation 4 is rotation 0)', () {
      expect(Morph.diff(_c({'rotation': 4}), _c({})), isEmpty);
    });

    test('different kinds cannot be explained', () {
      expect(Morph.diff(_c({}), {'type': 'mirror_text', 'content': 'AB'}), isNull);
    });
  });

  group('Sandia cells', () {
    Map<String, dynamic> cell(List<Map<String, dynamic>> layers) => {'type': 'sandia_cell', 'layers': layers};
    test('layers all turning together are one turn of the whole', () {
      final a = cell([{'surface': 0, 'fill': 1, 'rotation': 0}, {'surface': 1, 'fill': 0, 'rotation': 0}]);
      final b = cell([{'surface': 0, 'fill': 2, 'rotation': 1}, {'surface': 1, 'fill': 1, 'rotation': 1}]);
      final beats = Morph.diff(a, b);
      expectChain(beats, a, b);
      expect(beats!.map((x) => x.runtimeType), [TurnBeat, SwapBeat]);
      expect(beats.first.part, isNull);
    });

    test('one layer turning is a turn of that layer', () {
      final a = cell([{'surface': 0, 'rotation': 0}, {'surface': 1, 'rotation': 0}]);
      final b = cell([{'surface': 0, 'rotation': 0}, {'surface': 1, 'rotation': 1}]);
      final beats = Morph.diff(a, b);
      expectChain(beats, a, b);
      expect(beats!.single.part, 'L1');
    });

    Map<String, dynamic> feat(Map<String, dynamic> over) => {'shape': 'tee', 'w': 0.4, 'h': 0.6, 'rot': 0, 'cx': 0.5, 'cy': 0.5, 'scale': 1.0, 'fill': 'white', ...over};
    test('the whole cell turned: features turn and move round the centre', () {
      final a = cell([{'features': [feat({}), feat({'shape': 'triangle', 'cx': 0.13, 'cy': 0.13})]}]);
      final b = cell([{'features': [feat({'rot': 90}), feat({'shape': 'triangle', 'rot': 90, 'cx': 0.87, 'cy': 0.13})]}]);
      final beats = Morph.diff(a, b);
      expectChain(beats, a, b);
      expect((beats!.single as TurnBeat).degrees, 90);
      final mid = Morph.frame(beats.single, 0.5);
      final corner = ((mid['layers'] as List)[0]['features'] as List)[1] as Map;
      expect(corner['cx'], closeTo(0.5, 1e-9)); // half-way round, at the top middle
      expect(corner['cy'], closeTo(0.5 - 0.37 * 1.41421356, 1e-6));
    });

    test('features changing size is a resize', () {
      final a = cell([{'features': [feat({}), feat({'scale': 1.0})]}]);
      final b = cell([{'features': [feat({}), feat({'scale': 0.66})]}]);
      final beats = Morph.diff(a, b);
      expectChain(beats, a, b);
      expect(beats!.single, isA<ResizeBeat>());
      expect(((Morph.frame(beats.single, 0.5)['layers'] as List)[0]['features'] as List)[1]['scale'], closeTo(0.83, 1e-9));
    });

    test('a feature added is a swap', () {
      final a = cell([{'features': [feat({})]}]);
      final b = cell([{'features': [feat({}), feat({'cx': 0.2})]}]);
      expectChain(Morph.diff(a, b), a, b);
    });
  });

  group('letters', () {
    Map<String, dynamic> word(String s) => {'type': 'mirror_text', 'content': s, 'is_clock': false, 'mirror_h': false, 'mirror_v': false};
    test('the first letter moving to the end is one glide', () {
      final beat = Morph.diff(word('ABCD'), word('BCDA'))!.single as GlideBeat;
      expect(beat.tokens, [(0, 3), (1, 0), (2, 1), (3, 2)]);
    });
    test('a changed letter is a swap', () {
      expect(Morph.diff(word('ABCD'), word('ABCE'))!.single, isA<SwapBeat>());
    });
  });

  group('generated questions', () {
    test('series: every step of classic, Sandia and letter series', () {
      var n = 0;
      for (final q in _gen('figure_series', (q) => !q.type.startsWith('series_exam') && !q.type.startsWith('series_round'))) {
        final seq = [for (final f in q.puzzle['sequence'] as List) _saved(f as Map), _saved(q.options[q.correctIndex])];
        for (int i = 0; i + 1 < seq.length; i++) {
          expectChain(Morph.diff(seq[i], seq[i + 1]), seq[i], seq[i + 1], why: '${q.type} step $i');
          n++;
        }
      }
      expect(n, greaterThan(500));
    });

    test('analogy: A to B and C to the answer (classic and Sandia)', () {
      for (final q in _gen('analogy', (q) => !q.type.startsWith('analogy_exam'))) {
        final p = q.puzzle;
        expectChain(Morph.diff(_saved(p['A']), _saved(p['B'])), _m(p['A']), _m(p['B']), why: '${q.type} A:B');
        expectChain(Morph.diff(_saved(p['C']), _saved(q.options[q.correctIndex])), _m(p['C']), q.options[q.correctIndex], why: '${q.type} C:D');
      }
    });

    test('figure match hard: the answer is the target turned or mirrored', () {
      for (final q in _gen('figure_match', (q) => q.type == 'figure_match_hard')) {
        final t = _saved(q.puzzle['target']), ans = q.options[q.correctIndex];
        final beats = Morph.diff(t, ans);
        expectChain(beats, t, ans, maxBeats: 2, why: q.type);
        expect(beats!.every((b) => b is TurnBeat || b is FlipBeat), isTrue, reason: beats.map((b) => b.runtimeType).join(','));
      }
    });

    test('Sandia matrices: neighbouring cells in a row', () {
      for (final q in _gen('pattern', (q) => q.type == 'sandia_full_matrix')) {
        final cells = [for (final c in q.puzzle['cells'] as List) c == null || (c as Map)['empty'] == true ? null : _saved(c)];
        for (int i = 0; i < cells.length; i++) {
          if (i % 3 == 2 || cells[i] == null || cells[i + 1] == null) continue;
          expectChain(Morph.diff(cells[i]!, cells[i + 1]!), cells[i]!, cells[i + 1]!, why: 'matrix cell $i');
        }
      }
    });
  });
}
