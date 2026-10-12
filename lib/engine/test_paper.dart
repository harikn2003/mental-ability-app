import 'dart:math';

import 'difficulty.dart';
import 'question_generator.dart';
import 'reasoning_question.dart';

/// One part of a printed paper: four questions of one kind, easy to hard.
class PaperPart {
  final String id;
  final List<ReasoningQuestion> questions;
  final List<Difficulty> levels;
  const PaperPart(this.id, this.questions, this.levels);
}

/// One student's copy of a paper: the same questions, in a different order
/// within each part's equally hard questions and with the answers moved.
class PaperSet {
  final int number;
  final List<PaperPart> parts;
  const PaperSet(this.number, this.parts);

  /// Correct option (0-3) for questions 1-40.
  List<int> get answerKey => [for (final p in parts) for (final q in p.questions) q.correctIndex];
}

/// A printed test paper modelled on the JNVST Mental Ability Test: 10 parts
/// of 4 questions in the exam's order, each part going easy to hard.
class TestPaper {
  final List<PaperPart> parts;
  const TestPaper(this.parts);

  static const partIds = ['odd_man', 'figure_match', 'pattern', 'figure_series', 'analogy',
      'geo_completion', 'mirror', 'punch_hole', 'space_vis', 'embedded'];

  /// The topic of each question in a part; the mirror part mixes figures
  /// with letters and clocks.
  static const partTopics = {
    'odd_man': ['odd_man', 'odd_man', 'odd_man', 'odd_man'],
    'figure_match': ['figure_match', 'figure_match', 'figure_match', 'figure_match'],
    'pattern': ['pattern', 'pattern', 'pattern', 'pattern'],
    'figure_series': ['figure_series', 'figure_series', 'figure_series', 'figure_series'],
    'analogy': ['analogy', 'analogy', 'analogy', 'analogy'],
    'geo_completion': ['geo_completion', 'geo_completion', 'geo_completion', 'geo_completion'],
    'mirror': ['mirror_shape', 'mirror_text', 'mirror_shape', 'mirror_text'],
    'punch_hole': ['punch_hole', 'punch_hole', 'punch_hole', 'punch_hole'],
    'space_vis': ['space_vis', 'space_vis', 'space_vis', 'space_vis'],
    'embedded': ['embedded', 'embedded', 'embedded', 'embedded'],
  };

  static const partLevels = [Difficulty.easy, Difficulty.medium, Difficulty.medium, Difficulty.hard];

  static TestPaper generate({int? seed}) {
    if (seed != null) QuestionGenerator.seed(seed);
    QuestionGenerator.resetSession(); // no repeats within the paper
    return TestPaper([
      for (final id in partIds)
        PaperPart(id, [
          for (int i = 0; i < 4; i++) QuestionGenerator.generate(partTopics[id]![i], difficulty: partLevels[i]),
        ], partLevels),
    ]);
  }

  /// One copy per student. Questions only swap places with equally hard
  /// ones, so every part still goes easy to hard; the options are shuffled
  /// in every question.
  List<PaperSet> sets(int students, {int? seed}) {
    final r = Random(seed);
    return [
      for (int n = 1; n <= students; n++)
        PaperSet(n, [
          for (final p in parts)
            () {
              final order = [for (int i = 0; i < p.questions.length; i++) i];
              // Shuffle each run of equal levels in place.
              for (int i = 0; i < order.length;) {
                int j = i;
                while (j < order.length && p.levels[j] == p.levels[i]) {
                  j++;
                }
                final run = order.sublist(i, j)..shuffle(r);
                order.setRange(i, j, run);
                i = j;
              }
              return PaperPart(p.id, [for (final i in order) _shuffleOptions(p.questions[i], r)], [for (final i in order) p.levels[i]]);
            }(),
        ]),
    ];
  }

  static ReasoningQuestion _shuffleOptions(ReasoningQuestion q, Random r) {
    final perm = [for (int i = 0; i < q.options.length; i++) i]..shuffle(r);
    return ReasoningQuestion(
      category: q.category,
      type: q.type,
      puzzle: q.puzzle,
      options: [for (final i in perm) q.options[i]],
      correctIndex: perm.indexOf(q.correctIndex),
    );
  }
}
