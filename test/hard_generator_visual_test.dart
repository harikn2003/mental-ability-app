// Visual (pixel-level) diagnostic test for HardQuestionGenerator.
//
// Every prior diagnostic in this project (hard_generator_diagnostics_test.dart)
// only ever compared the underlying DATA attributes of two options (shape,
// w, h, rot, fill, scale) - never what actually lands on screen. That's a
// real gap: two options can carry genuinely different data and still
// composite to close-enough colors, or close-enough shapes, that a person
// can't tell them apart. No amount of attribute-level checking can catch
// that, because the thing being judged (perceived visual difference) only
// exists once real pixels exist. This file renders the ACTUAL widgets the
// app renders, captures real pixels, and compares those.
//
// TWO SEPARATE CHECKS:
//
//   1. Per-question visual distinctness: generate real questions, render
//      all 4 options through the exact same OptionRenderer widget the app
//      uses, capture each as an image, and compare every pair of options
//      pixel-by-pixel. Flags any pair whose rendered difference is small
//      enough to plausibly read as "the same" at a glance.
//
//   2. Sandia palette validation: independent of any generated question,
//      renders a plain shape in each of the four fill keys (white, grey40,
//      grey10, black) and checks two things against the documented Sandia
//      source values (see SandiaFill's own doc comment in sandia_painter.dart):
//        a) each fill's rendered color is close to the alpha-composited
//           value the source actually specifies, so a future accidental
//           change to the palette gets caught here instead of by a person
//           squinting at an app screen
//        b) every ADJACENT pair in the fill cycle stays far enough apart
//           in rendered color that stepping from one to the next is
//           actually visible - this is what "changeFill"-style rules
//           depend on being true
//
// HOW TO RUN
//   flutter test test/hard_generator_visual_test.dart
//
// HOW TO USE THE OUTPUT
//   Everything is printed via print(), same convention as the other
//   diagnostics file. Copy the full console output back - the printed
//   sample findings (which options, what the measured difference was) are
//   what need a second look, not the pass/fail line alone.
//
// PASS/FAIL: near-duplicate findings are printed as leads, not asserted
// (the thresholds are judgment calls). A PIXEL-IDENTICAL option pair fails
// the test - that's never a judgment call. generate()'s own live guard
// (_optionPairDiff / the rasterizer in hard_question_generator.dart) is
// tuned to be at least as strict as this file's thresholds, so a clean
// sweep here is the expected state; a residual ~0.03% right at the 2%
// boundary is rounding between that rasterizer and real anti-aliasing.
//
// TUNING - none of these thresholds are measured against a real device or
// a real person's perception. They're reasoned starting points, the same
// way the data-attribute thresholds in the other diagnostics file were -
// treat findings as leads to visually confirm, not automatically-true bugs.
//   - meanColorDiffThreshold / significantPixelFractionThreshold: how close
//     two option renders have to be, on average and in peak difference, to
//     get flagged as a possible visual duplicate.
//   - paletteToleranceRgb: how far a rendered fill's sampled color may sit
//     from the theoretically-expected composited value before it's flagged
//     as a palette regression (anti-aliasing and rounding need some room).
//   - minAdjacentFillDistance: the minimum rendered color distance required
//     between consecutive fills in the cycle (white->grey40->grey10->black)
//     for a fill step to count as "visibly different".
//
// Rendering is far more expensive than pure logic generation, so run counts
// here are much lower than the data-only diagnostics file (25/category
// instead of 300/category) to keep a single test run practical.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/hard_question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';
import 'package:flutter/rendering.dart';

// Override for a deeper sweep, or a different slice, without editing this file:
//   flutter test test/hard_generator_visual_test.dart --dart-define=VISUAL_RUNS=200 --dart-define=VISUAL_SEED=7
const int runsPerCategory = int.fromEnvironment('VISUAL_RUNS', defaultValue: 25);
const double renderSize = 64; // matches OptionRenderer's production default
const double meanColorDiffThreshold = 6.0; // out of 255, averaged over the whole image
const double significantPixelFractionThreshold = 0.02; // 2% of pixels differing by >25/255

const double paletteToleranceRgb = 18; // anti-aliasing/rounding slack
const double minAdjacentFillDistance = 30; // matches the ~30%-apart design already documented for the fill cycle

const List<String> categories = [
  'odd_man',
  'figure_match',
  'pattern',
  'figure_series',
  'analogy',
];

