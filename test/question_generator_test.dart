import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

String _canonical(dynamic value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((e) => '${e.key}:${_canonical(e.value)}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_canonical).join(',')}]';
  }
  return value.toString();
}

String _questionSignature(dynamic q) {
  return _canonical({
    'category': q.category,
    'type': q.type,
    'puzzle': q.puzzle,
    'options': q.options,
  });
}

String _optionSignature(Map<String, dynamic> option) => _canonical(option);

String _modeQuestionSignature(dynamic q) {
  final optionSigs =
  (q.options as List)
      .map((o) => _optionSignature(Map<String, dynamic>.from(o as Map)))
      .toList()
    ..sort();
  return _canonical({
    'category': q.category,
    'type': q.type,
    'puzzle': q.puzzle,
    'options': optionSigs,
  });
}

String _visibleFigureSignature(Map<String, dynamic> option) {
  final copy = Map<String, dynamic>.from(option);
  final shape = copy['shape'] ?? 0;
  if (shape == 0 || shape == 1 || shape == 4) {
    copy['rotation'] = 0;
  }
  if (shape == 3 || shape == 5) {
    copy['rotation'] = (copy['rotation'] ?? 0) % 2;
  }
  return _canonical(copy);
}

String _pickWeightedCategory(Random rng, Map<String, int> weights) {
  final total = weights.values.reduce((a, b) => a + b);
  var roll = rng.nextInt(total);
  for (final entry in weights.entries) {
    roll -= entry.value;
    if (roll < 0) return entry.key;
  }
  return weights.keys.first;
}

void _updateWeight(Map<String, int> weights, String category, bool correct) {
  if (correct) {
    weights[category] = max(1, (weights[category] ?? 1) - 1);
  } else {
    weights[category] = min(10, (weights[category] ?? 1) + 2);
  }
}

void _expectValidQuestion(
  dynamic q,
  String label, {
  bool allowDuplicateOptions = false,
}) {
  expect(q.puzzle.isNotEmpty, isTrue, reason: 'puzzle empty for $label');
  expect(q.options.length, 4, reason: 'options length invalid for $label');
  expect(q.correctIndex, inInclusiveRange(0, 3));

  final optionSignatures = q.options.map((o) {
    expect(o, isA<Map<String, dynamic>>());
    expect(o.isNotEmpty, isTrue);
    return _optionSignature(Map<String, dynamic>.from(o as Map));
  }).toSet();

  if (!allowDuplicateOptions) {
    expect(optionSignatures.length, 4, reason: 'duplicate options for $label');
  }
}

