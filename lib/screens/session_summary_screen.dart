import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mental_ability_app/config/localization.dart';

import '../engine/question_attempt.dart';
import 'quiz_screen.dart';
import 'session_review_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int skipped;
  final List<int> timeSpent;
  final Map<String, List<bool>> categoryStats;
  final List<QuestionAttempt> attempts;

  const SessionSummaryScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    this.skipped = 0,
    required this.timeSpent,
    required this.categoryStats,
    required this.attempts,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate Accuracy
    double accuracy = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
    int incorrect = totalQuestions - score;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocale.s('detailed_report'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScorecardHero(context, accuracy, incorrect),
            const SizedBox(height: 24),
            _buildTimeGraphSection(context),
            const SizedBox(height: 24),
            _buildTopicMasteryMatrix(context),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  // --- 1. HERO SECTION: SCORECARD & DONUT CHART ---
  Widget _buildScorecardHero(BuildContext context,
      double accuracy,
      int incorrect,) {
    // QW4: colour-coded accuracy badge
    final Color badgeBg;
    final Color badgeFg;
    if (accuracy >= 70) {
      badgeBg = Colors.green.shade100;
      badgeFg = Colors.green.shade800;
    } else if (accuracy >= 40) {
      badgeBg = Colors.orange.shade100;
      badgeFg = Colors.orange.shade900;
    } else {
      badgeBg = Colors.red.shade100;
      badgeFg = Colors.red.shade800;
    }

    // QW3: average time per question
    final int avgSecs = timeSpent.isNotEmpty
        ? (timeSpent.reduce((a, b) => a + b) / timeSpent.length).round()
        : 0;
    final String avgStr = avgSecs >= 60
        ? '${avgSecs ~/ 60}${AppLocale.s('minute_short')} ${(avgSecs % 60)
        .toString()
        .padLeft(2, '0')}${AppLocale.s('second_short')}'
        : '${avgSecs}${AppLocale.s('second_short')}';

    // Pie chart edge case: if both values are 0 show a grey placeholder
    final double pieCorrect = score > 0 ? score.toDouble() : 0;
    final double pieWrong = incorrect > 0 ? incorrect.toDouble() : 0;
    final bool allZero = pieCorrect == 0 && pieWrong == 0;

    return Card(
      elevation: 0,
      color: const Color(0xFF195DE6).withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score / $totalQuestions',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Skipped count — only shown when > 0
                  if (skipped > 0)
                    Text(
                      '$skipped ${AppLocale.s("skipped_count")}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    AppLocale.s('questions_correct'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Accuracy badge — colour reflects performance
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${accuracy.toStringAsFixed(0)}% ${AppLocale.s(
                              "accuracy")}',
                          style: TextStyle(
                              color: badgeFg, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // QW3: average time badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${AppLocale.s("avg_per_q")} $avgStr ${AppLocale.s(
                              "per_question")}',
                          style: TextStyle(
                              color: Colors.blueGrey.shade800,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: allZero
                  ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.grey.shade300, width: 6),
                ),
              )
                  : PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFF10B981),
                      value: pieCorrect,
                      title: '',
                      radius: 16,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFFEF4444),
                      value: pieWrong,
                      title: '',
                      radius: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. TIME TRAP BAR GRAPH (DYNAMIC NOW) ---
  Widget _buildTimeGraphSection(BuildContext context) {
    if (timeSpent.isEmpty) return const SizedBox.shrink();

    // Find the highest time spent to scale the Y axis properly
    double maxTime = timeSpent.reduce(max).toDouble();
    double chartMaxY = maxTime > 60
        ? maxTime + 10
        : 60; // minimum 60s Y-axis height

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.s('time_per_q'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: chartMaxY,
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 45,
                    // Time Trap Threshold
                    color: Colors.orange.shade700,
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                      ),
                      labelResolver: (line) => AppLocale.s('limit_45s'),
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= timeSpent.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${AppLocale.s('question_short')}${index + 1}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              // Map real recorded times into bar groups
              barGroups: List.generate(timeSpent.length, (index) {
                return _makeBarGroup(
                  index,
                  timeSpent[index].toDouble(),
                  context,
                  isTimeTrap: timeSpent[index] > 45,
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x,
      double y,
      BuildContext context, {
        bool isTimeTrap = false,
      }) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isTimeTrap ? Colors.orange.shade600 : const Color(0xFF195DE6),
          width: 16,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  // --- 3. TOPIC MASTERY MATRIX (DYNAMIC NOW) ---
  Widget _buildTopicMasteryMatrix(BuildContext context) {
    if (categoryStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.s('category_breakdown'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Generate tiles dynamically based on actual categories played
        ...categoryStats.entries.map((entry) {
          String categoryName = entry.key;
          List<bool> results = entry.value;

          int correctCount = results.where((r) => r).length;
          double percent = results.isNotEmpty
              ? correctCount / results.length
              : 0;

          String status = AppLocale.s('weak');
          MaterialColor color = Colors.red;

          if (percent >= 0.8) {
            status = AppLocale.s('strong');
            color = Colors.green;
          } else if (percent >= 0.5) {
            status = AppLocale.s('good');
            color = Colors.blue;
          }

          // Use readable label map — avoids "odd_man", "figure_series" etc.
          final catLabels = {
            'odd_man': AppLocale.s('cat_odd_man'),
            'figure_match': AppLocale.s('cat_fig_match'),
            'pattern': AppLocale.s('cat_pattern'),
            'figure_series': AppLocale.s('cat_fig_series'),
            'analogy': AppLocale.s('cat_analogy'),
            'geo_completion': AppLocale.s('cat_geo'),
            'mirror_shape': AppLocale.s('cat_mirror_shape'),
            'mirror_text': AppLocale.s('cat_mirror_text'),
            'punch_hole': AppLocale.s('cat_punch'),
            'embedded': AppLocale.s('cat_embedded'),
          };
          final formattedName = catLabels[categoryName]
              ?? (categoryName[0].toUpperCase() + categoryName.substring(1));

          return _buildMasteryTile(formattedName, status, percent, color);
        }).toList(),
      ],
    );
  }

  Widget _buildMasteryTile(String title,
      String status,
      double progress,
      MaterialColor color,) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.shade100,
            color: color.shade600,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  String _questionSignature(QuestionAttempt a) {
    return '${a.question.category}|${a.question.type}|${a.question.puzzle}|${a
        .question.correctIndex}';
  }

  List<QuestionAttempt> _incorrectAttemptsUnique() {
    final seen = <String>{};
    final out = <QuestionAttempt>[];
    for (final a in attempts.where((x) => !x.isCorrect)) {
      final sig = _questionSignature(a);
      if (seen.add(sig)) out.add(a);
    }
    return out;
  }

  // --- 4. BOTTOM ACTION BUTTONS ---
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── REVIEW ANSWERS (new) ────────────────────────────────────────────
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionReviewScreen(attempts: attempts),
            ),
          ),
          icon: const Icon(Icons.rate_review_rounded),
          label: Text(
              AppLocale.s('review_answers'), style: TextStyle(fontSize: 16)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF195DE6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final retryAttempts = _incorrectAttemptsUnique();
          final canRetry = retryAttempts.isNotEmpty;
          return FilledButton.icon(
            onPressed: !canRetry
                ? null
                : () {
              final retryQuestions =
              retryAttempts.map((a) => a.question).toList();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      QuizScreen(
                          mode: 'random',
                        totalQuestions: retryQuestions.length,
                          timePerQuestion: '2m',
                        biasEnabled: false,
                        retryQuestions: retryQuestions,
                        ),
                ),
              );
            },
            icon: const Icon(Icons.fitness_center_rounded),
            label: Text(
              canRetry
                  ? '${AppLocale.s('try_again')} (${retryAttempts
                  .length} ${AppLocale.s('incorrect')})'
                  : AppLocale.s('no_weak_session'),
              style: const TextStyle(fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: canRetry
                  ? const Color(0xFFF97316)
                  : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: Text(
              AppLocale.s('return_home'), style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}