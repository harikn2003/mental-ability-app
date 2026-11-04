// Geo Completion: the correct piece turns back (if it is shown turned) and
// slides into the gap; the completed shape glows.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/difficulty.dart';
import 'package:mental_ability_app/engine/line_figure.dart';
import 'package:mental_ability_app/engine/morph.dart';
import 'package:mental_ability_app/engine/morph_line.dart';
import 'package:mental_ability_app/engine/question_generator.dart';
import 'package:mental_ability_app/engine/scene.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';

import 'explain_helpers.dart';

Future<Uint8List> _render(WidgetTester tester, Map<String, dynamic> fig) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Center(child: RepaintBoundary(key: key, child: Container(color: Colors.white, child: OptionRenderer(data: fig, size: 100)))),
  ));
  late Uint8List out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
    out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    img.dispose();
  });
  return out;
}

void main() {
  test('every geo question: the piece lands in the gap and completes the shape', () {
    checkTopic('geo_completion', {'geo_jigsaw', 'geo_grid_cut'}, rule: (q, scene) {
      final fly = scene.steps.whereType<FlyStep>().single;
      expect(fly.from, scene.answerSlot);
      final end = scene.finalContents;
      final shape = Morph.plain(q.puzzle['piece'] as Map);
      final landed = end[fly.to]!;
      expect(scene.slots[fly.to].at, scene.slots[0].at, reason: 'lands on the puzzle figure');
      if (q.type == 'geo_grid_cut') {
        expect(fly.beats.whereType<TurnBeat>().length, lessThanOrEqualTo((q.puzzle['answer_turn'] as int) == 0 ? 0 : 1));
        expect(landed['center'], isNot(true), reason: 'the piece ends written in place');
        final gap = LineFig.fromMap(shape).cells, piece = LineFig.fromMap(landed).cells;
        expect(gap.intersection(piece), isEmpty, reason: 'piece overlaps the shape');
        expect(gap.union(piece).length, shape['w'] * shape['h'], reason: 'shape not complete');
      } else {
        expect(landed['shape'], shape['shape']);
        expect(landed['cut'], shape['cut']);
        expect({landed['piece'], shape['piece'] ?? 0}, {0, 1});
      }
    });
  });

  testWidgets('a centred piece and the same piece written in place look the same', (tester) async {
    QuestionGenerator.seed(4);
    var checked = 0;
    for (int i = 0; i < 60 && checked < 5; i++) {
      final q = QuestionGenerator.generate('geo_completion', difficulty: Difficulty.hard);
      if (q.type != 'geo_grid_cut') continue;
      final centred = Morph.plain(q.options[q.correctIndex]);
      final placed = MorphLine.uncentred(centred);
      expect(placed['center'], isNot(true));
      expect(Morph.same(centred, placed), isTrue);
      final a = await _render(tester, centred), b = await _render(tester, placed);
      var differ = 0;
      for (int k = 0; k < a.length; k += 4) {
        if ((a[k] - b[k]).abs() > 60) differ++;
      }
      expect(differ / (a.length / 4), lessThan(0.002), reason: jsonEncode(centred));
      checked++;
    }
    expect(checked, 5);
  });
}
