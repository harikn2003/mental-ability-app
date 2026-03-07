import 'dart:math';

class BiasEngine {
  Map<String, int> categoryWeights = {};

  void initialize(List<String> categories) {
    for (var cat in categories) {
      categoryWeights[cat] = 1;
    }
  }

  void registerIncorrect(String category) {
    categoryWeights[category] = (categoryWeights[category] ?? 1) + 1;
  }

  String pickCategory() {
    int totalWeight = categoryWeights.values.reduce((a, b) => a + b);

    int randomPoint = Random().nextInt(totalWeight);
    int cumulative = 0;

    for (var entry in categoryWeights.entries) {
      cumulative += entry.value;
      if (randomPoint < cumulative) {
        return entry.key;
      }
    }

    return categoryWeights.keys.first;
  }
}
