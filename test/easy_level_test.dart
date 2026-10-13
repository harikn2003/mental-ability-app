// Easy mode is used by grades 2-3 (age ~7-8): ONE thing changes per
// question and no option is a near-twin of the answer. These pin down the
// Easy versions of each topic that once let Medium/Hard material or an
// ambiguous item into Easy, and check Hard still serves the harder items.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const runs = 400;

List<Map<String, dynamic>> holesOf(Map m) => [for (final h in m['holes'] as List) Map<String, dynamic>.from(h as Map)];

bool separated(List<Map<String, dynamic>> holes) {
  for (int i = 0; i < holes.length; i++) {
    for (int j = i + 1; j < holes.length; j++) {
      final dx = (holes[i]['x'] as num) - (holes[j]['x'] as num);
      final dy = (holes[i]['y'] as num) - (holes[j]['y'] as num);
      if (dx * dx + dy * dy < 0.18 * 0.18) return false;
    }
  }
  return true;
}

String holesKey(List<Map<String, dynamic>> holes) =>
    ([for (final h in holes) '${((h['x'] as num) * 100).round()},${((h['y'] as num) * 100).round()}']..sort()).join(';');

List<ReasoningQuestion> easy(String topic, {int n = 200, int seed = 3}) {
  QuestionGenerator.seed(seed);
  QuestionGenerator.resetSession();
  return [for (int i = 0; i < n; i++) QuestionGenerator.generate(topic, difficulty: Difficulty.easy)];
}

List<Map> cells(ReasoningQuestion q) => [for (final c in q.puzzle['cells'] as List) if ((c as Map)['empty'] != true) c];

void main() {
  test('easy mirror text: three clearly-flipping characters, whole-word mistakes only', () {
    QuestionGenerator.seed(1);
    for (int i = 0; i < runs; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      final q = QuestionGenerator.generate('mirror_text');
      final content = q.puzzle['content'] as String;
      expect(content.length, 3);
      expect(content.split('').every('BCDEFGJKLNPRSZ234579'.contains), isTrue, reason: content);
      // No single-letter traps; the right card is the whole word mirrored.
      for (final o in q.options) {
        expect(o['selective_mirror_trap'] == true && o['trap_char_index'] != -99, isFalse, reason: 'single-letter trap in easy');
      }
      final right = q.options[q.correctIndex];
      expect((right['content'], right['mirror_h']), (content, true));
    }
  });

  test('hard mirror text still serves the 5-character set, the single-letter traps and clocks', () {
    QuestionGenerator.seed(2);
    final types = <String>{};
    for (int i = 0; i < runs; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      types.add(QuestionGenerator.generate('mirror_text', isHardMode: true).type);
    }
    expect(types, containsAll(['mirror_text_hard', 'mirror_clock']));
    expect(types.intersection({'mirror_text_word', 'mirror_text_num'}), isNotEmpty);
  });

  test('easy punch hole: one hole, one fold, exactly one card unfolds it right', () {
    QuestionGenerator.seed(3);
    for (int i = 0; i < runs; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      final q = QuestionGenerator.generate('punch_hole');
      final punched = holesOf(q.puzzle);
      expect(punched.length, 1);
      final axis = q.puzzle['fold_axis'] as int;
      final x = punched.single['x'] as double, y = punched.single['y'] as double;
      // Unfold independently: mirror across the fold line.
      final want = holesKey([
        {'x': x, 'y': y},
        axis == 0 ? {'x': 1 - x, 'y': y} : {'x': x, 'y': 1 - y},
      ]);
      expect([for (int o = 0; o < 4; o++) if (holesKey(holesOf(q.options[o])) == want) o], [q.correctIndex]);
    }
  });

  test('punch hole cards never show overlapping holes, at either level', () {
    for (final hard in [false, true]) {
      QuestionGenerator.seed(4);
      for (int i = 0; i < runs; i++) {
        if (i % 10 == 0) QuestionGenerator.resetSession();
        final q = QuestionGenerator.generate('punch_hole', isHardMode: hard);
        for (final o in q.options) {
          expect(separated(holesOf(o)), isTrue, reason: '${q.type}: holes overlap in $o');
        }
      }
    }
  });

  test('hard punch hole serves the exam item, the double fold and the original one-fold item', () {
    QuestionGenerator.seed(5);
    final types = <String>{};
    for (int i = 0; i < runs; i++) {
      if (i % 10 == 0) QuestionGenerator.resetSession();
      types.add(QuestionGenerator.generate('punch_hole', isHardMode: true).type);
    }
    expect(types, containsAll(['punch_hole_exam', 'punch_hole_double_fold', 'punch_hole']));
  });

  test('easy pattern turning grids: no square or pentagon, nothing filled', () {
    final grids = easy('pattern').where((q) => q.type == 'matrix_shape_cycle').toList();
    expect(grids, isNotEmpty);
    for (final q in grids) {
      for (final c in cells(q)) {
        expect([1, 5], isNot(contains(c['shape'])), reason: 'turn of shape ${c['shape']} is hard to see');
        expect(c['filled'], isFalse, reason: 'a filled row is a second rule');
      }
    }
  });

  test('easy pattern dot grids: only the dots change', () {
    final grids = easy('pattern').where((q) => q.type == 'matrix_dot_rotation').toList();
    expect(grids, isNotEmpty);
    for (final q in grids) {
      expect({for (final c in cells(q)) c['rotation']}, hasLength(1));
    }
  });

  test('easy inner-shape series alternates A, B, A and the answer is B', () {
    final qs = easy('figure_series', n: 400).where((q) => q.type.startsWith('series_inner')).toList();
    expect(qs, isNotEmpty);
    for (final q in qs) {
      expect(q.type, 'series_inner_easy', reason: 'Easy served the open-ended inner series');
      final inner = [for (final f in q.puzzle['sequence'] as List) (f as Map)['inner']];
      expect(inner[0], inner[2]);
      expect(q.options[q.correctIndex]['inner'], inner[1]);
      expect({for (final o in q.options) o['inner']}, hasLength(4));
    }
  });

  test('easy geo completion: no triangle to complete', () {
    final pieces = [for (final q in easy('geo_completion')) q.puzzle['piece'] as Map];
    expect(pieces, everyElement(containsPair('type', 'geo_piece')));
    expect(pieces.where((p) => p['shape'] == 1), isEmpty, reason: 'triangle halves are near-twins');
  });
}
