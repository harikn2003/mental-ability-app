import '../config/localization.dart';
import 'reasoning_question.dart';

/// Stores everything about one answered question for the review screen.
class QuestionAttempt {
  final int questionNumber; // 1-based
  final ReasoningQuestion question;
  final int? selectedIndex; // null = skipped / timed-out
  final bool isCorrect;
  final bool wasSkipped;
  final int timeSpentSeconds;

  const QuestionAttempt({
    required this.questionNumber,
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
    required this.wasSkipped,
    required this.timeSpentSeconds,
  });

  /// Human-readable category label — respects current app language
  String get categoryLabel {
    const keyMap = {
      'odd_man': 'cat_odd_man',
      'figure_match': 'cat_fig_match',
      'pattern': 'cat_pattern',
      'figure_series': 'cat_fig_series',
      'analogy': 'cat_analogy',
      'geo_completion': 'cat_geo',
      'mirror_shape': 'cat_mirror_shape',
      'mirror_text': 'cat_mirror_text',
      'punch_hole': 'cat_punch',
      'embedded': 'cat_embedded',
    };
    final key = keyMap[question.category];
    return key != null ? AppLocale.s(key) : question.category;
  }
}