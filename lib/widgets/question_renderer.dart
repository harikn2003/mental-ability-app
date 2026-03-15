import 'package:flutter/material.dart';

import '../painters/figure_painter.dart';
import '../painters/mirror_text_painter.dart';
import '../painters/punch_painter.dart';

/// QuestionRenderer — renders the puzzle area for all 10 question types.
/// All shapes use FigurePainter (same vocabulary as the generator).
class QuestionRenderer extends StatelessWidget {
  final Map<String, dynamic> puzzle;
  const QuestionRenderer({super.key, required this.puzzle});

  static const Color _subtle = Color(0xFF64748B);
  static const Color _blue = Color(0xFF195DE6);
  static const Color _ink = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    switch (puzzle['type']) {
      case 'odd_man':
        return _oddMan();
      case 'figure_match':
        return _figureMatch();
      case 'matrix':
        return _matrix();
      case 'series':
        return _series();
      case 'analogy':
        return _analogy();
      case 'geo_completion':
        return _geoCompletion();
      case 'mirror_shape':
        return _mirrorShape();
      case 'mirror_text':
        return _mirrorTextQ();
      case 'punch_hole':
        return _punchHole();
      case 'embedded':
        return _embedded();
      default:
        return const Center(child: Text('?'));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fig(Map<String, dynamic> data, {double size = 64}) =>
      FigureWidget(data: data, size: size);

  Widget _label(String text) =>
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: _subtle, height: 1.4),
      );

  Widget _qBox({double size = 64}) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Center(
          child: Text('?', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: _subtle)),
        ),
      );

  Widget _mirrorLine() =>
      Container(
        width: 2.5, height: 90,
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── 1. Odd Man Out ─────────────────────────────────────────────────────────
  Widget _oddMan() =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _label(
            'One figure is different from the other three.\nFind the odd one out.'),
      );

  // ── 2. Figure Match ────────────────────────────────────────────────────────
  Widget _figureMatch() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Find the exact match'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue, width: 2),
        ),
        child: _fig(target, size: 80),
      ),
    ]);
  }

  // ── 3. Pattern Completion (3×3 matrix) ────────────────────────────────────
  Widget _matrix() {
    final cells = (puzzle['cells'] as List).cast<Map<String, dynamic>>();
    final missing = puzzle['missing'] as int? ?? 8;
    const cellSize = 54.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Find the missing figure to complete the pattern'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (row) =>
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (col) {
                  final idx = row * 3 + col;
                  final cell = cells[idx];
                  final isQ = idx == missing;
                  return Container(
                    width: cellSize, height: cellSize,
                    decoration: BoxDecoration(
                      color: isQ ? const Color(0xFFE2E8F0) : Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: isQ
                        ? const Center(child: Text('?',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _subtle)))
                        : (cell['empty'] == true
                        ? const SizedBox()
                        : Center(child: _fig(cell, size: 38))),
                  );
                }),
              )),
        ),
      ),
    ]);
  }

  // ── 4. Figure Series ───────────────────────────────────────────────────────
  Widget _series() {
    final seq = (puzzle['sequence'] as List).cast<Map<String, dynamic>>();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('What comes next in the series?'),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final item in seq) ...[
              _fig(item, size: 58),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                    Icons.arrow_forward_rounded, color: _subtle, size: 18),
              ),
            ],
            _qBox(size: 58),
          ],
        ),
      ),
    ]);
  }

  // ── 5. Analogy ─────────────────────────────────────────────────────────────
  Widget _analogy() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('A : B :: C : ?'),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _fig(Map<String, dynamic>.from(puzzle['A'] as Map), size: 50),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(':', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: _ink))),
            _fig(Map<String, dynamic>.from(puzzle['B'] as Map), size: 50),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('::', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: _blue))),
            _fig(Map<String, dynamic>.from(puzzle['C'] as Map), size: 50),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(':', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: _ink))),
            _qBox(size: 50),
          ],
        ),
      ),
    ]);
  }

  // ── 6. Geo Completion ──────────────────────────────────────────────────────
  Widget _geoCompletion() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Which option completes this figure?'),
      const SizedBox(height: 12),
      _fig(target, size: 100),
    ]);
  }

  // ── 7. Mirror Shape ────────────────────────────────────────────────────────
  Widget _mirrorShape() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Find the left-right mirror image'),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _fig(target, size: 80),
        const SizedBox(width: 20),
        _mirrorLine(),
        const SizedBox(width: 20),
        _qBox(size: 80),
      ]),
    ]);
  }

  // ── 8. Mirror Text / Clock ─────────────────────────────────────────────────
  Widget _mirrorTextQ() {
    final orig = Map<String, dynamic>.from(puzzle)
      ..['mirror_h'] = false
      ..['mirror_v'] = false
      ..['type'] = 'mirror_text';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Find the mirror image'),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        CustomPaint(size: const Size(80, 80), painter: MirrorTextPainter(orig)),
        const SizedBox(width: 20),
        _mirrorLine(),
        const SizedBox(width: 20),
        _qBox(size: 80),
      ]),
    ]);
  }

  // ── 9. Punch Hole ──────────────────────────────────────────────────────────
  Widget _punchHole() =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        _label(
            'The paper is folded and a hole is punched.\nWhich shows the unfolded result?'),
        const SizedBox(height: 14),
        CustomPaint(size: const Size(120, 120), painter: PunchPainter(puzzle)),
      ]);

  // ── 10. Embedded Figure ────────────────────────────────────────────────────
  Widget _embedded() {
    final target = Map<String, dynamic>.from(puzzle['target'] as Map);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _label('Which option contains this shape hidden inside it?'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withOpacity(0.4)),
        ),
        child: _fig(target, size: 56),
      ),
    ]);
  }
}