import 'package:hive/hive.dart';

part 'session_record.g.dart';

/// Stores a summary of one completed session for the history screen.
/// Hive typeId 0 — do not change once deployed.
@HiveType(typeId: 0)
class SessionRecord extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int score;

  @HiveField(2)
  final int totalQuestions;

  @HiveField(3)
  final int skipped;

  @HiveField(4)
  final String mode; // 'random', 'odd_man', 'weak_areas', etc.

  @HiveField(5)
  final Map<String, int> categoryCorrect; // category → correct count

  @HiveField(6)
  final Map<String, int> categoryTotal; // category → total attempted

  @HiveField(7)
  final int avgTimeSeconds;

  SessionRecord({
    required this.date,
    required this.score,
    required this.totalQuestions,
    required this.skipped,
    required this.mode,
    required this.categoryCorrect,
    required this.categoryTotal,
    required this.avgTimeSeconds,
  });

  double get accuracy => totalQuestions > 0 ? score / totalQuestions : 0.0;

  String get modeLabel {
    const m = {
      'random': 'Random Mix',
      'weak_areas': 'Weak Areas',
      'odd_man': 'Odd Man Out',
      'figure_match': 'Figure Match',
      'pattern': 'Pattern',
      'figure_series': 'Figure Series',
      'analogy': 'Analogy',
      'geo_completion': 'Geo Completion',
      'mirror_shape': 'Mirror Shape',
      'mirror_text': 'Mirror Text',
      'punch_hole': 'Punch Hole',
      'embedded': 'Embedded Figure',
    };
    return m[mode] ?? mode;
  }
}
