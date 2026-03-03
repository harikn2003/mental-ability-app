import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:mental_ability_app/questions/questions.dart';

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
  // --- STATE ---
  List<Question> sessionQuestions = [];
  int currentQuestionIndex = 0;
  String? selectedOption;
  bool isAnswered = false;
  bool isCorrect = false;

  // TIMER & TRACKING STATE
  int remainingSeconds = 0;
  int secondsElapsedForCurrent = 0;
  Timer? _timer;

  // ANALYTICS DATA TO PASS
  int score = 0;
  List<int> timeSpentPerQuestion = [];
  Map<String, List<bool>> categoryPerformance =
      {}; // Tracks [true, false, true] per category

  final String currentLang = 'EN';

  // --- THEME COLORS ---
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

  void _loadQuestions() {
    if (widget.mode == 'random') {
      List<Question> shuffled = List.from(allQuestions)..shuffle();
      sessionQuestions = shuffled.take(widget.totalQuestions).toList();
    } else {
      sessionQuestions = allQuestions
          .where((q) => q.category == widget.mode)
          .toList();
      int count = widget.totalQuestions;
      if (sessionQuestions.length < count) count = sessionQuestions.length;
      sessionQuestions = sessionQuestions.take(count).toList();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    secondsElapsedForCurrent = 0; // Reset stopwatch for this question

    if (widget.timePerQuestion == '30s')
      remainingSeconds = 30;
    else if (widget.timePerQuestion == '2m')
      remainingSeconds = 120;
    else
      remainingSeconds = -1; // Unlimited time flag

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsElapsedForCurrent++; // Track exact time spent

      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else if (remainingSeconds == 0) {
        // TIMEOUT LOGIC
        _timer?.cancel();
        if (!isAnswered) {
          _recordAnswer(false, null); // Record as wrong due to timeout
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

    final correctAnswer = sessionQuestions[currentQuestionIndex].correctOption;
    bool answeredCorrectly = (option == correctAnswer);

    _recordAnswer(answeredCorrectly, option);
  }

  void _recordAnswer(bool isAnswerCorrect, String? optionSelected) {
    _timer?.cancel();
    final String currentCategory =
        sessionQuestions[currentQuestionIndex].category;

    setState(() {
      isAnswered = true;
      selectedOption = optionSelected;
      isCorrect = isAnswerCorrect;

      if (isCorrect) score++;

      // Record Analytics Data
      timeSpentPerQuestion.add(secondsElapsedForCurrent);

      // Add result to this category's performance log
      categoryPerformance.putIfAbsent(currentCategory, () => []).add(isCorrect);
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
    } else {
      // END OF QUIZ -> Go to Summary and Pass Data!
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
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Text("No questions found for category: ${widget.mode}"),
        ),
      );
    }

    final currentQuestion = sessionQuestions[currentQuestionIndex];
    double progress = (currentQuestionIndex + 1) / sessionQuestions.length;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: surface,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                      if (widget.timePerQuestion != 'Unlimited' &&
                          remainingSeconds >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer, size: 18, color: primary),
                              const SizedBox(width: 8),
                              Text(
                                "${remainingSeconds}s",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: background,
                      color: primary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Q ${currentQuestionIndex + 1} / ${sessionQuestions.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppLocale.get(
                              currentLang,
                              'question_figure',
                            ).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              currentQuestion.imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "Image not found\nCheck assets path",
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: ['A', 'B', 'C', 'D']
                          .map(
                            (opt) => _buildOptionCard(
                              opt,
                              currentQuestion.correctOption,
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    if (isAnswered)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? success.withOpacity(0.1)
                              : error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCorrect ? success : error,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? success : error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isCorrect
                                    ? "Correct Answer!"
                                    : "Incorrect. The answer is ${currentQuestion.correctOption}.",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? success : error,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isAnswered
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              child: FloatingActionButton.extended(
                onPressed: _nextQuestion,
                backgroundColor: primary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                label: Row(
                  children: [
                    Text(
                      AppLocale.get(currentLang, 'next_question'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildOptionCard(String option, String correctAnswer) {
    bool isSelected = selectedOption == option;
    Color bgColor = surface;
    Color borderColor = Colors.grey.withOpacity(0.2);
    Color textColor = Colors.grey;

    if (isAnswered) {
      if (option == correctAnswer) {
        bgColor = success;
        borderColor = success;
        textColor = Colors.white;
      } else if (isSelected) {
        bgColor = error;
        borderColor = error;
        textColor = Colors.white;
      }
    } else if (isSelected) {
      borderColor = primary;
      textColor = primary;
    }

    return GestureDetector(
      onTap: () => _handleOptionTap(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          option,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
