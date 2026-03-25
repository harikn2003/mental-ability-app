class ReasoningQuestion {
  final String category;
  final String type;

  final Map<String, dynamic> puzzle;

  final List<Map<String, dynamic>> options;

  final int correctIndex;

  ReasoningQuestion({
    required this.category,
    required this.type,
    required this.puzzle,
    required this.options,
    required this.correctIndex,
  });
}
