import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
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
    final bool trap = m['selective_mirror_trap'] ?? false;
    final int trapIdx = m['trap_char_index'] ?? -1;
    return 'txt|$ch|h:${m["mirror_h"]}|v:${m["mirror_v"]}|trap:$trap|trapIdx:$trapIdx';
  }
  // Exam-style line figures: the exact drawing key (same picture <=> same key).
  if (m['type'] == 'line_fig') return 'line|${LineFig.fromMap(m).key}';
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

  // Classic figures: the generator's exact appearance key, which accounts
  // for the symmetry of the outer shape AND of the inner shape / lines /
  // corner mark drawn inside it. The approximation below ignored the inner
  // parts, so e.g. a diamond at 90° vs 270° counted as a duplicate even
  // with a triangle inside pointing opposite ways.
  if (m.containsKey('shape') && !m.containsKey('type') && (m['missingCorner'] ?? 0) == 0) {
    return 'fig|${QuestionGenerator.debugOptionKey(m)}';
  }

  final int s = m['shape'] ?? 0;
  int rot = m['rotation'] ?? 0;
  bool mir = m['mirror'] ?? false;
  final bool trap = (m['selective_mirror_trap'] ?? false) && ((m['lines'] ?? 0) > 0 || (m['inner'] ?? 0) > 0);

  // Apply visual symmetry reductions to canonicalize visually identical states
  // Matches _shapeSymmetries (the exact key): a hexagon (vertex at 0°)
  // only repeats every half turn - a quarter turn swaps pointy-sides for
  // pointy-top - and a pentagon (vertex up) only under a flip, which the
  // painter applies after turning: flipped at turn r = unflipped at -r.
  if (s == 0 || s == 1 || s == 4) {
    rot = 0;
    mir = false;
  } else if (s == 3 || s == 6) {
    rot = rot % 2;
    mir = false;
  } else if (s == 5 && mir) {
    mir = false;
    rot = (4 - rot % 4) % 4;
  } else if (s == 2 && mir) {
    // Shape 2: Right-angle triangle. (mirror=true, rot) is visually identical to (mirror=false, 3-rot)
    mir = false;
    rot = 3 - rot;
  } else if (s == 7 && mir) {
    // Shape 7: Arrow. (mirror=true, rot) points LEFT/RIGHT/UP/DOWN identically to unmirrored counterparts:
    mir = false;
    if (rot == 0) {
      rot = 2;
    } else if (rot == 2) {
      rot = 0;
    }
  }

  return '$s,${m["filled"]},$rot,$mir,${m["dots"]},${m["inner"]},${m["lines"]},${m["missingCorner"]},$trap';
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
