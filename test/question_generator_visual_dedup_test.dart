import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

// Re-implement the generator's visibleKey logic for test verification.
String visibleKey(Map<String, dynamic> m) {
  // Punch hole
  if (m.containsKey('holes') && m.containsKey('unfolded')) {
    final holes =
        (m['holes'] as List)
            .map(
              (h) =>
                  '(${(h["x"] as num).toStringAsFixed(2)},${(h["y"] as num).toStringAsFixed(2)})',
            )
            .toList()
          ..sort();
    return 'punch|ax:${m["fold_axis"]}|holes:${holes.join("-")}';
  }
  // Mirror text / clock
  if (m.containsKey('mirror_h') || m.containsKey('is_clock')) {
    final ch = m['content'] ?? 'clk:${m["clock_hour"]}:${m["clock_minute"]}';
    return 'txt|$ch|h:${m["mirror_h"]}|v:${m["mirror_v"]}';
  }
  // Geo cell
  if (m['type'] == 'geo_cell') {
    return 'geocell|f:${m["filled"]}|mk:${m["mark"] ?? "none"}';
  }
  if (m['type'] == 'geo_piece') {
    return 'geopiece|s:${m["shape"]}|c:${m["cut"]}|p:${m["piece"]}';
  }
  // Embedded
  if (m['type'] == 'embedded_option') {
    final shapes = (m['shapes'] as List)
        .map((s) => '${s["shape"]}-${s["filled"]}-${s["rotation"] ?? 0}')
        .join('+');
    return 'emb|$shapes|off:${m["offset"]}';
  }

  final int s = m['shape'] ?? 0;
  int rot = m['rotation'] ?? 0;
  bool mir = m['mirror'] ?? false;
  if (s == 0 || s == 1 || s == 4 || s == 6) {
    rot = 0;
    mir = false;
  }
  if (s == 3 || s == 5) rot = rot % 2;
  return '$s,${m["filled"]},$rot,$mir,${m["dots"]},${m["inner"]},${m["lines"]},${m["missingCorner"]}';
}

void main() {
  test('question generator: 5k questions produce 4 visually distinct options', () {
    // Make deterministic
    QuestionGenerator.seed(42);
    QuestionGenerator.resetSession();

    // Skip 'odd_man' because that category intentionally contains three
    // identical majority options (odd-one-out) and therefore will fail a
    // strict uniqueness check.
    final categories = [
      'figure_match',
      'pattern',
      'figure_series',
      'analogy',
      'geo_completion',
      'mirror_shape',
      'mirror_text',
      'punch_hole',
      'embedded',
    ];

    final failures = <String>[];
    final perCategoryFailures = <String, int>{};

    const total = 5000;
    for (int i = 0; i < total; i++) {
      final cat = categories[i % categories.length];
      final q = QuestionGenerator.generate(cat);
      final keys = q.options
          .map((o) => visibleKey(Map<String, dynamic>.from(o)))
          .toList();
      final uniq = keys.toSet();
      if (uniq.length != 4) {
        final msg =
            'Failure #$i category=$cat type=${q.type} keys=$keys options=${q.options}';
        failures.add(msg);
        perCategoryFailures[cat] = (perCategoryFailures[cat] ?? 0) + 1;
        // stop early to keep test readable
        break;
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'Found visually-duplicate options: ${failures.isNotEmpty ? failures.first : ''}',
    );
  });
}
