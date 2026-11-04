// Explanations draw in-between frames as real figure maps: a part half-way
// through a turn, a dot half-way along its path. These tests pin that every
// painter draws such fractional values, and that whole values look exactly
// as before.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/widgets/option_renderer.dart';

const double _size = 100;

Future<Uint8List> _render(WidgetTester tester, Map<String, dynamic> fig) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Center(
      child: RepaintBoundary(
        key: key,
        child: Container(color: Colors.white, child: OptionRenderer(data: fig, size: _size)),
      ),
    ),
  ));
  late Uint8List out;
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
    out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    img.dispose();
  });
  return out;
}

/// Share of pixels whose colour differs noticeably.
double _diff(Uint8List a, Uint8List b) {
  var n = 0;
  for (int i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs() > 75) n++;
  }
  return n / (a.length / 4);
}

Map<String, dynamic> _classic(num rotation) => {'shape': 8, 'filled': false, 'rotation': rotation};
Map<String, dynamic> _features(num rot) => {
      'type': 'sandia_cell',
      'layers': [
        {
          'features': [
            {'shape': 'rectangle', 'w': 0.7, 'h': 0.2, 'rot': rot, 'cx': 0.5, 'cy': 0.5, 'fill': 'white'},
          ],
        },
      ],
    };
Map<String, dynamic> _layers(num rotation) => {
      'type': 'sandia_cell',
      'layers': [
        {'surface': 1, 'fill': 0, 'scale': 2, 'rotation': rotation},
      ],
    };
Map<String, dynamic> _line(num turn, {num flip = 1}) => {
      'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false,
      'segs': [[0, 0, 4, 0], [0, 0, 0, 2]],
      'turn': turn,
      'flip': flip,
    };

void main() {
  final kinds = <String, Map<String, dynamic> Function(num)>{
    'classic shape': (q) => _classic(q),
    'sandia feature (degrees)': (q) => _features(q * 90),
    'sandia layer': (q) => _layers(q),
    'line drawing': (q) => _line(q),
  };

  for (final MapEntry(key: name, value: fig) in kinds.entries) {
    testWidgets('$name: a half turn is drawn between its neighbours', (tester) async {
      final zero = await _render(tester, fig(0));
      final half = await _render(tester, fig(0.5));
      final one = await _render(tester, fig(1));
      expect(_diff(zero, one), greaterThan(0.02), reason: 'test figure must change when turned');
      expect(_diff(half, zero), greaterThan(0.02), reason: 'half turn drawn as no turn');
      expect(_diff(half, one), greaterThan(0.02), reason: 'half turn drawn as a full turn');
    });

    testWidgets('$name: whole values as doubles look exactly as ints', (tester) async {
      final asInt = await _render(tester, fig(1));
      final asDouble = await _render(tester, fig(1.0));
      expect(_diff(asInt, asDouble), 0);
    });
  }

  testWidgets('line drawing: a whole turn key equals the turned drawing', (tester) async {
    final turned = await _render(tester, _line(1));
    final drawn = await _render(tester, {
      'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false,
      'segs': [[4, 0, 4, 4], [2, 0, 4, 0]], // rot90 of the base: (X,Y) -> (4-Y, X)
    });
    expect(_diff(turned, drawn), lessThan(0.005));
  });

  testWidgets('line drawing: flip -1 mirrors, flip 0 is a sliver', (tester) async {
    final mirrored = await _render(tester, _line(0, flip: -1));
    final drawn = await _render(tester, {
      'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false,
      'segs': [[0, 0, 4, 0], [4, 0, 4, 2]],
    });
    expect(_diff(mirrored, drawn), lessThan(0.005));
    final edgeOn = await _render(tester, _line(0, flip: 0));
    final blank = await _render(tester, {'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false});
    expect(_diff(edgeOn, blank), lessThan(0.02));
  });

  testWidgets('line drawing: a dot half-way between cells', (tester) async {
    Map<String, dynamic> dotAt(num x) => {'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false, 'dots': [[x, 1]]};
    final a = await _render(tester, dotAt(0));
    final mid = await _render(tester, dotAt(1.5));
    final b = await _render(tester, dotAt(3));
    expect(_diff(mid, a), greaterThan(0.002));
    expect(_diff(mid, b), greaterThan(0.002));
    final glyphMid = await _render(tester, {'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false, 'glyphs': [[1.5, 1, 'star']], 'rings': [[2.5, 1]]});
    expect(tester.takeException(), isNull);
    expect(_diff(glyphMid, await _render(tester, {'type': 'line_fig', 'w': 4, 'h': 4, 'frame': false})), greaterThan(0.002));
  });
  testWidgets('letters: the slide starts on the first word and ends on the second', (tester) async {
    Map<String, dynamic> word(String s) => {'type': 'mirror_text', 'content': s, 'is_clock': false, 'mirror_h': false, 'mirror_v': false};
    // Tests draw every letter as the same block; spaces show where it is.
    final glide = {...word('N  '), 'glide_to': '  N', 'targets': [2, 0, 1]};
    final first = await _render(tester, word('N  ')), second = await _render(tester, word('  N'));
    expect(_diff(first, second), greaterThan(0.01));
    expect(_diff(await _render(tester, {...glide, 't': 0}), first), lessThan(0.002));
    expect(_diff(await _render(tester, {...glide, 't': 1}), second), lessThan(0.002));
    final mid = await _render(tester, {...glide, 't': 0.5});
    expect(_diff(mid, first), greaterThan(0.01));
    expect(_diff(mid, second), greaterThan(0.01));
  });
}
