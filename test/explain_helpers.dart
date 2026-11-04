// Shared checks for the topic explanations (scenes): every generated
// question of a topic gets a scene whose moves really lead, change by
// change, from the question's figures to the correct option.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/explanation.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/scene.dart';

/// A copy as a saved session gives it back: through JSON, then (every other
/// time) as `Map<dynamic, dynamic>` like Hive.
ReasoningQuestion savedCopy(ReasoningQuestion q, {bool hive = false}) {
  dynamic deep(dynamic v) => v is Map ? <dynamic, dynamic>{for (final e in v.entries) e.key: deep(e.value)} : v is List ? [for (final x in v) deep(x)] : v;
  dynamic back(String s) => hive ? deep(jsonDecode(s)) : jsonDecode(s);
  return ReasoningQuestion(
    category: q.category,
    type: q.type,
    puzzle: Map<String, dynamic>.from(back(jsonEncode(q.puzzle)) as Map),
    options: [for (final o in q.options) Map<String, dynamic>.from(back(jsonEncode(o)) as Map)],
    correctIndex: q.correctIndex,
  );
}

/// The chain law for [beats] starting at [start].
void checkBeats(List<Beat> beats, Map start, String why) {
  if (beats.isEmpty) return;
  expect(beats.length, lessThanOrEqualTo(5), reason: '$why: too many changes at once');
  expect(Morph.same(beats.first.from, start), isTrue, reason: '$why: does not start on the figure shown\n${jsonEncode(beats.first.from)}\n${jsonEncode(start)}');
  for (int i = 0; i + 1 < beats.length; i++) {
    expect(Morph.same(beats[i].to, beats[i + 1].from), isTrue, reason: '$why: link $i broken');
  }
  for (final b in beats) {
    expect(Morph.same(Morph.frame(b, 0), b.from), isTrue, reason: '$why: frame 0');
    expect(Morph.same(Morph.frame(b, 1), b.to), isTrue, reason: '$why: frame 1');
    expect(Morph.same(b.from, b.to), isFalse, reason: '$why: a change that changes nothing');
  }
}

/// Plays [scene] as data, checking every move's chain against what its slot
/// holds at that moment; returns the contents at the end.
List<Map<String, dynamic>?> playScene(Scene scene, String why) {
  final c = [for (final s in scene.slots) s.figure];
  void step(SceneStep s) {
    switch (s) {
      case MorphStep(:final slot, :final beats):
        expect(c[slot], isNotNull, reason: '$why: morph of an empty slot');
        checkBeats(beats, c[slot]!, '$why (morph slot $slot)');
      case FlyStep(:final from, :final beats, :final figure):
        final start = figure ?? c[from];
        expect(start, isNotNull, reason: '$why: nothing to fly');
        checkBeats(beats, start!, '$why (fly from $from)');
      case TogetherStep(:final steps):
        steps.forEach(step);
      default:
        break;
    }
    s.apply(c);
  }

  scene.steps.forEach(step);
  expect(scene.steps.last, isA<RevealStep>(), reason: '$why: does not end on the answer');
  expect(scene.duration.inMilliseconds, lessThanOrEqualTo(6500));
  return c;
}

/// Generates [n] questions of [category] per difficulty and checks each
/// one's scene: it exists, every move is a true chain, the answer slot ends
/// on the correct option, and [rule] (the topic's own check) holds. Every
/// type in [types] must be seen.
void checkTopic(String category, Set<String> types, {int n = 300, void Function(ReasoningQuestion q, Scene s)? rule}) {
  final seen = <String>{};
  var k = 0;
  for (final d in Difficulty.values) {
    QuestionGenerator.seed(31);
    for (int i = 0; i < n; i++) {
      final q = savedCopy(QuestionGenerator.generate(category, difficulty: d), hive: (k++).isOdd);
      seen.add(q.type);
      final why = '${q.type} (${d.name})';
      final e = Explanation.of(q);
      expect(e, isA<SceneExplanation>(), reason: '$why: no scene');
      final scene = (e as SceneExplanation).scene;
      final end = playScene(scene, why);
      expect(end[scene.answerSlot], isNotNull, reason: why);
      expect(Morph.same(end[scene.answerSlot]!, q.options[q.correctIndex]), isTrue,
          reason: '$why: ends on\n${jsonEncode(end[scene.answerSlot])}\nnot the answer\n${jsonEncode(q.options[q.correctIndex])}');
      rule?.call(q, scene);
    }
  }
  expect(seen, containsAll(types), reason: 'types never generated');
}
