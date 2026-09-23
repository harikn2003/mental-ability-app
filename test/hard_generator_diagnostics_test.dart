// Diagnostic test module for HardQuestionGenerator.
//
// This is NOT a pass/fail correctness suite in the usual sense - "is this
// specific question logically right" needs a human (or an LLM looking at
// the printed data) to judge, the same way the screenshot rounds worked.
// What this DOES automate is everything that doesn't need a human eye:
//
//   1. Crash-freedom: generate a few hundred questions per category and
//      make sure none of them throw.
//   2. Structural sanity: exactly 4 options, correctIndex in range, puzzle
//      non-empty.
//   3. Option distinctness: re-checks generate()'s own dedup guarantee as
//      an external regression trip-wire (see debugOptionVisibleKeys).
//   4. Tiny-feature warnings: flags any feature whose effective render
//      size falls under a threshold - the exact shape of every "too small
//      to see" bug found by hand this session (see debugTinyFeatureWarnings).
//      pattern/odd_man/figure_match only - figure_series/analogy use a
//      different schema this doesn't understand yet.
//   5. Row/column giveaway: pattern-only, re-derives the "two other cells
//      in the missing cell's row or column are identical" condition
//      directly from the returned puzzle data (see debugHasRowColGiveaway).
//   6. Near-duplicate option pairs: options that aren't literal duplicates
//      (#3 already covers that) but are too close to tell apart once drawn -
//      the "looks like a duplicate in a screenshot, isn't one in the data"
//      case (see debugOptionPairDiffs; same judgment generate() applies live).
//   7. Regression checks (hard-fail): hand-built symmetry/visibility cases
//      for the option comparison, and figure_match's "exactly one option is
//      a rotation of the target" (no second correct answer).
//
// HOW TO RUN
//   flutter test test/hard_generator_diagnostics_test.dart
//
// HOW TO USE THE OUTPUT
//   Everything interesting is printed via `print()`, grouped per category,
//   ending in a summary block. Copy the whole test output (not just
//   PASS/FAIL) and paste it back - the printed samples are what actually
//   need a second pair of eyes, not the assert results.
//
// TUNING
//   - runsPerCategory: how many questions to generate per category.
//     Bumped down from a "real" fuzz count (thousands) to keep a single
//     `flutter test` run fast; raise it locally if you want deeper
//     coverage on a specific category (e.g. after a fix, temporarily set
//     it high just for 'pattern' by editing the categories map below).
//   - minFeatureFraction: passed straight to debugTinyFeatureWarnings.
//     0.12 was picked as "probably too small to read at a glance", not
//     measured against a real device - treat the printed warnings as
//     leads to visually check, not confirmed bugs.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/hard_question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const int runsPerCategory = 300;
const double minFeatureFraction = 0.12;

const List<String> categories = [
  'odd_man',
  'figure_match',
  'pattern',
  'figure_series',
  'analogy',
];

Map<String, dynamic> _feat(String shape, double w, double h, int rot,
        {double cx = 0.5, double cy = 0.5, double scale = 1.0, String fill = 'white', bool? mirror}) =>
    {'shape': shape, 'w': w, 'h': h, 'rot': rot, 'cx': cx, 'cy': cy, 'scale': scale, 'fill': fill, 'mirror': ?mirror};

Map<String, dynamic> _cellOf(List<List<Map<String, dynamic>>> layers) => {
      'type': 'sandia_cell',
      'grid_box': true,
      'layers': [for (final l in layers) {'features': l}],
    };

ReasoningQuestion _pair(Map<String, dynamic> a, Map<String, dynamic> b) =>
    ReasoningQuestion(category: 'test', type: 'test', puzzle: {}, options: [a, b], correctIndex: 0);

bool _looksIdentical(Map<String, dynamic> a, Map<String, dynamic> b) {
  final keys = HardQuestionGenerator.debugOptionVisibleKeys(_pair(a, b));
  return keys[0] == keys[1];
}

bool _flaggedAsNearDuplicate(Map<String, dynamic> a, Map<String, dynamic> b) =>
    HardQuestionGenerator.debugOptionPairDiffs(_pair(a, b)).isNotEmpty;

