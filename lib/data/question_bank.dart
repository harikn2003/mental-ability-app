import '../models/question.dart';

class QuestionBank {
  static List<Question> allQuestions = [
    Question(
      id: "p1",
      category: "Odd Man Out",
      imagePath: "assets/questions/pattern/p1.png",
      options: ["A", "B", "C", "D"],
      correctIndex: 2,
    ),
    Question(
      id: "p2",
      category: "Analogy",
      imagePath: "assets/questions/pattern/p2.png",
      options: ["A", "B", "C", "D"],
      correctIndex: 1,
    ),
  ];
}
