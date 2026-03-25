import 'package:flutter/material.dart';

import '../data/hive_service.dart';
import '../data/session_record.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  static const _bg = Color(0xFFF6F6F8);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _primary = Color(0xFF195DE6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);

  List<SessionRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
    _sessions = HiveService.getSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Session History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _ink,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: _red),
              tooltip: 'Clear history',
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _sessions.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text(
          'No sessions yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete a quiz to see your history here.',
          style: TextStyle(fontSize: 14, color: _subtle),
        ),
      ],
    ),
  );

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _sessions.length,
      itemBuilder: (_, i) => _SessionCard(session: _sessions[i]),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'All session records will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await HiveService.clearHistory();
              if (mounted) setState(() => _sessions = []);
            },
            child: const Text('Clear', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRecord session;

  const _SessionCard({required this.session});

  static const _ink = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);

  Color _accuracyColor(double acc) {
    if (acc >= 0.70) return _green;
    if (acc >= 0.40) return _orange;
    return _red;
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final acc = session.accuracy;
    final color = _accuracyColor(acc);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
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
          // Top row: mode label + date + accuracy badge
          Row(
            children: [
              Expanded(
                child: Text(
                  session.modeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                _formatDate(session.date),
                style: const TextStyle(fontSize: 11, color: _subtle),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(acc * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _stat(
                Icons.check_circle_outline_rounded,
                _green,
                '${session.score}/${session.totalQuestions} correct',
              ),
              const SizedBox(width: 16),
              if (session.skipped > 0) ...[
                _stat(
                  Icons.skip_next_rounded,
                  _orange,
                  '${session.skipped} skipped',
                ),
                const SizedBox(width: 16),
              ],
              _stat(
                Icons.timer_outlined,
                _subtle,
                'avg ${session.avgTimeSeconds}s',
              ),
            ],
          ),
          // Category breakdown — only show categories attempted
          if (session.categoryTotal.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildCategoryBar(),
          ],
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: _subtle)),
    ],
  );

  Widget _buildCategoryBar() {
    // Only show categories where total > 0, sorted by accuracy asc
    final cats = session.categoryTotal.entries.where((e) => e.value > 0).map((
      e,
    ) {
      final correct = session.categoryCorrect[e.key] ?? 0;
      return MapEntry(e.key, correct / e.value);
    }).toList()..sort((a, b) => a.value.compareTo(b.value)); // worst first

    const labels = {
      'odd_man': 'Odd',
      'figure_match': 'Fig',
      'pattern': 'Pat',
      'figure_series': 'Ser',
      'analogy': 'Ana',
      'geo_completion': 'Geo',
      'mirror_shape': 'MirS',
      'mirror_text': 'MirT',
      'punch_hole': 'Pnc',
      'embedded': 'Emb',
    };

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: cats.map((e) {
        final pct = e.value;
        final color = _accuracyColor(pct);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${labels[e.key] ?? e.key} ${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
