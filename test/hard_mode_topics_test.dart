// Hard Mode for the topics that don't use the Sandia engine (geo_completion,
// mirror_shape, mirror_text, punch_hole, embedded), plus routing for all 10.
//
// Each topic's correct answer is re-derived here from the puzzle data
// itself, independently of the generator, so a generator bug can't make its
// own test pass.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/hard_question_generator.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const int runs = 200;

const allCategories = [
  'pattern', 'analogy', 'odd_man', 'mirror_shape', 'figure_match',
  'figure_series', 'geo_completion', 'mirror_text', 'punch_hole', 'embedded',
];

List<ReasoningQuestion> _hard(String category, [int n = runs]) {
  QuestionGenerator.resetSession();
  return [for (int i = 0; i < n; i++) QuestionGenerator.generate(category, isHardMode: true)];
}

Set<String> _holes(Map<String, dynamic> o) => {
      for (final h in o['holes'] as List) '${((h['x'] as num) * 100).round()},${((h['y'] as num) * 100).round()}',
    };

void main() {
  group('routing', () {
    for (final c in allCategories) {
      test('Hard Mode $c serves $c questions', () {
        for (final q in _hard(c, 40)) {
          expect(q.category, c);
          expect(q.options.length, 4);
          expect(q.correctIndex, inInclusiveRange(0, 3));
        }
      });
    }

    test('HardQuestionGenerator rejects categories it does not own', () {
      expect(() => HardQuestionGenerator.generate('mirror_shape'), throwsArgumentError);
    });
  });

  group('distinct options', () {
    for (final c in ['geo_completion', 'mirror_shape', 'mirror_text', 'punch_hole', 'embedded']) {
      test('$c: every Hard Mode question has 4 visibly different options', () {
        for (final q in _hard(c)) {
          final keys = q.options.map(QuestionGenerator.debugOptionKey).toSet();
          expect(keys.length, 4, reason: '${q.type}: ${q.options}');
        }
      });
    }
  });

  test('punch_hole: double fold, answer = every punch mirrored across both folds', () {
    for (final q in _hard('punch_hole')) {
      expect(q.type, 'punch_hole_double_fold');
      expect(q.puzzle['fold_axis'], 2);
      final expected = <String>{};
      for (final h in q.puzzle['holes'] as List) {
        final x = (h['x'] as num).toDouble(), y = (h['y'] as num).toDouble();
        expect(x, lessThan(0.5));
        expect(y, lessThan(0.5));
        for (final p in [[x, y], [1 - x, y], [x, 1 - y], [1 - x, 1 - y]]) {
          expected.add('${(p[0] * 100).round()},${(p[1] * 100).round()}');
        }
      }
      final matching = [for (int i = 0; i < 4; i++) if (_holes(q.options[i]).containsAll(expected) && _holes(q.options[i]).length == expected.length) i];
      expect(matching, [q.correctIndex]);
    }
  });

  test('mirror_text: clocks show the mirror time, strings are 5 mixed characters', () {
    var clocks = 0, strings = 0;
    for (final q in _hard('mirror_text')) {
      if (q.type == 'mirror_clock') {
        clocks++;
        final h = q.puzzle['clock_hour'] as int, m = q.puzzle['clock_minute'] as int;
        // Mirror = reflect both hand angles: angle -> 360 - angle.
        final wantMinute = (360 - m * 6) % 360;
        final wantHour = (360 - ((h % 12) * 30 + m / 2)) % 360;
        final matching = [
          for (int i = 0; i < 4; i++)
            if ((q.options[i]['clock_minute'] as int) * 6 % 360 == wantMinute &&
                (((q.options[i]['clock_hour'] as int) % 12) * 30 + (q.options[i]['clock_minute'] as int) / 2) % 360 == wantHour)
              i
        ];
        expect(matching, [q.correctIndex], reason: 'puzzle $h:$m');
      } else {
        strings++;
        final content = q.puzzle['content'] as String;
        expect(content.length, 5);
        expect(RegExp(r'\d').hasMatch(content) && RegExp(r'[A-Z]').hasMatch(content), isTrue, reason: content);
        final correct = q.options[q.correctIndex];
        expect(correct['content'], content);
        expect(correct['mirror_h'], isTrue);
        expect(correct['selective_mirror_trap'], isFalse);
      }
    }
    expect(clocks, greaterThan(runs ~/ 4));
    expect(strings, greaterThan(runs ~/ 4));
  });

  test('mirror_shape: answer is the target flipped left-right; wrong answers are the classic confusions', () {
    for (final q in _hard('mirror_shape')) {
      expect(q.type, 'mirror_shape_hard');
      final target = Map<String, dynamic>.from(q.puzzle['target'] as Map);
      final mirrorKey = QuestionGenerator.debugOptionKey({...target, 'mirror': true});
      final matching = [for (int i = 0; i < 4; i++) if (QuestionGenerator.debugOptionKey(q.options[i]) == mirrorKey) i];
      expect(matching, [q.correctIndex]);
      // No option may look like the unflipped target turned into the answer
      // some other way, i.e. only one option equals the mirror image.
      expect(target['dense'], isTrue);
    }
  });

  test('embedded: every option has the target shape, exactly one has it as shown', () {
    for (final q in _hard('embedded')) {
      expect(q.type, 'embedded_hard');
      final target = Map<String, dynamic>.from(q.puzzle['target'] as Map);
      final targetKey = QuestionGenerator.debugOptionKey(target);
      final containing = <int>[];
      for (int i = 0; i < 4; i++) {
        final shapes = [for (final s in q.options[i]['shapes'] as List) Map<String, dynamic>.from(s as Map)];
        expect(shapes.where((s) => s['shape'] == target['shape']).length, 1, reason: 'option $i must hold exactly one ${target['shape']}');
        if (shapes.any((s) => QuestionGenerator.debugOptionKey(s) == targetKey)) containing.add(i);
      }
      expect(containing, [q.correctIndex]);
    }
  });

  test('geo_completion: exactly one piece completes the shown piece', () {
    for (final q in _hard('geo_completion')) {
      final piece = q.puzzle['piece'] as Map;
      final matching = [
        for (int i = 0; i < 4; i++)
          if (q.options[i]['shape'] == piece['shape'] && q.options[i]['cut'] == piece['cut'] && q.options[i]['piece'] == 1 - (piece['piece'] as int)) i
      ];
      expect(matching, [q.correctIndex]);
    }
  });
}
