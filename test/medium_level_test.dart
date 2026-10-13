// Medium difficulty: a true midpoint for every topic - the same kinds of
// questions as Hard with the hardest trick taken out, or Easy plus one step.
// Each test pins the property that puts a topic's Medium between its Easy
// and Hard.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/engine/analogy_generator.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/series_generator.dart';

void main() {
  List<ReasoningQuestion> medium(String topic, {int n = 200, int seed = 7}) {
    QuestionGenerator.seed(seed);
    QuestionGenerator.resetSession();
    return [for (int i = 0; i < n; i++) QuestionGenerator.generate(topic, difficulty: Difficulty.medium)];
  }

  test('Medium never serves the Sandia matrices except in Pattern', () {
    for (final t in ['odd_man', 'figure_match', 'figure_series', 'analogy']) {
      for (final q in medium(t, n: 100)) {
        expect(q.options.first['type'], isNot('sandia_cell'), reason: '$t served Sandia: ${q.type}');
      }
    }
  });

  test('Medium Analogy (classic share) never changes three things', () {
    final types = {for (final q in medium('analogy')) q.type};
    expect(types.intersection({'analogy_r4', 'analogy_r8'}), isEmpty);
  });

  test('Medium Series (classic share) has no morph series', () {
    final types = {for (final q in medium('figure_series')) q.type};
    expect(types.contains('series_morph'), isFalse);
  });

  test('Medium Pattern serves mirror quarters, never turn quarters', () {
    final quarters = medium('pattern').where((q) => q.type == 'pattern_quarter').toList();
    expect(quarters, isNotEmpty);
    for (final q in quarters) {
      expect(q.puzzle['symmetry'], 'mirror');
    }
  });

  test('Medium Figure Match mixes the lite exam item with the classic one', () {
    final types = {for (final q in medium('figure_match')) q.type};
    expect(types, contains('figure_match_exam'));
  });

  test('Medium classic Figure Match: same shape and fill in every option', () {
    final classic = medium('figure_match').where((q) => q.type == 'figure_match').toList();
    expect(classic, isNotEmpty);
    for (final q in classic) {
      final target = q.puzzle['target'] as Map;
      for (final o in q.options) {
        expect((o['shape'], o['filled']), (target['shape'], target['filled']), reason: 'give-away option $o');
      }
    }
  });

  test('Medium Mirror Text words are 4 characters', () {
    for (final q in medium('mirror_text')) {
      if (q.puzzle['is_clock'] == true) continue;
      expect((q.puzzle['content'] as String).length, 4, reason: q.type);
    }
  });

  LineFig fig(dynamic m) => LineFig.fromMap(Map<String, dynamic>.from(m as Map));

  test('Medium series arrow: 90 degree steps and the bars change', () {
    SeriesGenerator.seed(5);
    for (int i = 0; i < 100; i++) {
      final q = SeriesGenerator.generate(level: Difficulty.medium, family: 'arrow')!;
      final seq = [for (final m in q.puzzle['sequence'] as List) fig(m)];
      expect(seq.map((f) => f.segs.length).toSet().length, greaterThan(1), reason: 'bars must change');
      expect(seq.map((f) => f.arrows.single).toSet().length, 3);
      // Head direction: consecutive arrowheads a quarter turn apart.
      final heads = [for (final f in seq) f.rings.single];
      for (int k = 0; k < 2; k++) {
        final (ax, ay) = (heads[k].$1 - 3, heads[k].$2 - 3);
        final (bx, by) = (heads[k + 1].$1 - 3, heads[k + 1].$2 - 3);
        expect(ax * bx + ay * by, 0, reason: 'tails 90 degrees apart');
      }
    }
  });

  test('Medium series symbols: four symbols on a 2x2 grid', () {
    SeriesGenerator.seed(6);
    for (int i = 0; i < 100; i++) {
      final q = SeriesGenerator.generate(level: Difficulty.medium, family: 'symbols')!;
      final f = fig((q.puzzle['sequence'] as List).first);
      expect((f.w, f.h), (2, 2));
      expect(f.glyphs.length, 4);
    }
  });

  test('Medium analogy turn: quarter turns, never mirrored', () {
    AnalogyGenerator.seed(8);
    for (int i = 0; i < 100; i++) {
      final q = AnalogyGenerator.generate(level: Difficulty.medium, family: 'turn')!;
      final a = fig(q.puzzle['A']).copyWith(glyphs: {});
      final b = fig(q.puzzle['B']).copyWith(glyphs: {});
      final turns = [for (int t = 0; t < 4; t++) if (a.rot(t).key == b.key) t];
      expect(turns.length == 1 && (turns.single == 1 || turns.single == 3), isTrue,
          reason: 'B must be A turned a quarter, got $turns');
    }
  });

  test('Medium Geo and Mirror Shape mix in their lite exam items', () {
    final geo = medium('geo_completion');
    expect({for (final q in geo) q.type}, contains('geo_grid_cut'));
    for (final q in geo.where((q) => q.type == 'geo_grid_cut')) {
      expect(q.puzzle['answer_turn'], anyOf(0, 2));
    }
    expect({for (final q in medium('mirror_shape')) q.type}, contains('mirror_line_fig'));
  });

  test('Medium mirror clocks: on the hour or half past, mirror time correct', () {
    final clocks = medium('mirror_text', n: 300).where((q) => q.puzzle['is_clock'] == true).toList();
    expect(clocks, isNotEmpty, reason: 'Medium serves some clocks');
    for (final q in clocks) {
      final h = q.puzzle['clock_hour'] as int, m = q.puzzle['clock_minute'] as int;
      expect(m, anyOf(0, 30));
      final a = q.options[q.correctIndex];
      // Mirror: both hands reflected about the 12-6 line.
      final hourAngle = ((h % 12) * 30 + m / 2) % 360;
      final ah = (((a['clock_hour'] as int) % 12) * 30 + (a['clock_minute'] as int) / 2) % 360;
      expect(ah, closeTo((360 - hourAngle) % 360, 0.01));
      expect(((a['clock_minute'] as int) * 6) % 360, (360 - m * 6) % 360);
    }
  });

  test('Medium Punch Hole never folds twice', () {
    for (final q in medium('punch_hole')) {
      final folds = q.puzzle['folds'] as List?;
      if (folds != null) {
        expect(folds.length, 1);
      } else {
        expect(q.puzzle['fold_axis'], anyOf(0, 1), reason: 'classic single fold');
      }
    }
  });

  test('Medium Odd Man Out: no fill-only give-aways, no mirror or counting tricks', () {
    final types = {for (final q in medium('odd_man', n: 300)) q.type};
    expect(types.intersection({'odd_v0', 'odd_v4', 'odd_v7', 'odd_v8', 'odd_v9'}), isEmpty);
    expect(types, containsAll(['odd_v1', 'odd_v10', 'odd_man_mirror']));
  });

  test('Medium classic Embedded: near-misses are never mirror images', () {
    final qs = medium('embedded').where((q) => q.type == 'embedded_medium').toList();
    expect(qs, isNotEmpty);
    for (final q in qs) {
      for (final o in q.options) {
        for (final f in o['shapes'] as List) {
          expect((f as Map)['mirror'], isNot(true));
        }
      }
    }
  });

  test('Medium Embedded mixes in the lite exam item', () {
    expect({for (final q in medium('embedded')) q.type}, contains('embedded_line'));
  });

  test('Medium is described as a midpoint, not a mix', () {
    AppLocale.setLang('EN');
    expect(AppLocale.s('medium_desc'), 'Between Easy and Hard in every topic');
  });
}
