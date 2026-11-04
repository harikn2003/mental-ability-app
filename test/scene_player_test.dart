// The scene player: draws a scene at any point of its timeline, starting on
// the question's figures and ending on the correct option framed green.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/reasoning_question.dart';
import 'package:mental_ability_app/engine/scene.dart';
import 'package:mental_ability_app/widgets/explanation_panel.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';
import 'package:mental_ability_app/widgets/scene_player.dart';

Map<String, dynamic> _c(int rotation) =>
    {'shape': 8, 'filled': false, 'rotation': rotation, 'mirror': false, 'dots': 0, 'inner': 0, 'lines': 0, 'missingCorner': 0};

Scene _turnScene() => Scene(
      extent: const Size(200, 80),
      slots: [Slot(figure: _c(0), at: const Offset(0, 8)), const Slot(at: Offset(120, 8), question: true)],
      steps: [FlyStep(0, 1, Morph.diff(_c(0), _c(1))!), const RevealStep()],
      answerSlot: 1,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

Iterable<Map<String, dynamic>> _drawn(WidgetTester t) => t.widgetList<OptionRenderer>(find.byType(OptionRenderer)).map((w) => w.data);

bool _framedGreen(WidgetTester t) => t.widgetList<Container>(find.byType(Container)).any((c) {
      final d = c.decoration;
      return d is BoxDecoration && d.border is Border && (d.border as Border).top.color.toARGB32() == const Color(0xFF16A34A).toARGB32();
    });

void main() {
  testWidgets('progress 0: the source figure and an empty question box', (tester) async {
    await tester.pumpWidget(_host(ScenePlayer(scene: _turnScene(), progress: 0)));
    expect(_drawn(tester).map((d) => d['rotation']), [0]);
    expect(find.text('?'), findsOneWidget);
    expect(_framedGreen(tester), isFalse);
  });

  testWidgets('mid-flight the copy is a real half-turned figure', (tester) async {
    final scene = _turnScene();
    // The fly step's middle: after the lead-in, half of its share.
    final mid = ScenePlayer.leadIn + (1 - ScenePlayer.leadIn) * (0.5 / scene.totalWeight);
    await tester.pumpWidget(_host(ScenePlayer(scene: scene, progress: mid)));
    final rotations = _drawn(tester).map((d) => (d['rotation'] as num).toDouble()).toList();
    expect(rotations.any((r) => (r - 0.5).abs() < 0.1), isTrue, reason: '$rotations');
  });

  testWidgets('progress 1: the answer, framed green, in the question slot', (tester) async {
    await tester.pumpWidget(_host(ScenePlayer(scene: _turnScene(), progress: 1)));
    expect(_drawn(tester).map((d) => d['rotation']), containsAll([0, 1]));
    expect(find.text('?'), findsNothing);
    expect(_framedGreen(tester), isTrue);
  });

  testWidgets('every step kind paints at every point', (tester) async {
    final scene = Scene(
      extent: const Size(300, 100),
      slots: [for (int i = 0; i < 4; i++) Slot(figure: _c(i), at: Offset(70.0 * i, 0))],
      steps: [
        MorphStep(0, Morph.diff(_c(0), {..._c(0), 'filled': true, 'mirror': true})!),
        const PulseStep([1, 2], colour: Color(0xFFDC2626), stay: true),
        const TogetherStep([TickStep(1, 3), TickStep(2, 4)]),
        FlyStep(3, 0, const []),
        const RevealStep(),
      ],
      answerSlot: 0,
    );
    for (final p in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
      await tester.pumpWidget(_host(ScenePlayer(scene: scene, progress: p)));
      expect(tester.takeException(), isNull, reason: 'at $p');
    }
  });

  testWidgets('a wide scene fits a 360 dp phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scene = Scene(
      extent: const Size(7 * 90, 90),
      slots: [for (int i = 0; i < 7; i++) Slot(figure: _c(i % 4), at: Offset(90.0 * i, 0), size: 84)],
      steps: const [RevealStep()],
      answerSlot: 6,
    );
    final q = ReasoningQuestion(category: 'test_scene', type: 't', puzzle: const {}, options: [_c(2)], correctIndex: 0);
    await tester.pumpWidget(_host(ExplanationPanel.scene(question: q, scene: scene)));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  group('in the explanation panel', () {
    final q = ReasoningQuestion(category: 'test_scene', type: 't', puzzle: const {}, options: [_c(1)], correctIndex: 0);
    Scene five() => Scene(
          extent: const Size(200, 80),
          slots: [Slot(figure: _c(0), at: Offset.zero), const Slot(at: Offset(120, 0), question: true)],
          steps: [for (int i = 0; i < 4; i++) const PulseStep([0]), FlyStep(0, 1, Morph.diff(_c(0), _c(1))!), const RevealStep()],
          answerSlot: 1,
        );

    testWidgets('the panel plays for the scene\'s own length', (tester) async {
      var finished = 0;
      final scene = five();
      expect(scene.duration.inMilliseconds, greaterThan(4000));
      await tester.pumpWidget(_host(ExplanationPanel.scene(question: q, scene: scene, onFinished: () => finished++)));
      await tester.pump(const Duration(milliseconds: 3000));
      expect(finished, 0);
      await tester.pump(scene.duration - const Duration(milliseconds: 2900));
      expect(finished, 1);
      expect(_framedGreen(tester), isTrue);
    });

    testWidgets('closing it mid-scene is clean', (tester) async {
      await tester.pumpWidget(_host(ExplanationPanel.scene(question: q, scene: five())));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });
}
