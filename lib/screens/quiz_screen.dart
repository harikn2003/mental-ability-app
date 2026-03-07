import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mental_ability_app/config/localization.dart';

import '../engine/reasoning_generator.dart';
import '../engine/reasoning_question.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';
import 'session_summary_screen.dart';

class QuizScreen extends StatefulWidget {
  final String mode;
  final int totalQuestions;
  final String timePerQuestion;

  const QuizScreen({
    super.key,
    required this.mode,
    required this.totalQuestions,
    required this.timePerQuestion,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {

  List<ReasoningQuestion> sessionQuestions = [];

  int currentQuestionIndex = 0;
  String? selectedOption;

  bool isAnswered = false;
  bool isCorrect = false;

  int remainingSeconds = 0;
  int secondsElapsedForCurrent = 0;

  Timer? _timer;

  int score = 0;

  List<int> timeSpentPerQuestion = [];

  Map<String, List<bool>> categoryPerformance = {};

  Map<String, int> categoryWeights = {
    'pattern': 1,
    'analogy': 1,
    'odd_man': 1,
    'mirror': 1,
  };

  final String currentLang = 'EN';

  static const Color primary = Color(0xFF195DE6);
  static const Color background = Color(0xFFF6F6F8);
  static const Color surface = Colors.white;
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _startTimer();
  }

  String pickBiasedCategory() {
    int totalWeight = categoryWeights.values.reduce((a, b) => a + b);

    int randomValue = Random().nextInt(totalWeight);

    int cumulative = 0;

    for (var entry in categoryWeights.entries) {
      cumulative += entry.value;

      if (randomValue < cumulative) {
        return entry.key;
      }
    }

    return categoryWeights.keys.first;
  }

  void _loadQuestions() {
    sessionQuestions = [];

    for (int i = 0; i < widget.totalQuestions; i++) {
      String category = pickBiasedCategory();

      sessionQuestions.add(
        ReasoningGenerator.generate(category),
      );
    }
  }

  void _startTimer() {

    _timer?.cancel();

    secondsElapsedForCurrent = 0;

    if (widget.timePerQuestion == '30s') {
      remainingSeconds = 30;
    }
    else if (widget.timePerQuestion == '2m') {
      remainingSeconds = 120;
    }
    else {
      remainingSeconds = -1;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsElapsedForCurrent++;

      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      }

      else if (remainingSeconds == 0) {

        _timer?.cancel();

        if (!isAnswered) {
          _recordAnswer(false, null);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleOptionTap(String option) {

    if (isAnswered) return;

    int selected = int.parse(option);

    bool answeredCorrectly =
        selected == sessionQuestions[currentQuestionIndex].correctIndex;

    _recordAnswer(answeredCorrectly, option);
  }

  void _recordAnswer(bool correct, String? optionSelected) {

    _timer?.cancel();

    final currentCategory =
        sessionQuestions[currentQuestionIndex].category;

    setState(() {

      isAnswered = true;
      selectedOption = optionSelected;
      isCorrect = correct;

      if (correct) {
        score++;
      } else {
        categoryWeights[currentCategory] =
            min(categoryWeights[currentCategory]! + 1, 10);
      }

      timeSpentPerQuestion.add(secondsElapsedForCurrent);

      categoryPerformance
          .putIfAbsent(currentCategory, () => [])
          .add(correct);
    });
  }

  void _nextQuestion() {

    if (currentQuestionIndex < sessionQuestions.length - 1) {

      setState(() {

        currentQuestionIndex++;

        isAnswered = false;
        selectedOption = null;
        isCorrect = false;

        _startTimer();
      });
    }

    else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SessionSummaryScreen(
            score: score,
            totalQuestions: sessionQuestions.length,
            timeSpent: timeSpentPerQuestion,
            categoryStats: categoryPerformance,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sessionQuestions.isEmpty) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: Text("No questions generated")),
      );
    }

    final currentQuestion =
    sessionQuestions[currentQuestionIndex];

    double progress =
        (currentQuestionIndex + 1) / sessionQuestions.length;

    return Scaffold(

      backgroundColor: background,

      body: SafeArea(
        child: Column(
          children: [

            _buildHeader(progress),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [

                    _buildQuestionFigure(currentQuestion),

                    const SizedBox(height: 24),

                    _buildOptions(currentQuestion),

                    const SizedBox(height: 24),

                    if (isAnswered)
                      _buildResultMessage(currentQuestion),
                  ],
                ),
              ),
            )
          ],
        ),
      ),

      floatingActionButton: isAnswered
          ? FloatingActionButton.extended(
        onPressed: _nextQuestion,
        backgroundColor: primary,
        label: Text(
          AppLocale.get(currentLang, 'next_question'),
        ),
      )
          : null,
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: surface,
      child: Column(
        children: [

          LinearProgressIndicator(
            value: progress,
            color: primary,
          ),

          const SizedBox(height: 8),

          Text(
            "Q ${currentQuestionIndex + 1} / ${sessionQuestions.length}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionFigure(ReasoningQuestion question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: QuestionRenderer(
        puzzle: question.puzzle,
      ),
    );
  }

  Widget _buildOptions(ReasoningQuestion question) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: List.generate(
        4,
            (index) => _buildOptionCard(index, question),
      ),
    );
  }

  Widget _buildOptionCard(int index, ReasoningQuestion question) {
    Map<String, dynamic> optionData = question.options[index];

    bool isSelected = selectedOption == index.toString();
    bool isCorrectOption = index == question.correctIndex;

    Color bgColor = surface;
    Color borderColor = Colors.grey.shade300;

    if (isAnswered) {
      if (isCorrectOption) {
        bgColor = success.withOpacity(0.2);
        borderColor = success;
      }

      else if (isSelected) {
        bgColor = error.withOpacity(0.2);
        borderColor = error;
      }
    }

    return GestureDetector(

      onTap: () => _handleOptionTap(index.toString()),

      child: Container(

        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),

        child: Center(
          child: OptionRenderer(
            data: optionData,
          ),
        ),
      ),
    );
  }

  Widget _buildResultMessage(ReasoningQuestion question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? success.withOpacity(0.1) : error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isCorrect
            ? "Correct!"
            : "Incorrect. Correct answer: ${question.correctIndex + 1}",
        style: TextStyle(
          color: isCorrect ? success : error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}