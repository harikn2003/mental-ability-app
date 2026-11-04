// Every Mirror / Punch Hole / Embedded question gets an explanation, and the
// explanation re-derives the correct option: the animation can only ever end
// on the right answer, by the rule the generator used.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/explanation.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/paper_fold.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';

/// As stored in a saved session and read back (dynamic maps and lists).
ReasoningQuestion _roundTrip(ReasoningQuestion q) {
  final m = jsonDecode(jsonEncode({'p': q.puzzle, 'o': q.options})) as Map<String, dynamic>;
  return ReasoningQuestion(
    category: q.category,
    type: q.type,
    puzzle: Map<String, dynamic>.from(m['p'] as Map),
    options: [for (final o in m['o'] as List) Map<String, dynamic>.from(o as Map)],
    correctIndex: q.correctIndex,
  );
}

String _j(Object? o) => jsonEncode(o);

int _hour(int h) => ((h - 1) % 12 + 12) % 12 + 1;

void _checkMirror(ReasoningQuestion q, MirrorExplanation e) {
  final fig = e.figure, ans = e.answer;
  if (fig['type'] == 'line_fig') {
    expect(LineFig.fromMap(fig).mirrorX().key, LineFig.fromMap(ans).key, reason: q.type);
  } else if (fig['type'] == 'mirror_text') {
    expect(fig['mirror_h'], isNot(true));
    expect(fig['mirror_v'], isNot(true));
    if (fig['is_clock'] == true) {
      final h = fig['clock_hour'] as int, m = fig['clock_minute'] as int;
      final mh = m == 0 ? 12 - h : 11 - h, mm = m == 0 ? 0 : 60 - m;
      expect([_hour(ans['clock_hour'] as int), ans['clock_minute']], [_hour(mh), mm], reason: q.type);
    } else {
      expect(ans['content'], fig['content'], reason: q.type);
      expect(ans['mirror_h'], true, reason: q.type);
      expect(ans['mirror_v'], isNot(true), reason: q.type);
      expect(ans['selective_mirror_trap'], isNot(true), reason: q.type);
    }
  } else {
    // A shape figure: the answer is the same figure with 'mirror' toggled.
    expect(fig['mirror'], isNot(true), reason: q.type);
    expect(ans['mirror'], true, reason: q.type);
    expect(_j({...ans}..remove('mirror')), _j({...fig}..remove('mirror')), reason: q.type);
  }
}

void _checkUnfold(ReasoningQuestion q, UnfoldExplanation e) {
  expect(e.folds, isNotEmpty);
  expect(e.stages.length, e.folds.length + 1);
  expect(PaperFold.holesKey(e.stages[e.folds.length]), PaperFold.holesKey(q.puzzle['holes'] as List));
  expect(PaperFold.holesKey(e.stages[0]), PaperFold.holesKey(e.answer['holes'] as List), reason: q.type);
}

void _checkFoldOver(FoldOverExplanation e) {
  final sheet = LineFig.fromMap(e.sheet);
  // Right half (x >= 2) flipped over the fold line x = 2 onto the left half.
  final folded = {
    for (final (a, b, c, d) in sheet.segs) (a <= 2 && c <= 2) ? (a, b, c, d) : (4 - a, b, 4 - c, d),
  };
  Set<String> norm(Set<(int, int, int, int)> s) => {
        for (final (a, b, c, d) in s) (a * 10 + b <= c * 10 + d) ? '$a,$b,$c,$d' : '$c,$d,$a,$b',
      };
  expect(norm(folded), norm(LineFig.fromMap(e.answer).segs));
}

void _checkEmbedded(ReasoningQuestion q, EmbeddedExplanation e) {
  final target = q.puzzle['target'] as Map;
  if (e.answer['type'] == 'embedded_option') {
    expect(e.shapeIndex, isNotNull, reason: q.type);
    expect(_j((e.answer['shapes'] as List)[e.shapeIndex!]), _j(target));
  } else {
    expect(e.segs, isNotNull, reason: q.type);
    final host = LineFig.fromMap(e.answer);
    final placed = {for (final s in e.segs!) (s[0], s[1], s[2], s[3])};
    expect(host.segs.containsAll(placed), isTrue);
    final t = LineFig.fromMap(Map<String, dynamic>.from(target));
    expect(LineFig(host.w, host.h, segs: placed).normalized().key, t.normalized().key);
  }
}

void main() {
  test('every Mirror / Punch Hole / Embedded question explains its own answer', () {
    QuestionGenerator.seed(31);
    final types = <String>{};
    for (final cat in ['mirror_shape', 'mirror_text', 'punch_hole', 'embedded']) {
      for (final d in Difficulty.values) {
        for (int i = 0; i < 300; i++) {
          final q = _roundTrip(QuestionGenerator.generate(cat, difficulty: d));
          types.add(q.type);
          final e = Explanation.of(q);
          expect(e, isNotNull, reason: '${q.type} ($cat, $d)');
          expect(_j(e!.answer), _j(q.options[q.correctIndex]));
          switch (e) {
            case MirrorExplanation():
              expect(cat, anyOf('mirror_shape', 'mirror_text'));
              _checkMirror(q, e);
            case UnfoldExplanation():
              expect(q.puzzle['type'], 'punch_hole');
              _checkUnfold(q, e);
            case FoldOverExplanation():
              expect(q.puzzle['type'], 'paper_fold');
              _checkFoldOver(e);
            case EmbeddedExplanation():
              expect(cat, 'embedded');
              _checkEmbedded(q, e);
            case SceneExplanation():
              fail('slice-1 topics are not scenes');
          }
        }
      }
    }
    expect(
        types,
        containsAll([
          'mirror_shape', 'mirror_shape_hard', 'mirror_line_fig', 'mirror_clock', //
          'punch_hole_easy', 'punch_hole_two', 'punch_hole', 'punch_hole_double_fold', 'punch_hole_exam', 'paper_fold',
          'embedded', 'embedded_medium', 'embedded_line', // embedded_hard: Hard's fallback only, same builder as embedded_medium
        ]));
  });

  test('a question is worked out once (the quiz asks for it twice)', () {
    QuestionGenerator.seed(5);
    final q = QuestionGenerator.generate('pattern', difficulty: Difficulty.hard);
    expect(identical(Explanation.of(q), Explanation.of(q)), isTrue);
  });

  test('a topic the app does not know has no explanation', () {
    final q = ReasoningQuestion(category: 'unknown_topic', type: 'unknown', puzzle: const {}, options: const [{}, {}, {}, {}], correctIndex: 0);
    expect(Explanation.of(q), isNull);
  });

  test('a malformed question gives no explanation instead of throwing', () {
    final q = ReasoningQuestion(category: 'embedded', type: 'embedded', puzzle: {'type': 'embedded'}, options: [{}], correctIndex: 0);
    expect(Explanation.of(q), isNull);
  });
}
