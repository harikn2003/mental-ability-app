import 'dart:math';

import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../engine/explanation.dart';
import '../engine/reasoning_question.dart';
import '../painters/line_figure_painter.dart';
import '../painters/punch_painter.dart';
import 'question_renderer.dart';

/// Shown under the result after a wrong, skipped or timed-out answer: the
/// rule acted out on the question's own figure (the figure flips over the
/// mirror, the paper unfolds, the hidden shape lights up), ending on the
/// correct option. No words, so it reads the same in every language.
class ExplanationPanel extends StatefulWidget {
  final ReasoningQuestion question;

  /// Called each time the animation finishes (also after a replay).
  final VoidCallback? onFinished;

  const ExplanationPanel({super.key, required this.question, this.onFinished});

  static bool has(ReasoningQuestion q) => Explanation.of(q) != null;

  @override
  State<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<ExplanationPanel> with SingleTickerProviderStateMixin {
  static const _green = LineFigurePainter.highlight;
  static const _blue = Color(0xFF195DE6);
  static const double _box = 140;

  late final Explanation? _e = Explanation.of(widget.question);
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onFinished?.call();
      });
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _e == null) return;
    _started = true;
    _play();
  }

  void _play() {
    if (_reduceMotion) {
      // After this frame, so the parent may setState in onFinished.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _c.value = 0;
        _c.value = 1;
      });
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Timeline (fractions of 3 s): hold, motion, cross-fade to the answer, hold.
  double get _motion => Curves.easeInOut.transform(((_c.value - 0.13) / 0.67).clamp(0.0, 1.0));
  double get _fade => ((_c.value - 0.80) / 0.13).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final e = _e;
    if (e == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => switch (e) {
                  MirrorExplanation() => _mirror(e),
                  UnfoldExplanation() => _unfold(e),
                  FoldOverExplanation() => _foldOver(e),
                  EmbeddedExplanation() => _embedded(e),
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.replay_rounded, color: _blue),
            tooltip: AppLocale.s('replay'),
            onPressed: _play,
          ),
        ],
      ),
    );
  }

  /// The answer, framed in green, fading in over [child].
  Widget _withAnswer(Widget child, Map<String, dynamic> answer, double size) => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 1 - _fade, child: child),
          Opacity(
            opacity: _fade,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _green, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: QuestionRenderer.figure(answer, size: size),
            ),
          ),
        ],
      );

  Widget _mirror(MirrorExplanation e) {
    final double sz = e.figure['type'] == 'mirror_text' ? 80 : 88;
    const gap = 16.0, line = 3.0;
    final width = sz * 2 + gap * 2 + line;
    final flip = 1 - 2 * _motion; // 1 -> -1: over the mirror line
    return SizedBox(
      width: width,
      height: sz + 6,
      child: Stack(
        children: [
          Positioned(left: 0, top: 3, child: QuestionRenderer.figure(e.figure, size: sz)),
          Positioned(
            left: sz + gap,
            top: 3 + sz * 0.1,
            child: Container(width: line, height: sz * 0.8, color: _blue.withValues(alpha: 0.6)),
          ),
          // The copy that flips; it lands exactly on the answer's slot.
          Positioned(
            left: 0,
            top: 3,
            child: Opacity(
              opacity: (1 - _fade) * (_c.value < 0.13 ? 0.0 : 1.0),
              child: Transform(
                transform: Matrix4.diagonal3Values(flip, 1, 1),
                origin: Offset(width / 2, 0),
                child: QuestionRenderer.figure(e.figure, size: sz),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Opacity(
              opacity: _fade,
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: _green, width: 3), borderRadius: BorderRadius.circular(10)),
                child: QuestionRenderer.figure(e.answer, size: sz),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unfold(UnfoldExplanation e) => _withAnswer(
        CustomPaint(
          size: const Size.square(_box),
          painter: UnfoldPainter(folds: e.folds, stages: e.stages, progress: _motion * e.folds.length),
        ),
        e.answer,
        _box,
      );

  Widget _foldOver(FoldOverExplanation e) {
    Widget half(bool left) => ClipRect(
          clipper: _HalfClip(left),
          child: CustomPaint(size: const Size.square(_box), painter: LineFigurePainter(e.sheet)),
        );
    return _withAnswer(
      SizedBox.square(
        dimension: _box,
        child: Stack(
          children: [
            half(true),
            // The right half swings over the fold line (the sheet's middle).
            Transform(
              transform: Matrix4.diagonal3Values(cos(pi * _motion), 1, 1),
              origin: const Offset(_box / 2, 0),
              child: half(false),
            ),
          ],
        ),
      ),
      e.answer,
      _box,
    );
  }

  Widget _embedded(EmbeddedExplanation e) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: _green.withValues(alpha: _motion), width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: QuestionRenderer.figure({
          ...e.answer,
          if (e.shapeIndex != null) 'highlight': e.shapeIndex,
          if (e.segs != null) 'highlight_segs': e.segs,
          'dim': _motion,
        }, size: _box),
      );
}

class _HalfClip extends CustomClipper<Rect> {
  final bool left;
  const _HalfClip(this.left);

  @override
  Rect getClip(Size size) => left ? Rect.fromLTWH(0, 0, size.width / 2, size.height) : Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_HalfClip old) => old.left != left;
}
