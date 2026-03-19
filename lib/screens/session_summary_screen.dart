import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../engine/question_attempt.dart';
import 'quiz_screen.dart';
import 'session_review_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final List<int> timeSpent;
  final Map<String, List<bool>> categoryStats;
  final List<QuestionAttempt> attempts;

  const SessionSummaryScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
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
        title: const Text(
          'Session Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
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
  Widget _buildScorecardHero(
    BuildContext context,
    double accuracy,
    int incorrect,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFF195DE6).withOpacity(0.1), // Primary color tinted
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
                  Text(
                    'Questions Correct',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${accuracy.toStringAsFixed(0)}% Accuracy',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      color: const Color(0xFF10B981),
                      value: score.toDouble(),
                      title: '',
                      radius: 16,
                    ),
                    PieChartSectionData(
                      color: const Color(0xFFEF4444),
                      value: incorrect.toDouble(),
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
        const Text(
          'Time Per Question',
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
                      labelResolver: (line) => 'Limit (45s)',
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
                          'Q${index + 1}',
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

  BarChartGroupData _makeBarGroup(
    int x,
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
        const Text(
          'Category Breakdown',
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

          String status = 'Weak';
          MaterialColor color = Colors.red;

          if (percent >= 0.8) {
            status = 'Strong';
            color = Colors.green;
          } else if (percent >= 0.5) {
            status = 'Good';
            color = Colors.blue;
          }

          // Format category name string (capitalize)
          String formattedName =
              categoryName[0].toUpperCase() + categoryName.substring(1);

          return _buildMasteryTile(formattedName, status, percent, color);
        }).toList(),
      ],
    );
  }

  Widget _buildMasteryTile(
    String title,
    String status,
      double progress,
    MaterialColor color,
  ) {
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

  // --- HELPER: weakest category label ---
  String _weakestLabel() {
    if (categoryStats.isEmpty) return 'Weak Areas';
    final weakest = categoryStats.entries
        .map((e) {
          final correct = e.value.where((v) => v).length;
          final pct = e.value.isEmpty ? 1.0 : correct / e.value.length;
          return MapEntry(e.key, pct);
        })
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    const labels = {
      'odd_man': 'Odd Man Out',
      'figure_match': 'Figure Match',
      'pattern': 'Pattern Completion',
      'figure_series': 'Figure Series',
      'analogy': 'Analogy',
      'geo_completion': 'Geo Completion',
      'mirror_shape': 'Mirror Shape',
      'mirror_text': 'Mirror Text',
      'punch_hole': 'Punch Hole',
      'embedded': 'Embedded Figure',
    };
    return labels[weakest] ?? weakest;
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
          label: const Text('Review Answers', style: TextStyle(fontSize: 16)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF195DE6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: categoryStats.isEmpty
              ? null
              : () {
                  // Find the weakest category (lowest accuracy)
                  String weakest = categoryStats.entries
                      .map((e) {
                        final correct = e.value.where((v) => v).length;
                        final pct = e.value.isEmpty
                            ? 1.0
                            : correct / e.value.length;
                        return MapEntry(e.key, pct);
                      })
                      .reduce((a, b) => a.value <= b.value ? a : b)
                      .key;

                  // Pop summary, then push a new quiz session focused on that category
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(
                        mode: weakest,
                        totalQuestions: 10,
                        timePerQuestion: '2m',
                        biasEnabled: false, // fixed category, no bias needed
                      ),
                    ),
                  );
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: Text(
            categoryStats.isEmpty
                ? 'Practice Weak Areas'
                : 'Practice ${_weakestLabel()}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          child: const Text('Return to Home', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}