import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/morph.dart';
import '../engine/scene.dart';
import '../painters/line_figure_painter.dart';
import 'question_renderer.dart';

/// Draws a [Scene] at [progress] (0..1). Stateless: the explanation panel's
/// animation drives [progress]. Every figure is drawn by the app's own
/// renderer; frames in between are real figure maps from [Morph.frame].
class ScenePlayer extends StatelessWidget {
  final Scene scene;
  final double progress;

  const ScenePlayer({super.key, required this.scene, required this.progress});

  /// Share of the timeline before the first step (the question as asked).
  static const double leadIn = 0.06;

  static const _green = LineFigurePainter.highlight;
  static const _grey = Color(0xFFE2E8F0);
  static const _subtle = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final contents = [for (final s in scene.slots) s.figure];
    final overrides = <int, Widget>{};
    final borders = <int, Color>{};
    final ticks = <int, (int, int, Color)>{}; // slot -> (shown, of, colour)
    final flying = <Widget>[];
    var reveal = 0.0;

    void play(SceneStep step, double local, bool done) {
      final e = Curves.easeInOut.transform(local);
      switch (step) {
        case MorphStep(:final slot, :final beats):
          if (!done) overrides[slot] = beatsView(beats, e, scene.slots[slot].size);
        case FlyStep(:final from, :final to, :final beats):
          if (!done) {
            final a = scene.slots[from], b = scene.slots[to];
            final size = a.size + (b.size - a.size) * e;
            final at = Offset.lerp(a.at, b.at, e)!;
            final fig = step.figure ?? contents[from];
            flying.add(Positioned(
              left: at.dx,
              top: at.dy,
              child: beats.isEmpty ? _figure(fig, size) : beatsView(beats, e, size),
            ));
          }
        case PulseStep(:final slots, :final colour, :final stay):
          for (final s in slots) {
            if (done) {
              if (stay) borders[s] = colour;
            } else {
              borders[s] = colour.withValues(alpha: stay ? max(sin(pi * local), local) : sin(pi * local));
            }
          }
        case TickStep(:final slot, :final count, :final colour):
          ticks[slot] = (done ? count : (local * count).ceil(), count, colour);
        case TogetherStep(:final steps):
          for (final s in steps) {
            play(s, local, done);
          }
        case RevealStep():
          reveal = done ? 1 : local;
      }
      if (done) step.apply(contents);
    }

    var start = leadIn;
    final total = scene.totalWeight;
    for (final step in scene.steps) {
      final span = (1 - leadIn) * step.weight / total;
      if (progress < start) break;
      final local = span <= 0 ? 1.0 : ((progress - start) / span).clamp(0.0, 1.0);
      play(step, local, local >= 1);
      start += span;
    }