/// The whole figure turned 90 degrees clockwise about the cell centre - the
/// same transform SandiaPainter applies for rot +90, including each
/// feature's own position.
Map<String, dynamic> _rotateCell90(Map<String, dynamic> cell) => {
      ...cell,
      'layers': [
        for (final l in cell['layers'] as List)
          {
            'features': [
              for (final f in (l as Map)['features'] as List)
                {
                  ...(f as Map<String, dynamic>),
                  'rot': ((f['rot'] as num).toInt() + 90) % 360,
                  'cx': 0.5 - ((f['cy'] as num) - 0.5),
                  'cy': 0.5 + ((f['cx'] as num) - 0.5),
                },
            ],
          },
      ],
    };

void main() {
  // Hand-built cases for the symmetry-aware option comparison. Each one is
  // a specific way two different data maps paint the same pixels, found by
  // the visual test - kept here so a future change can't quietly undo it.
  group('option comparison regressions', () {
    test('rotate 90 == swap w/h on centrally symmetric shapes', () {
      for (final s in ['rectangle', 'ellipse', 'diamond']) {
        expect(_looksIdentical(_cellOf([[_feat(s, 0.75, 0.5, 90)]]), _cellOf([[_feat(s, 0.5, 0.75, 0)]])), isTrue, reason: s);
      }
      // ...but not on a shape without that symmetry.
      expect(_looksIdentical(_cellOf([[_feat('triangle', 0.75, 0.5, 90)]]), _cellOf([[_feat('triangle', 0.5, 0.75, 0)]])), isFalse);
    });

    test('diamond / rectangle look identical 180 degrees apart', () {
      expect(_looksIdentical(_cellOf([[_feat('diamond', 0.79, 0.26, 90)]]), _cellOf([[_feat('diamond', 0.79, 0.26, 270)]])), isTrue);
      expect(_looksIdentical(_cellOf([[_feat('trapezoid', 0.79, 0.26, 90)]]), _cellOf([[_feat('trapezoid', 0.79, 0.26, 270)]])), isFalse);
    });

    test('scale folds into size, mirror folds into rotation', () {
      expect(_looksIdentical(_cellOf([[_feat('tee', 0.5, 0.5, 0, scale: 0.5)]]), _cellOf([[_feat('tee', 0.25, 0.25, 0)]])), isTrue);
      expect(_looksIdentical(_cellOf([[_feat('triangle', 0.5, 0.75, 90, mirror: true)]]), _cellOf([[_feat('triangle', 0.5, 0.75, 270)]])), isTrue);
    });

    test('legacy thick cross (surface 9) is 90-degree symmetric', () {
      Map<String, dynamic> legacy(int rotation) => {
            'type': 'sandia_cell',
            'layers': [
              {'surface': 9, 'fill': 1, 'scale': 2.2, 'rotation': rotation, 'grid_box': true},
            ],
          };
      expect(_looksIdentical(legacy(2), legacy(3)), isTrue);
    });

    test('turning only a tiny feature is flagged as too subtle', () {
      // figure_match: two distractors differing only in which way the ~10dp
      // corner triangle marker points.
      Map<String, dynamic> marker(int rot) => _cellOf([
            [_feat('ellipse', 0.46, 0.69, 90), _feat('triangle', 0.16, 0.16, rot, cx: 0.13, cy: 0.87, fill: 'black')],
          ]);
      expect(_flaggedAsNearDuplicate(marker(90), marker(270)), isTrue);
      // A large shape turning is plainly visible.
      expect(_flaggedAsNearDuplicate(_cellOf([[_feat('triangle', 0.5, 0.5, 90)]]), _cellOf([[_feat('triangle', 0.5, 0.5, 270)]])), isFalse);
    });

    test('swapping between similar outlines on a small white shape is flagged as too subtle', () {
      // pattern: trapezoid vs triangle, outline-only, ~9x18dp.
      Map<String, dynamic> small(String shape) => _cellOf([
            [_feat(shape, 0.25, 0.5, 0, scale: 0.55)],
          ]);
      expect(_flaggedAsNearDuplicate(small('trapezoid'), small('triangle')), isTrue);
      // The same swap at full size is plainly visible.
      Map<String, dynamic> big(String shape) => _cellOf([
            [_feat(shape, 0.75, 0.75, 0)],
          ]);
      expect(_flaggedAsNearDuplicate(big('trapezoid'), big('triangle')), isFalse);
    });

    test('fill change hidden under a semi-transparent layer is flagged as too subtle', () {
      // Black vs grey10 triangle entirely under a grey10 diamond: composites
      // to ~41 vs ~63 out of 255 (the pattern-run finding that motivated this).
      Map<String, dynamic> covered(String fill) => _cellOf([
            [_feat('triangle', 0.5, 0.75, 0, scale: 0.4, fill: fill)],
            [_feat('diamond', 0.9, 0.9, 0, fill: 'grey10')],
          ]);
      expect(_flaggedAsNearDuplicate(covered('black'), covered('grey10')), isTrue);
      // The same change uncovered is plainly visible.
      Map<String, dynamic> open(String fill) => _cellOf([
            [_feat('triangle', 0.5, 0.75, 0, fill: fill)],
          ]);
      expect(_flaggedAsNearDuplicate(open('black'), open('grey10')), isFalse);
      // white vs grey75 is ~26/255 apart even uncovered.
      expect(_flaggedAsNearDuplicate(open('white'), open('grey75')), isTrue);
    });
  });

  test('[figure_match] exactly one option is a rotation of the target', () {
    // Guards against a distractor that is ALSO a valid answer (e.g. a mirror
    // image that happens to equal some rotation) - a question with two
    // correct answers, which pairwise option checks can't see.
    HardQuestionGenerator.seed(42);
    HardQuestionGenerator.resetSession();
    final failures = <String>[];
    for (int i = 0; i < runsPerCategory; i++) {
      final q = HardQuestionGenerator.generate('figure_match');
      final rotations = <Map<String, dynamic>>[q.puzzle['target'] as Map<String, dynamic>];
      for (int k = 1; k < 4; k++) {
        rotations.add(_rotateCell90(rotations.last));
      }
      final rotationKeys = HardQuestionGenerator.debugOptionVisibleKeys(
          ReasoningQuestion(category: 'test', type: 'test', puzzle: {}, options: rotations, correctIndex: 0)).toSet();
      final optionKeys = HardQuestionGenerator.debugOptionVisibleKeys(q);
      final matching = [for (int o = 0; o < optionKeys.length; o++) if (rotationKeys.contains(optionKeys[o])) o];
      if (matching.length != 1 || matching.single != q.correctIndex) {
        failures.add('run $i: options matching a rotation of the target = $matching, correctIndex = ${q.correctIndex}');
      }
    }
    expect(failures, isEmpty, reason: failures.take(5).join('\n'));
  });

  setUp(() {
    // Fixed seed -> reproducible runs. Re-run with a different seed (or
    // remove this line to use wall-clock randomness) if you want to sample
    // a different slice than last time.
    HardQuestionGenerator.seed(42);
    HardQuestionGenerator.resetSession();
  });

  for (final category in categories) {
    group('[$category]', () {
      int crashes = 0;
      int structuralFailures = 0;
      int duplicateOptionSets = 0;
      int tinyFeatureQuestions = 0;
      int giveawayQuestions = 0;
      int nearDuplicateQuestions = 0;
      final tinyFeatureSamples = <String>[];
      final giveawaySamples = <String>[];
      final crashSamples = <String>[];
      final nearDuplicateSamples = <String>[];

      test('generate $runsPerCategory questions and record findings', () {
        for (int i = 0; i < runsPerCategory; i++) {
          ReasoningQuestion q;
          try {
            q = HardQuestionGenerator.generate(category);
          } catch (e, st) {
            crashes++;
            if (crashSamples.length < 5) {
              crashSamples.add('run $i: $e\n${st.toString().split('\n').take(4).join('\n')}');
            }
            continue;
          }

          // --- structural sanity ---
          if (q.options.length != 4 || q.correctIndex < 0 || q.correctIndex >= q.options.length || q.puzzle.isEmpty) {
            structuralFailures++;
          }

          // --- option distinctness (regression trip-wire on generate()'s own guarantee) ---
          final keys = HardQuestionGenerator.debugOptionVisibleKeys(q);
          if (keys.toSet().length < keys.length) {
            duplicateOptionSets++;
          }

          // --- tiny-feature scan (pattern/odd_man/figure_match schema only) ---
          final tiny = HardQuestionGenerator.debugTinyFeatureWarnings(q, minFraction: minFeatureFraction);
          if (tiny.isNotEmpty) {
            tinyFeatureQuestions++;
            if (tinyFeatureSamples.length < 8) {
              tinyFeatureSamples.add('run $i: ${tiny.join(' | ')}');
            }
          }

          // --- row/column giveaway (pattern only) ---
          if (HardQuestionGenerator.debugHasRowColGiveaway(q)) {
            giveawayQuestions++;
            if (giveawaySamples.length < 5) {
              giveawaySamples.add('run $i');
            }
          }

          // --- near-duplicate option pairs: not literal duplicates (that's
          // covered above), but pairs differing by only 1-2 attributes,
          // which is the "looks the same in a screenshot even though the
          // data technically differs" failure mode - can't be judged from
          // a photo, so print the exact numeric diffs instead.
          final pairDiffs = HardQuestionGenerator.debugOptionPairDiffs(q);
          if (pairDiffs.isNotEmpty) {
            nearDuplicateQuestions++;
            if (nearDuplicateSamples.length < 8) {
              nearDuplicateSamples.add('run $i: ${pairDiffs.join(' || ')}');
            }
          }
        }

        // ---- report ----
        print('');
        print('=== [$category] diagnostic summary ($runsPerCategory runs) ===');
        print('crashes: $crashes / $runsPerCategory');
        if (crashSamples.isNotEmpty) {
          print('  sample crashes:');
          for (final s in crashSamples) {
            print('    - $s');
          }
        }
        print('structural failures (bad option count / correctIndex / empty puzzle): $structuralFailures / $runsPerCategory');
        print('duplicate option sets slipping past generate()\'s own dedup: $duplicateOptionSets / $runsPerCategory');
        print('questions with a tiny (<$minFeatureFraction fraction) feature: $tinyFeatureQuestions / $runsPerCategory');
        if (tinyFeatureSamples.isNotEmpty) {
          print('  sample tiny-feature findings:');
          for (final s in tinyFeatureSamples) {
            print('    - $s');
          }
        }
        if (category == 'pattern') {
          print('questions with a row/column giveaway slipping past the generation-time guard: $giveawayQuestions / $runsPerCategory');
          if (giveawaySamples.isNotEmpty) {
            print('  sample giveaway runs: ${giveawaySamples.join(', ')}');
          }
        }
        print('option pairs whose only differences are individually small enough to miss (possibly too subtle to see): $nearDuplicateQuestions / $runsPerCategory');
        if (nearDuplicateSamples.isNotEmpty) {
          print('  sample near-duplicate findings:');
          for (final s in nearDuplicateSamples) {
            print('    - $s');
          }
        }
        print('=== end [$category] ===');
        print('');

        // Hard-fail only on things that are unambiguously bugs regardless
        // of visual judgment: crashes, structural violations, and literal
        // duplicate options (which generate() itself is supposed to
        // prevent - if this trips, generate()'s retry loop has a real
        // regression, not a subjective call). Tiny-feature and giveaway
        // counts are printed as leads, not asserted on, since "how tiny is
        // too tiny" and "is this specific giveaway actually severe" are
        // exactly the judgment calls this module exists to surface for
        // review rather than silently auto-decide.
        expect(crashes, 0, reason: 'generator threw on at least one run - see sample crashes above');
        expect(structuralFailures, 0, reason: 'generator returned a structurally invalid question - see summary above');
        expect(duplicateOptionSets, 0,
            reason: "generate()'s own option-dedup guarantee was violated - this is a real regression, not a false positive");
      });
    });
  }
}