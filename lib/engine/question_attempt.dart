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

  /// Human-readable category label
  String get categoryLabel {
    const labels = {
      'odd_man': 'Odd Man Out',
      'figure_match': 'Figure Match',
      'pattern': 'Pattern Completion',
      'figure_series': 'Figure Series',
      'analogy': 'Analogy',
      'geo_completion': 'Geo Completion',
      'mirror_shape': 'Mirror Shape',
      'mirror_text': 'Mirror Text',
      'punch_hole': 'Punch Hole',
      'embedded': 'Embedded Figure',
    };
    return labels[question.category] ?? question.category;
  }
}
