// A shape drawn on a near-black one must still show its outline: the
// outline is dark too, so it gets a light edge (mentors' printed paper,
// 2026-10-17: a white diamond on a black rectangle could not be seen).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/painters/sandia_painter.dart';

Future<(Uint8List, int)> render(Map<String, dynamic> data, WidgetTester t) async {
  const size = 80;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 80, 80), Paint()..color = Colors.white);
  SandiaPainter(data).paint(canvas, const Size(80, 80));
  final img = await t.runAsync(() => rec.endRecording().toImage(size, size));
  final bytes = await t.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.rawRgba));
  return (bytes!.buffer.asUint8List(), size);
}

void main() {
  testWidgets('a white diamond on a black rectangle shows a light edge', (t) async {
    final cell = {
      'type': 'sandia_cell',
      'layers': [
        {
          'features': [
            {'shape': 'rectangle', 'w': 0.6, 'h': 0.8, 'rot': 0, 'cx': 0.5, 'cy': 0.5, 'scale': 1.0, 'fill': 'black'},
            {'shape': 'diamond', 'w': 0.3, 'h': 0.45, 'rot': 0, 'cx': 0.5, 'cy': 0.5, 'scale': 1.0, 'fill': 'white'},
          ],
        },
      ],
    };
    final (px, size) = await render(cell, t);
    int lum(int x, int y) {
      final i = (y * size + x) * 4;
      return (px[i] * 77 + px[i + 1] * 150 + px[i + 2] * 29) >> 8;
    }

    // Along the row through the centre, inside the rectangle: the
    // brightest pixel left of centre should be light (the diamond's edge),
    // not the rectangle's dark fill.
    final row = [for (int x = 18; x < 40; x++) lum(x, 40)];
    expect(row.reduce((a, b) => a > b ? a : b), greaterThan(150), reason: 'row luminance $row');
  });
}