void main() {
  const categories = [
    'pattern',
    'analogy',
    'odd_man',
    'mirror_shape',
    'figure_match',
    'figure_series',
    'geo_completion',
    'mirror_text',
    'punch_hole',
    'embedded',
  ];

  group('linear mode repeatness', () {
    for (final category in categories) {
      test('no repeated questions or options in $category', () {
        QuestionGenerator.resetSession();
        final seenQuestions = <String>{};

        for (int i = 0; i < 15; i++) {
          final q = QuestionGenerator.generate(category);
          expect(q.category, category);
          _expectValidQuestion(
            q,
            'linear:$category#$i',
            allowDuplicateOptions: category == 'odd_man',
          );

          final sig = _questionSignature(q);
          expect(
            seenQuestions.add(sig),
            isTrue,
            reason: 'repeated question in linear mode for $category at $i',
          );
        }
      });
    }
  });

  group('random mode repeatness', () {
    test('covers all sections without repeating questions', () {
      QuestionGenerator.resetSession();
      final seenQuestions = <String>{};
      final seenCategories = <String>{};
      final rng = Random(42);

      for (int round = 0; round < 8; round++) {
        final shuffled = [...categories]..shuffle(rng);
        for (final category in shuffled) {
          final q = QuestionGenerator.generate(category);
          expect(q.category, category);
          seenCategories.add(category);
          _expectValidQuestion(
            q,
            'random:$category#$round',
            allowDuplicateOptions: category == 'odd_man',
          );

          final sig = _questionSignature(q);
          expect(
            seenQuestions.add(sig),
            isTrue,
            reason:
                'repeated question in random mode for $category at round $round',
          );
        }
      }

      expect(seenCategories, containsAll(categories));
    });
  });

  test('series questions keep at least 3 sequence items', () {
    QuestionGenerator.resetSession();
    for (int i = 0; i < 50; i++) {
      final q = QuestionGenerator.generate('figure_series');
      final seq = q.puzzle['sequence'] as List<dynamic>;
      expect(seq.length >= 3, isTrue);

      final visible = seq
          .map((e) =>
          _visibleFigureSignature(Map<String, dynamic>.from(e as Map)))
          .toSet();
      expect(
        visible.length,
        greaterThan(1),
        reason: 'figure series is visually flat for ${q.type}',
      );
    }
  });

  test('pattern inner-shape matrix keeps valid inner shape codes', () {
    QuestionGenerator.resetSession();
    for (int i = 0; i < 120; i++) {
      final q = QuestionGenerator.generate('pattern');
      if (q.type != 'matrix_inner_shape') continue;

      final cells = (q.puzzle['cells'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['empty'] != true)
          .toList();

      for (final c in cells) {
        final inner = c['inner'] as int? ?? 0;
        if (inner > 0) {
          expect(inner, inInclusiveRange(1, 8));
        }
      }
    }
  });

  test('series_inner follows a consistent next-step answer', () {
    QuestionGenerator.resetSession();
    for (int i = 0; i < 120; i++) {
      final q = QuestionGenerator.generate('figure_series');
      if (q.type != 'series_inner') continue;

      final seq = (q.puzzle['sequence'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final answer = Map<String, dynamic>.from(q.options[q.correctIndex]);

      final seqFill = seq.first['filled'];
      final seqInners = seq.map((e) => e['inner']).toSet();

      expect(answer['filled'], seqFill,
          reason: 'series_inner answer must keep same fill as sequence');
      expect(seqInners.contains(answer['inner']), isFalse,
          reason:
          'series_inner answer inner should advance beyond shown sequence');
    }
  });

  test('analogy rule 7 applies same transform to C as A', () {
    QuestionGenerator.resetSession();
    for (int i = 0; i < 300; i++) {
      final q = QuestionGenerator.generate('analogy');
      if (q.type != 'analogy_r7') continue;

      final a = Map<String, dynamic>.from(q.puzzle['A'] as Map);
      final b = Map<String, dynamic>.from(q.puzzle['B'] as Map);
      final c = Map<String, dynamic>.from(q.puzzle['C'] as Map);
      final d = Map<String, dynamic>.from(q.options[q.correctIndex]);

      final deltaAB = ((b['rotation'] as int) - (a['rotation'] as int)) % 4;
      final deltaCD = ((d['rotation'] as int) - (c['rotation'] as int)) % 4;

      expect(deltaAB, 2);
      expect(deltaCD, 2);
      expect(b['filled'], a['filled']);
      expect(d['filled'], c['filled']);
      expect(b['dots'], a['dots']);
      expect(d['dots'], c['dots']);
      expect(b['inner'], a['inner']);
      expect(d['inner'], c['inner']);
    }
  });

  test('geo completion has one complement answer and good variety', () {
    QuestionGenerator.resetSession();
    final seenSignatures = <String>{};
    final seenShownPieces = <int>{};

    for (int i = 0; i < 120; i++) {
      final q = QuestionGenerator.generate('geo_completion');
      final piece = Map<String, dynamic>.from(q.puzzle['piece'] as Map);
      final shape = piece['shape'] as int;
      final cut = piece['cut'] as int;
      final shownPiece = piece['piece'] as int;
      final targetPiece = 1 - shownPiece;

      seenShownPieces.add(shownPiece);
      seenSignatures.add('$shape|$cut|$shownPiece');

      int complementMatches = 0;
      for (final option in q.options) {
        expect(option['type'], 'geo_piece');
        if (option['shape'] == shape &&
            option['cut'] == cut &&
            option['piece'] == targetPiece) {
          complementMatches++;
        }
      }
      expect(complementMatches, 1);
    }

    // Should expose both puzzle sides and enough unique combinations.
    expect(seenShownPieces.length, 2);
    expect(seenSignatures.length, greaterThan(10));
  });

  test('mirror shape options are unique', () {
    for (int i = 0; i < 80; i++) {
      final q = QuestionGenerator.generate('mirror_shape');
      final target = Map<String, dynamic>.from(q.puzzle['target'] as Map);
      final keys = q.options
          .map(
            (o) =>
            '${o['shape']}|${o['rotation']}|${o['filled']}|${o['mirror']}|${o['dots']}',
          )
          .toSet();
      expect(keys.length, 4);
      for (final o in q.options) {
        expect(o['shape'], target['shape']);
      }
    }
  });

  test('mirror text options are unique', () {
    for (int i = 0; i < 80; i++) {
      final q = QuestionGenerator.generate('mirror_text');
      final puzzle = Map<String, dynamic>.from(q.puzzle);
      final keys = q.options
          .map(
            (o) => o['is_clock'] == true
                ? 'clk|${o['clock_hour']}|${o['clock_minute']}|${o['mirror_h']}|${o['mirror_v']}'
                : '${o['content']}|${o['mirror_h']}|${o['mirror_v']}',
          )
          .toSet();
      expect(keys.length, 4);
      for (final o in q.options) {
        if (puzzle['is_clock'] == true) {
          expect(o['clock_hour'], puzzle['clock_hour']);
          expect(o['clock_minute'], puzzle['clock_minute']);
        } else {
          expect(o['content'], puzzle['content']);
        }
      }
    }
  });

  group('session mode repeatness stress', () {
    test(
      'topic-wise mode does not repeat questions within same topic session',
          () {
        for (final category in categories) {
          QuestionGenerator.resetSession();
          final seen = <String>{};
          for (int i = 0; i < 30; i++) {
            final q = QuestionGenerator.generate(category);
            _expectValidQuestion(
              q,
              'topic:$category#$i',
              allowDuplicateOptions: category == 'odd_man',
            );
            expect(
              seen.add(_modeQuestionSignature(q)),
              isTrue,
              reason: 'repeated topic-wise question for $category at $i',
            );
          }
        }
      },
    );

    test(
      'random mode avoids repeated questions with dynamic bias over 100 picks',
          () {
        QuestionGenerator.resetSession();
        final rng = Random(20260420);
        final weights = {for (final c in categories) c: 1};
        final seen = <String>{};

        for (int i = 0; i < 100; i++) {
          final category = _pickWeightedCategory(rng, weights);
          final q = QuestionGenerator.generate(category);
          _expectValidQuestion(
            q,
            'random-flow:$category#$i',
            allowDuplicateOptions: category == 'odd_man',
          );
          expect(
            seen.add(_modeQuestionSignature(q)),
            isTrue,
            reason: 'repeated random-flow question at $i for $category',
          );
          _updateWeight(weights, category, rng.nextBool());
        }
      },
    );

    test(
      'linear mode category cycle does not repeat questions in 100 picks',
          () {
        QuestionGenerator.resetSession();
        final seen = <String>{};
        for (int i = 0; i < 100; i++) {
          final category = categories[i % categories.length];
          final q = QuestionGenerator.generate(category);
          _expectValidQuestion(
            q,
            'linear-flow:$category#$i',
            allowDuplicateOptions: category == 'odd_man',
          );
          expect(
            seen.add(_modeQuestionSignature(q)),
            isTrue,
            reason: 'repeated linear-flow question at $i for $category',
          );
        }
      },
    );
  });
}