/// Result of comparing two rendered images pixel-by-pixel.
class _PixelDiff {
  final double meanColorDistance;
  final double significantPixelFraction;
  _PixelDiff(this.meanColorDistance, this.significantPixelFraction);
}

/// Converts a premultiplied-alpha pixel (what toByteData(rawRgba) actually
/// returns - confirmed empirically: e.g. grey40's true color/alpha per
/// SandiaFill is (102,102,102,128), and premultiplying gives
/// 102*(128/255)=51.2, which is exactly what got captured) into the color
/// a person actually sees once it's composited over the app's white
/// background. Comparing premultiplied bytes directly systematically
/// compresses perceived differences - especially for low-alpha fills,
/// where premultiplication pulls everything toward (0,0,0) regardless of
/// true base color - so every comparison below composites first.
List<int> _compositeOverWhite(List<int> premultipliedRgba) {
  final a = premultipliedRgba[3];
  int channel(int c) => (c + (255 - a)).clamp(0, 255);
  return [channel(premultipliedRgba[0]), channel(premultipliedRgba[1]), channel(premultipliedRgba[2]), 255];
}

_PixelDiff _comparePixels(ByteData a, ByteData b) {
  final pa = a.buffer.asUint8List();
  final pb = b.buffer.asUint8List();
  final n = pa.length < pb.length ? pa.length : pb.length;
  double totalDist = 0;
  int significant = 0;
  int pixelCount = 0;
  for (int i = 0; i + 3 < n; i += 4) {
    final ca = _compositeOverWhite([pa[i], pa[i + 1], pa[i + 2], pa[i + 3]]);
    final cb = _compositeOverWhite([pb[i], pb[i + 1], pb[i + 2], pb[i + 3]]);
    final dr = (ca[0] - cb[0]).abs();
    final dg = (ca[1] - cb[1]).abs();
    final db = (ca[2] - cb[2]).abs();
    final dist = (dr + dg + db) / 3.0;
    totalDist += dist;
    if (dist > 25) significant++;
    pixelCount++;
  }
  if (pixelCount == 0) return _PixelDiff(0, 0);
  return _PixelDiff(totalDist / pixelCount, significant / pixelCount);
}

/// Renders up to 4 widgets side by side in one frame (so a single pump
/// covers all of them), each in its own RepaintBoundary, and returns their
/// captured pixels as raw RGBA ByteData in the same order.
Future<List<ByteData>> _renderAndCapture(WidgetTester tester, List<Widget> children) async {
  final keys = List.generate(children.length, (_) => GlobalKey());
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        color: Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++)
              RepaintBoundary(
                key: keys[i],
                child: SizedBox(width: renderSize, height: renderSize, child: children[i]),
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final results = <ByteData>[];
  await tester.runAsync(() async {
    for (final key in keys) {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      results.add(bytes!);
      image.dispose();
    }
  });
  return results;
}

/// Samples the color at the exact center pixel of a captured image -
/// assumes the shape under test is large enough that its fill covers the
/// center, which every palette-validation case below is built to ensure.
List<int> _centerPixel(ByteData data, int widthPx) {
  final bytes = data.buffer.asUint8List();
  final cx = widthPx ~/ 2;
  final cy = widthPx ~/ 2;
  final offset = (cy * widthPx + cx) * 4;
  return [bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]];
}

double _colorDistance(List<int> a, List<int> b) {
  final dr = (a[0] - b[0]).abs();
  final dg = (a[1] - b[1]).abs();
  final db = (a[2] - b[2]).abs();
  return (dr + dg + db) / 3.0;
}

