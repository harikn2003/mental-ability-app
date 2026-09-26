// Easy mode is used by grades 2-3 (age ~7-8): these pin down the Easy
// versions of Mirror Text and Punch Hole, and check Hard still serves the
// harder items those topics used to show in Easy.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

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
}
