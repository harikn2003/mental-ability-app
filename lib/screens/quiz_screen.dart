import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hive_service.dart';
import '../data/session_record.dart';
import '../engine/question_attempt.dart';
import '../engine/question_generator.dart';
import '../engine/reasoning_question.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';
import 'student_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String mode;
  final int totalQuestions;
  final String timePerQuestion;
  final bool biasEnabled;
  final Map<String, int> initialWeights; // persisted from previous session
  final List<ReasoningQuestion> retryQuestions;

  const QuizScreen({
    super.key,
    required this.mode,
    required this.totalQuestions,
    required this.timePerQuestion,
    this.biasEnabled = true,
    this.initialWeights = const {},
    this.retryQuestions = const [],
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  // ── Session state ─────────────────────────────────────────────────────────
  // Questions are generated ONE AT A TIME so bias weights are always current.
  // We keep already-seen signatures to avoid exact duplicates.
  final List<ReasoningQuestion> _questions = [];
  final List<QuestionAttempt> _attempts = [];
  final Set<String> _seenSignatures = {};

  int currentQuestionIndex = 0;
  String? selectedOption;
  bool isAnswered = false;
  bool isCorrect = false;
  int skippedCount = 0;
  bool _nextLocked = false; // true for 1.2s after wrong answer
  bool _showBiasChart = false; // coordinator toggle for bias weight chart
  bool _timedOut = false; // true when timer expired on current question

  // ── Timer ─────────────────────────────────────────────────────────────────
  int remainingSeconds = 0;
  int secondsElapsedForCurrent = 0;
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Scoring ───────────────────────────────────────────────────────────────
  int score = 0;
  List<int> timeSpentPerQuestion = [];
  Map<String, List<bool>> categoryPerformance = {};

  // ── Bias weights ──────────────────────────────────────────────────────────
  // Initialised from widget.initialWeights (loaded from SharedPreferences).
  // Falls back to 1 for any category not yet in storage.
  // Wrong answer / skip → weight += 2 (up to max 10)
  // Correct answer      → weight -= 1 (down to min 1)
  // Saved to SharedPreferences after every change via _saveWeights().
  static const _kWeightsKey = 'bias_weights';
  static const _allCategories = [
    'pattern',
    'analogy',
    'odd_man',
    'mirror_shape',
    'figure_match',
    'figure_series',
    'geo_completion',
    'mirror_text',
    'punch_hole',
    'embedded',
  ];

  static const _linearOrder = _allCategories;
  int _linearCursor = 0;

  late Map<String, int> _weights;

  // ── Constants ─────────────────────────────────────────────────────────────
  String get currentLang =>
      AppLocale.current; // always reflects the globally selected language
  static const Color primary = Color(0xFF195DE6);
  static const Color background = Color(0xFFF6F6F8);
  static const Color surface = Colors.white;
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF97316);

  bool get _hasTimer => widget.timePerQuestion != 'unlimited';

  int get _totalSeconds {
    if (widget.timePerQuestion == '30s') return 30;
    if (widget.timePerQuestion == '2m') return 120;
    return 1;
  }

  // ── Current question shortcut ─────────────────────────────────────────────
  ReasoningQuestion get _currentQ => _questions[currentQuestionIndex];

  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    // Seed weights from persisted values — any category not in storage defaults to 1
    _weights = {
      for (final cat in _allCategories) cat: widget.initialWeights[cat] ?? 1,
    };

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Clear generator history so this session gets fresh questions
    QuestionGenerator.resetSession();

    // Generate ONLY the first question — rest generated on-demand
    _generateNextQuestion();
    _startTimer();
  }

  // Write current weights to SharedPreferences — called after every answer
  Future<void> _saveWeights() async {
    if (!widget.biasEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    // Only save categories that were seeded into this session.
    // If initialWeights was a subset (e.g. weak-areas session), writing all
    // 10 categories would reset the strong ones back to 1. Instead, only
    // update the keys that this session actually knows about.
    final sessionCats = widget.initialWeights.isNotEmpty
        ? widget.initialWeights.keys.toSet()
        : _weights.keys.toSet(); // full session — save everything
    for (final entry in _weights.entries) {
      if (sessionCats.contains(entry.key)) {
        await prefs.setInt('${_kWeightsKey}_${entry.key}', entry.value);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Bias: pick a category ─────────────────────────────────────────────────
  String _pickCategory() {
    if (widget.mode == 'linear') {
      final cat = _linearOrder[_linearCursor % _linearOrder.length];
      _linearCursor++;
      return cat;
    }
    if (widget.mode != 'random') return widget.mode;

    final int total = _weights.values.reduce((a, b) => a + b);
    int roll = Random().nextInt(total);
    for (final entry in _weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return _weights.keys.first;
  }

  // ── Generate a single question, avoiding exact duplicates ─────────────────
  String _canonical(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return '{${entries.map((e) => '${e.key}:${_canonical(e.value)}').join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_canonical).join(',')}]';
    }
    return value.toString();
  }

  String _questionSignature(ReasoningQuestion q) {
    final optionSigs =
        q.options.map((o) => _canonical(Map<String, dynamic>.from(o))).toList()
          ..sort();
    return _canonical({
      'category': q.category,
      'type': q.type,
      'puzzle': q.puzzle,
      'options': optionSigs,
    });
  }

  void _generateNextQuestion() {
    // Retry flow: replay known incorrect questions first.
    if (_questions.length < widget.retryQuestions.length) {
      final retryQ = widget.retryQuestions[_questions.length];
      final sig = _questionSignature(retryQ);
      if (_seenSignatures.add(sig)) {
        _questions.add(retryQ);
        return;
      }
    }

    ReasoningQuestion q;
    int attempts = 0;
    do {
      final category = _pickCategory();
      q = QuestionGenerator.generate(category);
      attempts++;
    } while (_seenSignatures.contains(_questionSignature(q)) && attempts < 40);
    _seenSignatures.add(_questionSignature(q));
    _questions.add(q);
  }

  // ── Update bias weights after each answer ─────────────────────────────────
  void _updateWeights(String category, bool correct) {
    if (!widget.biasEnabled) return;

    setState(() {
      if (correct) {
        _weights[category] = max(1, (_weights[category] ?? 1) - 1);
      } else {
        _weights[category] = min(10, (_weights[category] ?? 1) + 2);
      }
    });

    // Persist immediately — fire-and-forget, doesn't block UI
    _saveWeights();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    secondsElapsedForCurrent = 0;

    if (widget.timePerQuestion == '30s') {
      remainingSeconds = 30;
    } else if (widget.timePerQuestion == '2m') {
      remainingSeconds = 120;
    } else {
      remainingSeconds = -1;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => secondsElapsedForCurrent++);
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else if (remainingSeconds == 0) {
        t.cancel();
        if (!isAnswered) {
          setState(() => _timedOut = true);
          _recordAnswer(false, null);
        }
      }
    });
  }

  // ── Answer handling ───────────────────────────────────────────────────────
  void _handleOptionTap(String option) {
    if (isAnswered) return;
    final selected = int.parse(option);
    _recordAnswer(selected == _currentQ.correctIndex, option);
  }

  void _recordAnswer(bool correct, String? optionSelected) {
    _timer?.cancel();
    final cat = _currentQ.category;
    final selIdx = optionSelected != null ? int.tryParse(optionSelected) : null;
    final timeSecs = secondsElapsedForCurrent;

    // Haptic feedback — distinct patterns for right vs wrong
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
      Future.delayed(
        const Duration(milliseconds: 120),
        HapticFeedback.mediumImpact,
      );
    }

    setState(() {
      isAnswered = true;
      selectedOption = optionSelected;
      isCorrect = correct;
      if (correct) score++;
      timeSpentPerQuestion.add(timeSecs);
      categoryPerformance.putIfAbsent(cat, () => []).add(correct);
      _attempts.add(
        QuestionAttempt(
          questionNumber: currentQuestionIndex + 1,
          question: _currentQ,
          selectedIndex: selIdx,
          isCorrect: correct,
          wasSkipped: false,
          timeSpentSeconds: timeSecs,
        ),
      );
      // Lock Next for 1.2s after wrong answer so student sees the correct option
      if (!correct) {
        _nextLocked = true;
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _nextLocked = false);
        });
      }
    });
    _updateWeights(cat, correct);
  }

  void _skipQuestion() {
    if (isAnswered) return;
    _timer?.cancel();
    final cat = _currentQ.category;
    final timeSecs = secondsElapsedForCurrent;
    setState(() {
      isAnswered = true;
      selectedOption = null;
      isCorrect = false;
      skippedCount++;
      timeSpentPerQuestion.add(timeSecs);
      categoryPerformance.putIfAbsent(cat, () => []).add(false);
      _attempts.add(
        QuestionAttempt(
          questionNumber: currentQuestionIndex + 1,
          question: _currentQ,
          selectedIndex: null,
          isCorrect: false,
          wasSkipped: true,
          timeSpentSeconds: timeSecs,
        ),
      );
    });
    _updateWeights(cat, false); // skip counts as wrong for bias
  }

  void _nextQuestion() {
    final isLast = currentQuestionIndex >= widget.totalQuestions - 1;
    if (isLast) {
      // Persist session to Hive history
      final catCorrect = <String, int>{};
      final catTotal = <String, int>{};
      for (final entry in categoryPerformance.entries) {
        catCorrect[entry.key] = entry.value.where((v) => v).length;
        catTotal[entry.key] = entry.value.length;
      }
      final avgT = timeSpentPerQuestion.isNotEmpty
          ? (timeSpentPerQuestion.reduce((a, b) => a + b) /
                    timeSpentPerQuestion.length)
                .round()
          : 0;
      // Serialize attempts into plain maps for Hive storage
      final snapshots = _attempts
          .map(
            (a) => <dynamic, dynamic>{
              'category': a.question.category,
              'type': a.question.type,
              'puzzle': a.question.puzzle,
              'options': a.question.options,
              'correctIndex': a.question.correctIndex,
              'selectedIndex': a.selectedIndex,
              'timeSpentSeconds': a.timeSpentSeconds,
              'isCorrect': a.isCorrect,
              'wasSkipped': a.wasSkipped,
            },
          )
          .toList();

      HiveService.saveSession(
        SessionRecord(
          date: DateTime.now(),
          score: score,
          totalQuestions: widget.totalQuestions,
          skipped: skippedCount,
          mode: widget.mode,
          categoryCorrect: catCorrect,
          categoryTotal: catTotal,
          avgTimeSeconds: avgT,
          attemptSnapshots: snapshots,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentResultScreen(
            score: score,
            totalQuestions: widget.totalQuestions,
            skipped: skippedCount,
            timeSpent: timeSpentPerQuestion,
            categoryStats: categoryPerformance,
            attempts: List.unmodifiable(_attempts),
          ),
        ),
      );
      return;
    }

    // Generate the NEXT question now (weights are already updated)
    _generateNextQuestion();

    setState(() {
      currentQuestionIndex++;
      isAnswered = false;
      selectedOption = null;
      isCorrect = false;
      _timedOut = false;
      _startTimer();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI helpers
  // ═══════════════════════════════════════════════════════════════════════════
  String _getTopicLabel(String category) {
    final labels = {
      'pattern': AppLocale.get(currentLang, 'topic_pattern'),
      'mirror_shape': AppLocale.get(currentLang, 'topic_mirror'),
      'mirror_text': AppLocale.get(currentLang, 'topic_mirror'),
      'odd_man': AppLocale.get(currentLang, 'topic_odd'),
      'analogy': AppLocale.get(currentLang, 'topic_analogy'),
      'figure_match': AppLocale.get(currentLang, 'topic_figmatch'),
      'figure_series': AppLocale.get(currentLang, 'topic_series'),
      'geo_completion': AppLocale.get(currentLang, 'topic_geo'),
      'punch_hole': AppLocale.get(currentLang, 'topic_punch'),
      'embedded': AppLocale.get(currentLang, 'topic_embedded'),
    };
    return labels[category] ?? AppLocale.get(currentLang, 'topic_odd');
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return '∞';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m${AppLocale.get(currentLang, 'minute_short')} '
          '${s.toString().padLeft(2, '0')}${AppLocale.get(currentLang, 'second_short')}';
    }
    return '$s${AppLocale.get(currentLang, 'second_short')}';
  }

  Color _timerColor() {
    if (!_hasTimer) return Colors.grey.shade500;
    final pct = remainingSeconds / _totalSeconds;
    if (pct > 0.5) return success;
    if (pct > 0.25) return warning;
    return error;
  }

  bool get _isTimeLow =>
      _hasTimer && remainingSeconds >= 0 && remainingSeconds <= 10;

  int get _attemptedCount =>
      _attempts.where((a) => a.selectedIndex != null).length;

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double progress = (currentQuestionIndex + 1) / widget.totalQuestions;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(progress, _currentQ.category),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuestionFigure(),
                    const SizedBox(height: 20),
                    _buildOptions(),
                    const SizedBox(height: 14),
                    if (isAnswered) _buildResultMessage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildBottomActions(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(double progress, String category) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: primary,
              backgroundColor: Colors.grey.shade200,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Topic pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getTopicLabel(category),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Bias indicator (only visible when bias is on and a weight is elevated)
              if (widget.biasEnabled) ...[
                const SizedBox(width: 6),
                _buildBiasIndicator(category),
              ],

              const Spacer(),
              _buildTimerWidget(),
              const SizedBox(width: 12),
              Text(
                '${AppLocale.s('question_short')} ${currentQuestionIndex + 1} / ${widget.totalQuestions}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(child: _buildScorePill()),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  /// Small dot that shows the current bias weight for this topic.
  /// Green = low weight (easy), orange = medium, red = high weight (weak area).
  Widget _buildBiasIndicator(String category) {
    final weight = _weights[category] ?? 1;
    if (weight <= 1) return const SizedBox.shrink(); // no dot when equal weight

    Color dotColor;
    String tooltip;
    if (weight <= 3) {
      dotColor = warning;
      tooltip = AppLocale.get(currentLang, 'reviewing');
    } else {
      dotColor = error;
      tooltip = AppLocale.get(currentLang, 'weak_area');
    }

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            tooltip,
            style: TextStyle(
              fontSize: 9,
              color: dotColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerWidget() {
    final color = _timerColor();
    if (!_hasTimer) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 3),
          Text(
            _formatTime(secondsElapsedForCurrent),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: _isTimeLow
            ? Border.all(color: error.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTimeLow ? Icons.timer_off_rounded : Icons.timer_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(remainingSeconds),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    return (_isTimeLow && !isAnswered)
        ? ScaleTransition(scale: _pulseAnim, child: container)
        : container;
  }

  Widget _buildScorePill() {
    final attempted = _attemptedCount;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          // rounded rectangle, not fully circular
          border: Border.all(color: success.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$score/$attempted',
              style: TextStyle(
                color: success,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Question figure ───────────────────────────────────────────────────────
  Widget _buildQuestionFigure() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: QuestionRenderer(puzzle: _currentQ.puzzle),
    );
  }

  // ── Options ───────────────────────────────────────────────────────────────
  Widget _buildOptions() {
    // Punch hole and mirror text/shape options need taller cards — the painters
    // use more vertical space than a simple shape.
    final cat = _currentQ.category;
    final double aspectRatio = (cat == 'punch_hole' || cat == 'mirror_text')
        ? 0.85
        : (cat == 'embedded')
        ? 0.95
        : (cat == 'mirror_shape')
        ? 1.1 // mirror shape options need slightly more height
        : (cat == 'geo_completion')
        ? 1.0 // geo now uses shape figures like pattern
        : 1.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: aspectRatio,
      children: List.generate(4, _buildOptionCard),
    );
  }

  Widget _buildOptionCard(int index) {
    final optionData = _currentQ.options[index];
    final isSelected = selectedOption == index.toString();
    final isCorrectOption = index == _currentQ.correctIndex;
    final label = String.fromCharCode(65 + index); // A, B, C, D

    Color bgColor = surface;
    Color borderColor = Colors.grey.shade200;
    double borderWidth = 1;
    Color labelColor = const Color(0xFF94A3B8);
    Widget? badge;

    if (isAnswered) {
      if (isCorrectOption) {
        bgColor = success.withValues(alpha: 0.12);
        borderColor = success;
        borderWidth = 2;
        labelColor = success;
        badge = _badge(Icons.check_rounded, success);
      } else if (isSelected) {
        bgColor = error.withValues(alpha: 0.12);
        borderColor = error;
        borderWidth = 2;
        labelColor = error;
        badge = _badge(Icons.close_rounded, error);
      }
    }

    return _PressScaleCard(
      onTap: isAnswered ? null : () => _handleOptionTap(index.toString()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Shape figure centred
            Center(child: OptionRenderer(data: optionData)),
            // A/B/C/D label — top-left corner always visible
            Positioned(
              top: 7,
              left: 9,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
            ),
            // Correct / wrong badge — top-right corner after answering
            if (badge != null) Positioned(top: 7, right: 7, child: badge),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, size: 12, color: Colors.white),
  );

  // ── Result message ────────────────────────────────────────────────────────
  Widget _buildResultMessage() {
    final isSkipped = selectedOption == null;
    final correctLetter = String.fromCharCode(
      65 + _currentQ.correctIndex,
    ); // A/B/C/D
    Color bg;
    Color fg;
    IconData icon;
    String text;

    if (_timedOut) {
      bg = const Color(0xFFFFF3CD);
      fg = const Color(0xFFB45309);
      icon = Icons.timer_off_rounded;
      text = "${AppLocale.get(currentLang, 'times_up')} $correctLetter";
    } else if (isSkipped) {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
      icon = Icons.skip_next_rounded;
      text =
          '${AppLocale.get(currentLang, 'skipped_answer_is')} $correctLetter';
    } else if (isCorrect) {
      bg = success.withValues(alpha: 0.1);
      fg = success;
      icon = Icons.check_circle_outline_rounded;
      text = AppLocale.get(currentLang, 'correct_msg');
    } else {
      bg = error.withValues(alpha: 0.1);
      fg = error;
      icon = Icons.cancel_outlined;
      text = '${AppLocale.get(currentLang, 'wrong_answer_is')} $correctLetter';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: fg, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        // ── Coordinator bias chart — hidden behind a toggle ────────────────
        if (widget.biasEnabled && widget.mode == 'random') ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showBiasChart = !_showBiasChart),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 13,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  _showBiasChart
                      ? AppLocale.get(currentLang, 'hide_bias')
                      : AppLocale.get(currentLang, 'show_bias'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _showBiasChart
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          if (_showBiasChart) ...[
            const SizedBox(height: 6),
            _buildWeightPreview(),
          ],
        ],
      ],
    );
  }

  /// Shows a mini bar chart of all 10 category weights after each answer,
  /// so the student/coordinator can see which topics are being focused on.
  Widget _buildWeightPreview() {
    final maxW = _weights.values.reduce(max).toDouble();
    final shortLabels = {
      'pattern': AppLocale.get(currentLang, 'short_pattern'),
      'analogy': AppLocale.get(currentLang, 'short_analogy'),
      'odd_man': AppLocale.get(currentLang, 'short_odd'),
      'mirror_shape': AppLocale.get(currentLang, 'short_mirshape'),
      'figure_match': AppLocale.get(currentLang, 'short_fig'),
      'figure_series': AppLocale.get(currentLang, 'short_series'),
      'geo_completion': AppLocale.get(currentLang, 'short_geo'),
      'mirror_text': AppLocale.get(currentLang, 'short_mirtext'),
      'punch_hole': AppLocale.get(currentLang, 'short_punch'),
      'embedded': AppLocale.get(currentLang, 'short_embedded'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 13,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                AppLocale.get(currentLang, 'bias_weights'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weights.entries.map((e) {
              final isCurrentCat = e.key == _currentQ.category;
              final barH = 4.0 + (e.value / maxW) * 28.0;
              final barColor = e.value <= 1
                  ? success
                  : e.value <= 4
                  ? warning
                  : error;
              final marker = isCurrentCat
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox(height: 4);
              return Expanded(
                child: Column(
                  children: [
                    marker,
                    const SizedBox(height: 2),
                    Container(
                      height: barH,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isCurrentCat
                            ? barColor
                            : barColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shortLabels[e.key] ?? e.key.substring(0, 3),
                      style: TextStyle(
                        fontSize: 7.5,
                        color: isCurrentCat ? primary : Colors.grey.shade500,
                        fontWeight: isCurrentCat
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Bottom actions ────────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    if (!isAnswered) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_skipButton()],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (skippedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.skip_next_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$skippedCount ${AppLocale.get(currentLang, "skipped_count")}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FloatingActionButton.extended(
              heroTag: 'next_btn',
              onPressed: _nextLocked ? null : _nextQuestion,
              backgroundColor: _nextLocked ? Colors.grey.shade400 : primary,
              elevation: _nextLocked ? 0 : 4,
              label: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_nextLocked) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocale.get(currentLang, 'look_at'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    Text(
                      currentQuestionIndex < widget.totalQuestions - 1
                          ? AppLocale.get(currentLang, 'next_question')
                          : AppLocale.get(currentLang, 'finish'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skipButton() => GestureDetector(
    onTap: _skipQuestion,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.skip_next_rounded, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            AppLocale.get(currentLang, 'skip'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Press-scale wrapper: shrinks to 96% on tap-down, springs back on release.
// Gives instant tactile feedback without any animation controller boilerplate.
// ─────────────────────────────────────────────────────────────────────────────
class _PressScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScaleCard({required this.child, this.onTap});

  @override
  State<_PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<_PressScaleCard> {
  double _scale = 1.0;

  void _onTapDown(_) => setState(() => _scale = 0.95);

  void _onTapUp(_) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
