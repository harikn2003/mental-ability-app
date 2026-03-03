// lib/questions.dart

class Question {
  final String id;
  final String category;
  final String imagePath;
  final String correctOption;

  Question({
    required this.id,
    required this.category,
    required this.imagePath,
    required this.correctOption,
  });
}

class QuestionResult {
  final Question question;
  final bool isCorrect;
  final int timeTakenSeconds;

  QuestionResult({
    required this.question,
    required this.isCorrect,
    required this.timeTakenSeconds,
  });
}

// MASTER LIST OF QUESTIONS
final List<Question> allQuestions = [
  // --- PATTERN COMPLETION (20 Questions) ---
  // TODO: Update 'correctOption' for each line below according to your real answer key!
  Question(
    id: 'p1',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p1.png',
    correctOption: 'A',
  ),
  Question(
    id: 'p2',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p2.png',
    correctOption: 'B',
  ),
  Question(
    id: 'p3',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p3.png',
    correctOption: 'C',
  ),
  Question(
    id: 'p4',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p4.png',
    correctOption: 'D',
  ),
  Question(
    id: 'p5',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p5.png',
    correctOption: 'A',
  ),
  Question(
    id: 'p6',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p6.png',
    correctOption: 'B',
  ),
  Question(
    id: 'p7',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p7.png',
    correctOption: 'C',
  ),
  Question(
    id: 'p8',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p8.png',
    correctOption: 'D',
  ),
  Question(
    id: 'p9',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p9.png',
    correctOption: 'A',
  ),
  Question(
    id: 'p10',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p10.png',
    correctOption: 'B',
  ),
  Question(
    id: 'p11',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p11.png',
    correctOption: 'C',
  ),
  Question(
    id: 'p12',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p12.png',
    correctOption: 'D',
  ),
  Question(
    id: 'p13',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p13.png',
    correctOption: 'A',
  ),
  Question(
    id: 'p14',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p14.png',
    correctOption: 'B',
  ),
  Question(
    id: 'p15',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p15.png',
    correctOption: 'C',
  ),
  Question(
    id: 'p16',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p16.png',
    correctOption: 'D',
  ),
  Question(
    id: 'p17',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p17.png',
    correctOption: 'A',
  ),
  Question(
    id: 'p18',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p18.png',
    correctOption: 'B',
  ),
  Question(
    id: 'p19',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p19.png',
    correctOption: 'C',
  ),
  Question(
    id: 'p20',
    category: 'pattern',
    imagePath: 'assets/questions/pattern/p20.png',
    correctOption: 'D',
  ),
];
