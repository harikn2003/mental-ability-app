import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../engine/question_attempt.dart';
import 'session_config_screen.dart';
import 'session_summary_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// StudentResultScreen
//
// Shown immediately after quiz ends — before the detailed teacher report.
// Designed for rural students aged 10-15.
// Language: whichever is current in AppLocale.
//
// Layout (top → bottom):
//   1. Big emoji + one-line verdict (Great job! / Keep trying!)
//   2. Score circle — large, easy to read
//   3. Three stat pills — correct / wrong / time
//   4. Topic result cards — each topic as a simple pass/retry badge
//   5. Two CTA buttons — Try Again / See Full Report (teacher view)
// ═══════════════════════════════════════════════════════════════════════════
class StudentResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int skipped;
  final List<int> timeSpent;
  final Map<String, List<bool>> categoryStats;
  final List<QuestionAttempt> attempts;

  const StudentResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    this.skipped = 0,
    required this.timeSpent,
    required this.categoryStats,
    required this.attempts,
  });

  // ── Theme ──────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF195DE6);
  static const _green = Color(0xFF10B981);
  static const _orange = Color(0xFFF97316);
  static const _red = Color(0xFFEF4444);
  static const _bgPage = Color(0xFFF6F6F8);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  // ── Helpers ────────────────────────────────────────────────────────────
  double get _accuracy => totalQuestions > 0 ? score / totalQuestions : 0.0;

  int get _avgSecs => timeSpent.isNotEmpty
      ? (timeSpent.reduce((a, b) => a + b) / timeSpent.length).round()
      : 0;

  // Grade tier
  _Tier get _tier {
    final pct = _accuracy;
    if (pct >= 0.80) return _Tier.excellent;
    if (pct >= 0.60) return _Tier.good;
    if (pct >= 0.40) return _Tier.average;
    return _Tier.needsPractice;
  }

  // Category label from localization key
  String _catLabel(String key) {
    const map = {
      'odd_man': 'cat_odd_man',
      'figure_match': 'cat_fig_match',
      'pattern': 'cat_pattern',
      'figure_series': 'cat_fig_series',
      'analogy': 'cat_analogy',
      'geo_completion': 'cat_geo',
      'mirror_shape': 'cat_mirror_shape',
      'mirror_text': 'cat_mirror_text',
      'punch_hole': 'cat_punch',
      'embedded': 'cat_embedded',
    };
    return AppLocale.s(map[key] ?? key);
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(),
              const SizedBox(height: 24),
              _buildScoreCircle(),
              const SizedBox(height: 20),
              _buildStatRow(),
              const SizedBox(height: 28),
              _buildTopicCards(),
              const SizedBox(height: 32),
              _buildActions(context),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Hero ────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final t = _tier;
    return Column(
      children: [
        Text(t.emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(
          t.headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
        ),
      ],
    );
  }

  // ── 2. Score circle ────────────────────────────────────────────────────
  Widget _buildScoreCircle() {
    final pct = _accuracy;
    final color = _tier.color;
    return Center(
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Track
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 12,
                valueColor: AlwaysStoppedAnimation(color.withOpacity(0.12)),
              ),
            ),
            // Fill
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            // Labels
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score/$totalQuestions',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocale.s('score'),
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Stat pills ──────────────────────────────────────────────────────
  Widget _buildStatRow() {
    final incorrect = totalQuestions - score;
    final mins = _avgSecs ~/ 60;
    final secs = _avgSecs % 60;
    final timeStr = mins > 0
        ? '$mins${AppLocale.s('minute_short')} ${secs.toString().padLeft(2, '0')}${AppLocale.s('second_short')}'
        : '$secs${AppLocale.s('second_short')}';

    return Row(
      children: [
        _StatPill(
          icon: Icons.check_circle_rounded,
          color: _green,
          label: AppLocale.s('correct'),
          value: '$score',
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.cancel_rounded,
          color: _red,
          label: AppLocale.s('incorrect'),
          value: '$incorrect',
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.timer_rounded,
          color: _orange,
          label: AppLocale.s('avg_time'),
          value: timeStr,
        ),
      ],
    );
  }

  // ── 4. Topic result cards ──────────────────────────────────────────────
  Widget _buildTopicCards() {
    if (categoryStats.isEmpty) return const SizedBox.shrink();

    // Sort: weak topics first — student sees what to work on first
    final entries = categoryStats.entries.toList()
      ..sort((a, b) {
        final pctA = a.value.where((x) => x).length / a.value.length;
        final pctB = b.value.where((x) => x).length / b.value.length;
        return pctA.compareTo(pctB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.s('how_you_did_by_topic'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map(
          (e) => _TopicCard(label: _catLabel(e.key), results: e.value),
        ),
      ],
    );
  }

  // ── 5. Action buttons ──────────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary — try again
        FilledButton.icon(
          onPressed: () {
            // Pop all the way back to config screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SessionConfigScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            AppLocale.s('try_again'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Secondary — detailed report (teacher view)
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionSummaryScreen(
                  score: score,
                  totalQuestions: totalQuestions,
                  skipped: skipped,
                  timeSpent: timeSpent,
                  categoryStats: categoryStats,
                  attempts: attempts,
                ),
              ),
            );
          },
          icon: const Icon(Icons.bar_chart_rounded, size: 18),
          label: Text(
            AppLocale.s('full_report'),
            style: const TextStyle(fontSize: 15),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: _muted,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tier
// ═══════════════════════════════════════════════════════════════════════════
enum _Tier { excellent, good, average, needsPractice }

extension _TierProps on _Tier {
  String get emoji {
    switch (this) {
      case _Tier.excellent:
        return '🏆';
      case _Tier.good:
        return '👍';
      case _Tier.average:
        return '💪';
      case _Tier.needsPractice:
        return '📚';
    }
  }

  String get headline {
    switch (this) {
      case _Tier.excellent:
        return AppLocale.s('excellent_headline');
      case _Tier.good:
        return AppLocale.s('good_headline');
      case _Tier.average:
        return AppLocale.s('average_headline');
      case _Tier.needsPractice:
        return AppLocale.s('needs_practice_headline');
    }
  }

  String get subtitle {
    switch (this) {
      case _Tier.excellent:
        return AppLocale.s('excellent_subtitle');
      case _Tier.good:
        return AppLocale.s('good_subtitle');
      case _Tier.average:
        return AppLocale.s('average_subtitle');
      case _Tier.needsPractice:
        return AppLocale.s('needs_practice_subtitle');
    }
  }

  Color get color {
    switch (this) {
      case _Tier.excellent:
        return const Color(0xFF10B981);
      case _Tier.good:
        return const Color(0xFF195DE6);
      case _Tier.average:
        return const Color(0xFFF97316);
      case _Tier.needsPractice:
        return const Color(0xFFEF4444);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _StatPill
// ═══════════════════════════════════════════════════════════════════════════
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TopicCard
// ═══════════════════════════════════════════════════════════════════════════
class _TopicCard extends StatelessWidget {
  final String label;
  final List<bool> results;

  const _TopicCard({required this.label, required this.results});

  @override
  Widget build(BuildContext context) {
    final correct = results.where((x) => x).length;
    final total = results.length;
    final pct = total > 0 ? correct / total : 0.0;

    final Color barColor;
    final String badge;
    final Color badgeColor;
    final Color badgeBg;

    if (pct >= 0.80) {
      barColor = const Color(0xFF10B981);
      badge = '✓ ${AppLocale.s('topic_badge_good')}';
      badgeColor = const Color(0xFF065F46);
      badgeBg = const Color(0xFFD1FAE5);
    } else if (pct >= 0.50) {
      barColor = const Color(0xFF195DE6);
      badge = AppLocale.s('topic_badge_ok');
      badgeColor = const Color(0xFF1E40AF);
      badgeBg = const Color(0xFFDBEAFE);
    } else {
      barColor = const Color(0xFFEF4444);
      badge = AppLocale.s('topic_badge_retry');
      badgeColor = const Color(0xFF991B1B);
      badgeBg = const Color(0xFFFEE2E2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Score fraction
              Text(
                '$correct/$total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
