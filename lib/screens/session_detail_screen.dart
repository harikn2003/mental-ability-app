import 'package:flutter/material.dart';

import '../config/localization.dart';
import '../data/session_record.dart';
import '../engine/reasoning_question.dart';
import '../widgets/option_renderer.dart';
import '../widgets/question_renderer.dart';

/// Full in-depth review of a past session loaded from Hive.
/// Shows every question with the puzzle, all 4 options, the student's answer,
/// the correct answer, and time spent — identical to SessionReviewScreen
/// but driven by serialized snapshots rather than live QuestionAttempt objects.
class SessionDetailScreen extends StatefulWidget {
  final SessionRecord session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  static const _bg = Color(0xFFF6F6F8);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _primary = Color(0xFF195DE6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);

  // view mode: list or focused (single card swipe)
  bool _focusedMode = false;
  int _focusedIdx = 0;
  bool _wrongOnly = false;

  List<Map<dynamic, dynamic>> get _snapshots => widget.session.attemptSnapshots;

  List<Map<dynamic, dynamic>> get _filtered => _wrongOnly
      ? _snapshots.where((s) => s['isCorrect'] != true).toList()
      : _snapshots;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final acc = session.accuracy;
    final accColor = acc >= 0.70
        ? _green
        : acc >= 0.40
        ? _orange
        : _red;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.modeLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            Text(
              _formatDate(session.date),
              style: const TextStyle(fontSize: 11, color: _subtle),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Score badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${session.score}/${session.totalQuestions} · '
              '${(acc * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: accColor,
              ),
            ),
          ),
        ],
      ),
      body: _snapshots.isEmpty
          ? _buildNoData()
          : _focusedMode
          ? _buildFocused()
          : _buildList(),
    );
  }

  // ── No snapshots (old session recorded before this feature) ──────────────
  Widget _buildNoData() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocale.s('no_detail_data'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocale.s('no_detail_data_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _subtle),
          ),
        ],
      ),
    ),
  );

  // ── List view ─────────────────────────────────────────────────────────────
  Widget _buildList() {
    final items = _filtered;
    return Column(
      children: [
        // Filter bar
        _buildFilterBar(items.length),
        // Cards
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    AppLocale.s('all_correct'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _SnapshotCard(
                    snapshot: items[i],
                    number: _snapshots.indexOf(items[i]) + 1,
                    onTap: () => setState(() {
                      _focusedIdx = i;
                      _focusedMode = true;
                    }),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Focused single-card view ──────────────────────────────────────────────
  Widget _buildFocused() {
    final items = _filtered;
    if (items.isEmpty) {
      return Column(
        children: [
          _buildFilterBar(0),
          Expanded(
            child: Center(
              child: Text(
                AppLocale.s('all_correct'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final idx = _focusedIdx.clamp(0, items.length - 1);
    final snap = items[idx];

    return Column(
      children: [
        _buildFilterBar(items.length),
        // Nav bar
        Container(
          color: _surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.list_rounded),
                onPressed: () => setState(() => _focusedMode = false),
                tooltip: AppLocale.s('list'),
                color: _primary,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: idx > 0
                    ? () => setState(() => _focusedIdx = idx - 1)
                    : null,
                color: idx > 0 ? _ink : Colors.grey.shade300,
              ),
              Text(
                '${idx + 1} / ${items.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: idx < items.length - 1
                    ? () => setState(() => _focusedIdx = idx + 1)
                    : null,
                color: idx < items.length - 1 ? _ink : Colors.grey.shade300,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _SnapshotCard(
              snapshot: snap,
              number: _snapshots.indexOf(snap) + 1,
              alwaysExpanded: true,
              onTap: null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(int count) {
    final wrongCount = _snapshots.where((s) => s['isCorrect'] != true).length;
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '$count ${AppLocale.s("questions_label")}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _subtle,
            ),
          ),
          const Spacer(),
          if (wrongCount > 0)
            GestureDetector(
              onTap: () => setState(() {
                _wrongOnly = !_wrongOnly;
                _focusedIdx = 0;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _wrongOnly
                      ? _red.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _wrongOnly
                        ? _red.withOpacity(0.4)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _wrongOnly
                      ? AppLocale.s('showing_wrong')
                      : AppLocale.s('show_wrong'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _wrongOnly ? _red : _subtle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ── Snapshot Card ─────────────────────────────────────────────────────────────
class _SnapshotCard extends StatefulWidget {
  final Map<dynamic, dynamic> snapshot;
  final int number;
  final bool alwaysExpanded;
  final VoidCallback? onTap;

  const _SnapshotCard({
    required this.snapshot,
    required this.number,
    this.alwaysExpanded = false,
    this.onTap,
  });

  @override
  State<_SnapshotCard> createState() => _SnapshotCardState();
}

class _SnapshotCardState extends State<_SnapshotCard> {
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);
  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);

  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.alwaysExpanded || widget.snapshot['isCorrect'] != true;
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot;
    final isCorrect = snap['isCorrect'] == true;
    final wasSkipped = snap['wasSkipped'] == true;
    final selected = snap['selectedIndex'] as int?;
    final correct = snap['correctIndex'] as int;
    final timeSecs = snap['timeSpentSeconds'] as int? ?? 0;
    final category = snap['category'] as String? ?? '';

    final statusColor = wasSkipped
        ? _orange
        : isCorrect
        ? _green
        : _red;
    final statusIcon = wasSkipped
        ? Icons.skip_next_rounded
        : isCorrect
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    // Reconstruct puzzle and options from snapshot
    final puzzle = (snap['puzzle'] as Map).cast<String, dynamic>();
    final options = (snap['options'] as List)
        .map((o) => (o as Map).cast<String, dynamic>())
        .toList();
    final rq = ReasoningQuestion(
      category: category,
      type: snap['type'] as String? ?? '',
      puzzle: puzzle,
      options: options,
      correctIndex: correct,
    );

    return GestureDetector(
      onTap:
          widget.onTap ??
          (widget.alwaysExpanded
              ? null
              : () => setState(() => _expanded = !_expanded)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  // Q number + category
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Q${widget.number}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.s(_categoryKey(category)),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _subtle,
                      ),
                    ),
                  ),
                  // Time
                  Text(
                    '${timeSecs}s',
                    style: const TextStyle(fontSize: 11, color: _subtle),
                  ),
                  const SizedBox(width: 8),
                  Icon(statusIcon, size: 18, color: statusColor),
                  if (!widget.alwaysExpanded) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _subtle,
                    ),
                  ],
                ],
              ),
            ),

            if (_expanded) ...[
              const Divider(height: 1),

              // ── Question figure ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF195DE6).withOpacity(0.12),
                    ),
                  ),
                  child: QuestionRenderer(puzzle: rq.puzzle),
                ),
              ),

              // ── Options grid ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: List.generate(options.length, (i) {
                    final isCorr = i == correct;
                    final isSel = i == selected;

                    Color bg = Colors.white;
                    Color border = Colors.grey.shade200;

                    if (isCorr) {
                      bg = _green.withOpacity(0.08);
                      border = _green;
                    } else if (isSel && !isCorr) {
                      bg = _red.withOpacity(0.08);
                      border = _red;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          Center(child: OptionRenderer(data: options[i])),
                          // Corner badges
                          if (isCorr)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: _green,
                              ),
                            ),
                          if (isSel && !isCorr)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 14,
                                color: _red,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // ── Result line ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        wasSkipped
                            ? '${AppLocale.s("skipped_msg")} ${correct + 1}'
                            : isCorrect
                            ? AppLocale.s('correct_msg')
                            : '${AppLocale.s("wrong_msg")} ${correct + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _categoryKey(String cat) {
    const m = {
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
    return m[cat] ?? 'cat_pattern';
  }
}
