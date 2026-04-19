import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';

const _categories = [
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

Map<String, int> _initialWeights() =>
    {
      for (final c in _categories) c: 1,
    };

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

void main() {
  test('random mode weighting remains clamped over 50 answers', () {
    final rng = Random(13579);
    final weights = _initialWeights();
    final selectedCounts = <String, int>{for (final c in _categories) c: 0};
    final wrongCounts = <String, int>{for (final c in _categories) c: 0};

    for (int i = 0; i < 50; i++) {
      final category = _pickWeightedCategory(rng, weights);
      selectedCounts[category] = selectedCounts[category]! + 1;

      final answeredCorrectly = rng.nextBool();
      if (!answeredCorrectly) {
        wrongCounts[category] = wrongCounts[category]! + 1;
      }
      _updateWeight(weights, category, answeredCorrectly);
    }

    for (final weight in weights.values) {
      expect(weight, inInclusiveRange(1, 10));
    }

    expect(selectedCounts.values.where((v) => v > 0).length, greaterThan(1));
    expect(weights.values.any((w) => w > 1), isTrue);

    final highestWrong = wrongCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final lowestWrong = wrongCounts.entries.reduce(
      (a, b) => a.value <= b.value ? a : b,
    );
    expect(
      weights[highestWrong.key]!,
      greaterThanOrEqualTo(weights[lowestWrong.key]!),
    );
  });

  test('language cycle includes Hindi', () {
    expect(AppLocale.nextLang('EN'), 'MR');
    expect(AppLocale.nextLang('MR'), 'HI');
    expect(AppLocale.nextLang('HI'), 'EN');
    expect(AppLocale.langLabel('HI'), 'हि');
  });
}
