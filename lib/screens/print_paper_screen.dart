import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../config/localization.dart';
import '../engine/test_paper.dart';
import '../paper/paper_pdf.dart';

/// Coordinator screen: a printed test paper for a class. Each student gets
/// the same 40 questions, shuffled differently; the answer key comes last.
class PrintPaperScreen extends StatefulWidget {
  const PrintPaperScreen({super.key});

  @override
  State<PrintPaperScreen> createState() => _PrintPaperScreenState();
}

class _PrintPaperScreenState extends State<PrintPaperScreen> {
  static const _primary = Color(0xFF195DE6);
  static const _maxStudents = 60;

  int _students = 5;
  (int, int)? _progress; // pages done, pages in all; null when idle

  Future<void> _make() async {
    final view = View.of(context);
    final sets = TestPaper.generate().sets(_students);
    setState(() => _progress = (0, 0));
    try {
      final pdf = await buildPaperPdf(sets, view, onProgress: (d, n) {
        if (mounted) setState(() => _progress = (d, n));
      });
      await Printing.layoutPdf(onLayout: (_) async => pdf, name: 'test-paper-$_students.pdf');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _progress != null;
    Widget stepButton(IconData icon, int delta) => IconButton.filledTonal(
          iconSize: 28,
          onPressed: busy || (_students + delta).clamp(1, _maxStudents) == _students
              ? null
              : () => setState(() => _students += delta),
          icon: Icon(icon),
        );
    return Scaffold(
      appBar: AppBar(title: Text(AppLocale.s('paper_print'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(AppLocale.s('paper_students'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              stepButton(Icons.remove_rounded, -1),
              SizedBox(
                width: 90,
                child: Text('$_students',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              ),
              stepButton(Icons.add_rounded, 1),
            ]),
            const SizedBox(height: 16),
            Text(AppLocale.s('paper_hint'), style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
            const Spacer(),
            if (busy) ...[
              LinearProgressIndicator(value: _progress!.$2 == 0 ? null : _progress!.$1 / _progress!.$2),
              const SizedBox(height: 8),
              Text(
                AppLocale.s('paper_making').replaceAll('{p}', '${_progress!.$1}').replaceAll('{n}', '${_progress!.$2}'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: busy ? null : _make,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.print_rounded),
                label: Text(AppLocale.s('paper_make'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