void main() {
  testWidgets('per-question visual option distinctness', (tester) async {
    HardQuestionGenerator.seed(const int.fromEnvironment('VISUAL_SEED', defaultValue: 11));
    HardQuestionGenerator.resetSession();
    final exactDuplicates = <String>[];

    for (final category in categories) {
      int checked = 0;
      int flaggedQuestions = 0;
      final samples = <String>[];

      for (int i = 0; i < runsPerCategory; i++) {
        ReasoningQuestion q;
        try {
          q = HardQuestionGenerator.generate(category);
        } catch (_) {
          continue;
        }
        if (q.options.length != 4) continue;

        final captures = await _renderAndCapture(
          tester,
          [for (final opt in q.options) OptionRenderer(data: opt, size: renderSize)],
        );
        checked++;

        var flaggedThisQuestion = false;
        for (int a = 0; a < 4; a++) {
          for (int b = a + 1; b < 4; b++) {
            final diff = _comparePixels(captures[a], captures[b]);
            if (diff.meanColorDistance == 0) exactDuplicates.add('$category run $i [${q.type}]: option[$a] vs option[$b]');
            if (diff.meanColorDistance < meanColorDiffThreshold &&
                diff.significantPixelFraction < significantPixelFractionThreshold) {
              flaggedThisQuestion = true;
              if (samples.length < 8) {
                // Include the question type and both options' raw data so a
                // finding can be traced straight to the generator branch
                // that produced it, instead of re-deriving it from a seed.
                samples.add('run $i [${q.type}]: option[$a] vs option[$b] -> '
                    'meanDist=${diff.meanColorDistance.toStringAsFixed(2)}, '
                    'significantPixels=${(diff.significantPixelFraction * 100).toStringAsFixed(1)}%\n'
                    '        a=${q.options[a]}\n'
                    '        b=${q.options[b]}');
              }
            }
          }
        }
        if (flaggedThisQuestion) flaggedQuestions++;
      }

      print('');
      print('=== [$category] VISUAL diagnostic ($checked questions rendered) ===');
      print('questions with a visually indistinguishable option pair: $flaggedQuestions / $checked');
      if (samples.isNotEmpty) {
        print('  sample findings:');
        for (final s in samples) {
          print('    - $s');
        }
      }
      print('=== end [$category] VISUAL ===');
    }

    // Near-duplicates above stay report-only (the thresholds are judgment
    // calls), but two options painting byte-identical pixels is never a
    // judgment call - that's a question with two correct-looking answers.
    expect(exactDuplicates, isEmpty, reason: 'pixel-identical option pairs rendered - see findings above');
  });

  testWidgets('Sandia fill palette renders as documented', (tester) async {
    // Independent of any generated question: renders one large rectangle
    // per fill key so its color fills the entire capture, then samples the
    // center pixel and checks it against the alpha-composited-over-white
    // value the actual Sandia source specifies (see SandiaFill's doc
    // comment in sandia_painter.dart for the source alpha values this is
    // computed from).
    const expected = {
      'white': [255, 255, 255],
      'grey40': [179, 179, 179],
      'grey10': [118, 118, 118],
      'black': [64, 64, 64],
    };
    const order = ['white', 'grey40', 'grey10', 'black'];

    final captures = await _renderAndCapture(tester, [
      for (final fill in order)
        OptionRenderer(
          data: {
            'type': 'sandia_cell',
            'grid_box': false,
            'layers': [
              {
                'features': [
                  {'shape': 'rectangle', 'w': 0.95, 'h': 0.95, 'rot': 0, 'cx': 0.5, 'cy': 0.5, 'scale': 1.0, 'fill': fill},
                ],
              },
            ],
          },
          size: renderSize,
        ),
    ]);

    // toImage(pixelRatio: 1.0) captures at exactly 1 image pixel per
    // logical pixel, regardless of the test device's actual pixel ratio -
    // so the captured width is renderSize itself, not renderSize scaled by
    // devicePixelRatio.
    final widthPx = renderSize.round();
    final sampled = <String, List<int>>{};
    print('');
    print('=== Sandia palette VISUAL validation ===');
    for (int i = 0; i < order.length; i++) {
      final raw = _centerPixel(captures[i], widthPx);
      // toByteData(rawRgba) returns premultiplied alpha (confirmed: e.g.
      // grey40's true (r,g,b,a) is (102,102,102,128), and 102*(128/255)
      // rounds to exactly 51 - the raw captured value) - composite over
      // white before comparing, since that's the color a person actually
      // sees, not the premultiplied byte value.
      final composited = _compositeOverWhite(raw);
      sampled[order[i]] = composited;
      final dist = _colorDistance(composited, expected[order[i]]!);
      final status = dist <= paletteToleranceRgb ? 'OK' : 'MISMATCH';
      print('  ${order[i]}: raw(premultiplied)=$raw composited=$composited expected=${expected[order[i]]} '
          'distance=${dist.toStringAsFixed(1)} [$status]');
    }

    print('  adjacent-step distances (need >= $minAdjacentFillDistance to count as visibly different):');
    for (int i = 0; i < order.length - 1; i++) {
      final d = _colorDistance(sampled[order[i]]!, sampled[order[i + 1]]!);
      final status = d >= minAdjacentFillDistance ? 'OK' : 'TOO CLOSE';
      print('    ${order[i]} -> ${order[i + 1]}: ${d.toStringAsFixed(1)} [$status]');
    }
    print('=== end Sandia palette VISUAL validation ===');
  });
}