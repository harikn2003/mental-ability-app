import 'package:flutter/material.dart';

import '../engine/question_attempt.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';

/// Shows every question from the session with:
///  • The question figure
///  • All 4 options labelled A/B/C/D
///  • Student's chosen option highlighted (green=correct, red=wrong)
///  • Correct answer always highlighted green
///  • Category label + time taken
///  • "Skipped" badge if the student skipped
class SessionReviewScreen extends StatefulWidget {
  final List<QuestionAttempt> attempts;

  const SessionReviewScreen({super.key, required this.attempts});

  @override
  State<SessionReviewScreen> createState() => _SessionReviewScreenState();
}

class _SessionReviewScreenState extends State<SessionReviewScreen> {
  // ── Colours ─────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF6F6F8);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _primary = Color(0xFF195DE6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);

  // ── Filter state ─────────────────────────────────────────────────────────
  bool _showWrongOnly = false; // when true, collapse correct cards

  List<QuestionAttempt> get _filtered =>
      _showWrongOnly
          ? widget.attempts.where((a) => !a.isCorrect).toList()
          : widget.attempts;

  int get _wrongCount =>
      widget.attempts
          .where((a) => !a.isCorrect)
          .length;

  int get _correctCount =>
      widget.attempts
          .where((a) => a.isCorrect)
          .length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Answer Review',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: _ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              // ── Score strip ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statChip(_correctCount.toString(), 'Correct', _green),
                    const SizedBox(width: 12),
                    _statChip(_wrongCount.toString(), 'Wrong', _red),
                    const SizedBox(width: 12),
                    _statChip(
                      widget.attempts
                          .where((a) => a.wasSkipped)
                          .length
                          .toString(),
                      'Skipped', _orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Filter toggle ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: GestureDetector(
                  onTap: () => setState(() => _showWrongOnly = !_showWrongOnly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showWrongOnly
                          ? _red.withOpacity(0.12)
                          : _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _showWrongOnly ? _red : Colors.grey.shade300,
                        width: _showWrongOnly ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showWrongOnly
                              ? Icons.filter_list_off_rounded
                              : Icons.filter_list_rounded,
                          size: 15,
                          color: _showWrongOnly ? _red : _subtle,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showWrongOnly
                              ? 'Showing $_wrongCount wrong answers — tap to show all'
                              : 'Show wrong answers only  ($_wrongCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _showWrongOnly ? _red : _subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: filtered.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: filtered.length,
        itemBuilder: (_, i) =>
            _QuestionReviewCard(
              attempt: filtered[i],
              number: widget.attempts.indexOf(filtered[i]) + 1,
              // Auto-expand wrong/skipped cards; collapse correct ones
              initiallyExpanded: !filtered[i].isCorrect,
            ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$value ',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color,
                ),
              ),
              TextSpan(
                text: label,
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
              ),
        ],
      ),
        ),
      );

  Widget _buildEmpty() =>
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64,
                color: _green.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('All answers were correct!',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
            const SizedBox(height: 8),
            Text('No wrong answers to show.',
                style: TextStyle(fontSize: 14, color: _subtle)),
          ],
        ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Single question card
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionReviewCard extends StatefulWidget {
  final QuestionAttempt attempt;
  final int number;
  final bool initiallyExpanded;

  const _QuestionReviewCard({
    required this.attempt,
    required this.number,
    this.initiallyExpanded = false,
  });

  @override
  State<_QuestionReviewCard> createState() => _QuestionReviewCardState();
}

class _QuestionReviewCardState extends State<_QuestionReviewCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  static const _bg = Color(0xFFF6F6F8);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _primary = Color(0xFF195DE6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final a = widget.attempt;
    final q = a.question;
    final isCorrect = a.isCorrect;
    final isSkipped = a.wasSkipped;

    Color statusColor = isCorrect ? _green : (isSkipped ? _orange : _red);
    IconData statusIcon = isCorrect
        ? Icons.check_circle_rounded
        : (isSkipped ? Icons.skip_next_rounded : Icons.cancel_rounded);
    String statusText = isCorrect ? 'Correct' : (isSkipped
        ? 'Skipped'
        : 'Wrong');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  // Question number badge
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'Q${widget.number}',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Category + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.categoryLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14, color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.timeSpentSeconds}s',
                          style: const TextStyle(fontSize: 11, color: _subtle),
                        ),
                      ],
                    ),
                  ),

                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusText,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  // Expand/collapse chevron
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _subtle, size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: question figure + options ──────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question figure
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QuestionRenderer(puzzle: q.puzzle),
                  ),
                  const SizedBox(height: 16),

                  // Options grid 2×2
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: List.generate(q.options.length, (i) {
                      return _buildOptionCard(i, q.options[i], a);
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index,
      Map<String, dynamic> optionData,
      QuestionAttempt a,) {
    final isCorrectOption = index == a.question.correctIndex;
    final isStudentChoice = index == a.selectedIndex;
    final isWrongChoice = isStudentChoice && !isCorrectOption;

    // Border/bg colour logic
    Color borderColor;
    Color bgColor;
    Widget? badge;

    if (isCorrectOption && isStudentChoice) {
      // Student picked the right answer
      borderColor = _green;
      bgColor = _green.withOpacity(0.08);
      badge = _optionBadge(_green, Icons.check_rounded, 'Your answer ✓');
    } else if (isCorrectOption) {
      // This is the correct answer (student didn't pick it)
      borderColor = _green;
      bgColor = _green.withOpacity(0.06);
      badge = _optionBadge(_green, Icons.check_rounded, 'Correct');
    } else if (isWrongChoice) {
      // Student picked this but it's wrong
      borderColor = _red;
      bgColor = _red.withOpacity(0.06);
      badge = _optionBadge(_red, Icons.close_rounded, 'Your answer');
    } else {
      borderColor = Colors.grey.shade200;
      bgColor = _surface;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor,
            width: isCorrectOption || isStudentChoice ? 2.0 : 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Option letter (A/B/C/D)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Text(
                String.fromCharCode(65 + index), // A, B, C, D
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCorrectOption
                      ? _green
                      : (isWrongChoice ? _red : _subtle),
                ),
              ),
            ),
          ),

          // The shape
          Expanded(
            child: Center(
              child: OptionRenderer(data: optionData, size: 52),
            ),
          ),

          // Badge at bottom
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: badge,
            ),
          if (badge == null)
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _optionBadge(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}