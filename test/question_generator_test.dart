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
                '${o['shape']}|${o['rotation']}|${o['filled']}|${o['mirror']}',
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
}
