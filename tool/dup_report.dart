import 'dart:convert';
import 'dart:io';

import 'package:mental_ability_app/engine/question_generator.dart';

// Re-implement visibleKey from the unit test to match visual signature logic
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

void usageAndExit() {
  print(
    '''Usage: dart run tool/dup_report.dart --n <per-category-count> [--seed <int>] [--out <path>] [--categories <comma-separated>] [--format json|csv]

Example:
  dart run tool/dup_report.dart --n 500 --seed 42 --out dup_report_500.json
''',
  );
  exit(1);
}

void main(List<String> args) async {
  if (args.isEmpty) usageAndExit();

  int n = 0;
  int seed = 42;
  String out = 'dup_report.json';
  String format = 'json';
  List<String>? categories;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--n' && i + 1 < args.length) {
      n = int.tryParse(args[++i]) ?? 0;
    } else if (a == '--seed' && i + 1 < args.length) {
      seed = int.tryParse(args[++i]) ?? seed;
    } else if (a == '--out' && i + 1 < args.length) {
      out = args[++i];
    } else if (a == '--format' && i + 1 < args.length) {
      format = args[++i];
    } else if (a == '--categories' && i + 1 < args.length) {
      categories = args[++i]
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }

  if (n <= 0) usageAndExit();

  categories ??= [
    'figure_match',
    'pattern',
    'figure_series',
    'analogy',
    'geo_completion',
    'mirror_shape',
    'mirror_text',
    'punch_hole',
    'embedded',
    // Note: 'odd_man' intentionally contains three identical majority
    // options and therefore will always appear as a duplicate under the
    // strict 4-unique-options check. It is omitted by default from reports.
  ];

  print('Running duplicate-report: n=$n seed=$seed out=$out format=$format');

  QuestionGenerator.seed(seed);
  QuestionGenerator.resetSession();
  // Enable generator duplicate logging so any collisions are emitted to stdout
  // (useful when running on a device or collecting terminal logs).
  QuestionGenerator.debugDuplicateLogging = true;

  final results = <String, dynamic>{};

  for (final cat in categories) {
    final generated = <Map<String, dynamic>>[];
    int failures = 0;
    final examples = <Map<String, dynamic>>[];

    for (var i = 0; i < n; i++) {
      final q = QuestionGenerator.generate(cat);
      final options = q.options
          .map((o) => Map<String, dynamic>.from(o))
          .toList();
      final keys = options.map((o) => visibleKey(o)).toList();
      final uniq = keys.toSet();
      if (uniq.length != 4) {
        failures++;
        if (examples.length < 5) {
          final dupKeys = <String>[];
          final counts = <String, int>{};
          for (var k in keys) counts[k] = (counts[k] ?? 0) + 1;
          for (var e in counts.entries) if (e.value > 1) dupKeys.add(e.key);
          examples.add({
            'index': i,
            'type': q.type,
            'keys': keys,
            'duplicate_keys': dupKeys,
            'correctIndex': q.correctIndex,
            'options': options,
          });
        }
      }
      // keep a tiny sample for manual inspection
      if (i < 3) generated.add({'index': i, 'type': q.type, 'keys': keys});
    }

    results[cat] = {
      'generated': n,
      'failures': failures,
      'duplicate_rate': failures / n,
      'examples': examples,
      'sample_head': generated,
    };
    print(
      '$cat: generated=$n failures=$failures duplicate_rate=${(failures / n).toStringAsFixed(4)}',
    );
  }

  final outObj = {
    'metadata': {
      'seed': seed,
      'run_time': DateTime.now().toIso8601String(),
      'n': n,
      'categories': categories,
    },
    'results': results,
  };

  if (format == 'json') {
    final f = File(out);
    await f.writeAsString(JsonEncoder.withIndent('  ').convert(outObj));
    print('Wrote $out');
  } else if (format == 'csv') {
    final f = File(out);
    final sb = StringBuffer();
    sb.writeln('category,generated,failures,duplicate_rate,example_count');
    for (final e in results.entries) {
      final r = e.value as Map<String, dynamic>;
      sb.writeln(
        '${e.key},${r['generated']},${r['failures']},${r['duplicate_rate']},${(r['examples'] as List).length}',
      );
    }
    await f.writeAsString(sb.toString());
    print('Wrote $out');
  } else {
    print('Unknown format: $format');
  }
}
