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
//   - RUNS_PER_CATEGORY: how many questions to generate per category.
//     Bumped down from a "real" fuzz count (thousands) to keep a single
//     `flutter test` run fast; raise it locally if you want deeper
//     coverage on a specific category (e.g. after a fix, temporarily set
//     it high just for 'pattern' by editing the categories map below).
//   - MIN_FEATURE_FRACTION: passed straight to debugTinyFeatureWarnings.
//     0.12 was picked as "probably too small to read at a glance", not
//     measured against a real device - treat the printed warnings as
//     leads to visually check, not confirmed bugs.

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/hard_question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

const int RUNS_PER_CATEGORY = 300;
const double MIN_FEATURE_FRACTION = 0.12;

const List<String> CATEGORIES = [
  'odd_man',
  'figure_match',
  'pattern',
  'figure_series',
  'analogy',
];

void main() {
  setUp(() {
    // Fixed seed -> reproducible runs. Re-run with a different seed (or
    // remove this line to use wall-clock randomness) if you want to sample
    // a different slice than last time.
    HardQuestionGenerator.seed(42);
    HardQuestionGenerator.resetSession();
  });

  for (final category in CATEGORIES) {
    group('[$category]', () {
      int crashes = 0;
      int structuralFailures = 0;
      int duplicateOptionSets = 0;
      int tinyFeatureQuestions = 0;
      int giveawayQuestions = 0;
      final tinyFeatureSamples = <String>[];
      final giveawaySamples = <String>[];
      final crashSamples = <String>[];

      test('generate $RUNS_PER_CATEGORY questions and record findings', () {
        for (int i = 0; i < RUNS_PER_CATEGORY; i++) {
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
          final tiny = HardQuestionGenerator.debugTinyFeatureWarnings(q, minFraction: MIN_FEATURE_FRACTION);
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
        }

        // ---- report ----
        print('');
        print('=== [$category] diagnostic summary ($RUNS_PER_CATEGORY runs) ===');
        print('crashes: $crashes / $RUNS_PER_CATEGORY');
        if (crashSamples.isNotEmpty) {
          print('  sample crashes:');
          for (final s in crashSamples) {
            print('    - $s');
          }
        }
        print('structural failures (bad option count / correctIndex / empty puzzle): $structuralFailures / $RUNS_PER_CATEGORY');
        print('duplicate option sets slipping past generate()\'s own dedup: $duplicateOptionSets / $RUNS_PER_CATEGORY');
        print('questions with a tiny (<$MIN_FEATURE_FRACTION fraction) feature: $tinyFeatureQuestions / $RUNS_PER_CATEGORY');
        if (tinyFeatureSamples.isNotEmpty) {
          print('  sample tiny-feature findings:');
          for (final s in tinyFeatureSamples) {
            print('    - $s');
          }
        }
        if (category == 'pattern') {
          print('questions with a row/column giveaway slipping past the generation-time guard: $giveawayQuestions / $RUNS_PER_CATEGORY');
          if (giveawaySamples.isNotEmpty) {
            print('  sample giveaway runs: ${giveawaySamples.join(', ')}');
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