    final children = <Widget>[];
    for (int i = 0; i < scene.slots.length; i++) {
      final slot = scene.slots[i];
      Widget body = overrides[i] ??
          (contents[i] == null
              ? (slot.question ? _qBox(slot.size) : SizedBox.square(dimension: slot.size))
              : _figure(contents[i], slot.size));
      final border = i == scene.answerSlot && reveal > 0 ? _green.withValues(alpha: reveal) : borders[i];
      if (border != null) {
        body = Container(
          decoration: BoxDecoration(border: Border.all(color: border, width: 3), borderRadius: BorderRadius.circular(8)),
          child: body,
        );
      }
      children.add(Positioned(left: slot.at.dx - (border != null ? 3 : 0), top: slot.at.dy - (border != null ? 3 : 0), child: body));
      final t = ticks[i];
      if (t != null) {
        children.add(Positioned(left: slot.at.dx, top: slot.at.dy + slot.size + 6, width: slot.size, child: _ticks(t.$1, t.$3)));
      }
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: scene.extent.width,
        height: scene.extent.height,
        child: Stack(clipBehavior: Clip.none, children: [...children, ...flying]),
      ),
    );
  }

  static Widget _figure(Map<String, dynamic>? fig, double size) =>
      fig == null ? SizedBox.square(dimension: size) : QuestionRenderer.figure(fig, size: size);

  static Widget _qBox(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
        child: Center(child: Text('?', style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.bold, color: _subtle))),
      );

  static Widget _ticks(int n, Color colour) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 4,
        children: [for (int i = 0; i < n; i++) Container(width: 4, height: 12, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)))],
      );

  /// [beats] played one after another, [t] (0..1) through all of them.
  static Widget beatsView(List<Beat> beats, double t, double size) {
    if (beats.isEmpty) return SizedBox.square(dimension: size);
    final n = beats.length;
    final i = min((t * n).floor(), n - 1);
    return beatView(beats[i], (t * n - i).clamp(0.0, 1.0), size);
  }

  static Widget beatView(Beat beat, double t, double size) {
    final line = Morph.kindOf(beat.from) == FigureKind.line;
    switch (beat) {
      case FlipBeat() when !line:
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(max(0.02, cos(pi * t).abs()), 1, 1),
          child: _figure(t < 0.5 ? beat.from : beat.to, size),
        );
      case SwapBeat():
        return _crossFade(beat.from, beat.to, t, size);
      case RegroupBeat(:final pieces):
        final s = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
        return SizedBox.square(
          dimension: size,
          child: Stack(children: [
            for (final (a, b) in pieces) ...[
              _placed(a, _lineBox(a, size), Rect.lerp(_lineBox(a, size), _lineBox(b, size), t)!, size, 1 - s),
              _placed(b, _lineBox(b, size), Rect.lerp(_lineBox(a, size), _lineBox(b, size), t)!, size, s),
            ],
          ]),
        );
      default:
        return _figure(Morph.frame(beat, t), size);
    }
  }

  /// [a] fading into [b], with a green glow while it changes.
  static Widget _crossFade(Map<String, dynamic> a, Map<String, dynamic> b, double t, double size) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.35 * sin(pi * t)), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Stack(children: [
          Opacity(opacity: 1 - t, child: _figure(a, size)),
          Opacity(opacity: t, child: _figure(b, size)),
        ]),
      );

  /// [fig] (drawn in a [size] box, its content at [box]) moved and scaled so
  /// its content lands on [to].
  static Widget _placed(Map<String, dynamic> fig, Rect box, Rect to, double size, double opacity) {
    final sx = box.width > 0 ? to.width / box.width : (box.height > 0 ? to.height / box.height : 1.0);
    final sy = box.height > 0 ? to.height / box.height : sx;
    final m = Matrix4.identity()
      ..translateByDouble(to.left - box.left * sx, to.top - box.top * sy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1);
    return Opacity(opacity: opacity, child: Transform(transform: m, child: _figure(fig, size)));
  }

  /// Where a line figure's content is drawn in a [size] square (the same
  /// layout rule as [LineFigurePainter]).
  static Rect _lineBox(Map<String, dynamic> fig, double size) {
    final w = (fig['w'] as num).toDouble(), h = (fig['h'] as num).toDouble();
    final pad = size * 0.12;
    final unit = min((size - 2 * pad) / w, (size - 2 * pad) / h);
    final ox = (size - unit * w) / 2, oy = (size - unit * h) / 2;
    final xs = <double>[], ys = <double>[];
    for (final s in fig['segs'] as List? ?? const []) {
      final l = (s as List).cast<num>();
      xs..add(l[0].toDouble())..add(l[2].toDouble());
      ys..add(l[1].toDouble())..add(l[3].toDouble());
    }
    for (final a in fig['arcs'] as List? ?? const []) {
      final l = (a as List).cast<num>();
      final (cx, cy, r) = (l[0] / 2, l[1] / 2, l[2] / 2);
      xs..add(cx - r)..add(cx + r);
      ys..add(cy - r)..add(cy + r);
    }
    if (xs.isEmpty) return Rect.fromLTWH(0, 0, size, size);
    return Rect.fromLTRB(ox + xs.reduce(min) * unit, oy + ys.reduce(min) * unit, ox + xs.reduce(max) * unit, oy + ys.reduce(max) * unit);
  }
}
