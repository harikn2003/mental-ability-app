import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

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

Map<String, int> _initialWeights({
  int boostedIndex = 0,
  int boostedWeight = 10,
}) {
  return {
    for (var i = 0; i < _categories.length; i++)
      _categories[i]: i == boostedIndex ? boostedWeight : 1,
  };
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

void main() {
  test('weighted random-mode picker favors higher weights', () {
    final weights = _initialWeights(boostedIndex: 0, boostedWeight: 10);
    final rng = Random(20260405);
    final counts = <String, int>{for (final c in _categories) c: 0};

    for (int i = 0; i < 3000; i++) {
      final category = _pickWeightedCategory(rng, weights);
      counts[category] = counts[category]! + 1;
    }

    final boosted = counts[_categories[0]]!;
    final weakestCounts = _categories.skip(1).map((c) => counts[c]!).toList();
    final strongestOfWeak = weakestCounts.reduce(max);

    expect(boosted, greaterThan(strongestOfWeak));
    expect(boosted / 3000, greaterThan(0.30));
  });

  test(
    '50-question random-mode bias update stays within clamp and shifts weights',
    () {
      final rng = Random(424242);
      final weights = {for (final c in _categories) c: 1};
      final selectedCounts = <String, int>{for (final c in _categories) c: 0};
      final wrongCounts = <String, int>{for (final c in _categories) c: 0};

      for (int i = 0; i < 50; i++) {
        final category = _pickWeightedCategory(rng, weights);
        selectedCounts[category] = selectedCounts[category]! + 1;

        // Randomly simulate correct/wrong answers as requested.
        final answeredCorrectly = rng.nextBool();
        if (!answeredCorrectly) {
          wrongCounts[category] = wrongCounts[category]! + 1;
        }
        _updateWeight(weights, category, answeredCorrectly);
      }

      // Clamp safety: every category must stay in the 1..10 range.
      for (final entry in weights.entries) {
        expect(entry.value, inInclusiveRange(1, 10));
      }

      // Some categories should move away from the default weight after 50 rounds.
      expect(weights.values.any((w) => w > 1), isTrue);

      // After the 50-question run, categories that were answered wrong more often
      // should tend to have higher weights than categories answered wrong less often.
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

      // Verify the final weights actually influence future random-mode picks.
      final postCounts = <String, int>{for (final c in _categories) c: 0};
      for (int i = 0; i < 2000; i++) {
        final category = _pickWeightedCategory(rng, weights);
        postCounts[category] = postCounts[category]! + 1;
      }

      final maxWeight = weights.values.reduce(max);
      final maxWeightCategories = weights.entries
          .where((e) => e.value == maxWeight)
          .map((e) => e.key)
          .toList();
      final maxWeightSelected = maxWeightCategories
          .map((c) => postCounts[c]!)
          .reduce(max);
      final strongestOfLowWeight = weights.entries
          .where((e) => e.value == 1)
          .map((e) => postCounts[e.key]!)
          .fold<int>(0, max);

      expect(maxWeightSelected, greaterThan(strongestOfLowWeight));
    },
  );
}
