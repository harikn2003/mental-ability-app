class Question {
  final String id;
  final String category;
  final String imagePath;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.id,
    required this.category,
    required this.imagePath,
    required this.options,
    required this.correctIndex,
  });
}
