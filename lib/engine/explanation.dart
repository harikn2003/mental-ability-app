import 'dart:convert';

import 'line_figure.dart';
import 'paper_fold.dart';
import 'reasoning_question.dart';
import 'scene.dart';

/// What the answer explanation animates for a question, worked out from the
/// puzzle and its correct option (so it also works for sessions saved before
/// explanations existed). `test/explanation_test.dart` checks, for hundreds
/// of generated questions, that each one re-derives the correct option.
sealed class Explanation {
  /// The correct option; the animation's last frame.
  final Map<String, dynamic> answer;
  const Explanation(this.answer);

  /// How long the animation plays.
  Duration get duration => const Duration(seconds: 3);

  /// The explanation for [q], or null for a topic without one or a question
  /// whose data doesn't fit (never throws).
  static Explanation? of(ReasoningQuestion q) {
    try {
      if (q.correctIndex < 0 || q.correctIndex >= q.options.length) return null;
      final answer = _map(q.options[q.correctIndex]);
      final puzzle = _map(q.puzzle);
      return switch (q.category) {
        'mirror_shape' || 'mirror_text' => _mirror(puzzle, answer),
        'punch_hole' => _punch(puzzle, answer),
        'embedded' => _embedded(puzzle, answer),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _map(Object? m) => Map<String, dynamic>.from(m as Map);

  static Explanation? _mirror(Map<String, dynamic> puzzle, Map<String, dynamic> answer) {
    if (puzzle['type'] == 'mirror_text') {
      return MirrorExplanation({...puzzle, 'type': 'mirror_text', 'mirror_h': false, 'mirror_v': false}, answer);
    }
    final target = puzzle['target'];
    return target is Map ? MirrorExplanation(_map(target), answer) : null;
  }

  static Explanation? _punch(Map<String, dynamic> puzzle, Map<String, dynamic> answer) {
    if (puzzle['type'] == 'paper_fold') {
      final sheet = puzzle['sheet'];
      return sheet is Map ? FoldOverExplanation(_map(sheet), answer) : null;
    }
    final holes = puzzle['holes'] as List?;
    if (holes == null || answer['holes'] is! List) return null;
    final folds = PaperFold.foldsOf(puzzle);
    return UnfoldExplanation(folds, [
      for (int k = 0; k <= folds.length; k++) PaperFold.unfold(holes, folds.sublist(k)),
    ], answer);
  }

  static Explanation? _embedded(Map<String, dynamic> puzzle, Map<String, dynamic> answer) {
    final target = puzzle['target'];
    if (target is! Map) return null;
    if (answer['type'] == 'embedded_option') {
      final key = jsonEncode(target);
      final shapes = answer['shapes'] as List;
      final i = shapes.indexWhere((s) => jsonEncode(s) == key);
      return i < 0 ? null : EmbeddedExplanation(answer, shapeIndex: i);
    }
    if (answer['type'] == 'line_fig') {
      final placed = LineFig.fromMap(answer).embedding(LineFig.fromMap(_map(target)));
      if (placed == null) return null;
      return EmbeddedExplanation(answer, segs: [for (final (a, b, c, d) in placed) [a, b, c, d]]);
    }
    return null;
  }
}

/// The figure flips over the mirror line onto the answer.
final class MirrorExplanation extends Explanation {
  final Map<String, dynamic> figure;
  const MirrorExplanation(this.figure, Map<String, dynamic> answer) : super(answer);
}

/// The folded, punched paper opens fold by fold (last fold first).
/// `stages[k]` is the holes while `k` folds are still closed, so
/// `stages[folds.length]` is the punched paper and `stages[0]` the answer.
final class UnfoldExplanation extends Explanation {
  final List<String> folds;
  final List<List<Map<String, dynamic>>> stages;
  const UnfoldExplanation(this.folds, this.stages, Map<String, dynamic> answer) : super(answer);
}

/// The see-through sheet's right half folds over onto the left half.
final class FoldOverExplanation extends Explanation {
  final Map<String, dynamic> sheet;
  const FoldOverExplanation(this.sheet, Map<String, dynamic> answer) : super(answer);
}

/// The hidden figure lights up inside the answer: [shapeIndex] for a
/// three-shape option, [segs] (`[a, b, c, d]` lines) for a line drawing.
final class EmbeddedExplanation extends Explanation {
  final int? shapeIndex;
  final List<List<int>>? segs;
  const EmbeddedExplanation(super.answer, {this.shapeIndex, this.segs});
}

/// An explanation acted out as a [Scene] (Figure Series, Analogy, Pattern,
/// Odd Man Out, Figure Match, Geo Completion, Space Visualisation).
class SceneExplanation extends Explanation {
  final Scene scene;
  const SceneExplanation(this.scene, super.answer);

  @override
  Duration get duration => scene.duration;
}
