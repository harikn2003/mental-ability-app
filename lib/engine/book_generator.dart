import 'dart:math';

import 'line_figure.dart';
import 'reasoning_question.dart';

/// Question types taken from the JNVST guide book (Arihant, Class VI) that
/// the other generators don't make. Each is ADDED to its topic's mix in
/// QuestionGenerator at a small share:
///   odd_man       - letter words (RUN UNR NKU RNU), counting symbols
///   figure_series - letters shifting (IPOZ POZI OZIP ?), a symbol stepping
///                   round the box
///   punch_hole    - paper folding: a see-through sheet folded on a line
/// Every method may return null when a draw fails its checks; callers fall
/// back to the topic's other generators.
class BookGenerator {
  static Random _r = Random();

  static void seed(int s) => _r = Random(s);

  static T _pick<T>(List<T> l) => l[_r.nextInt(l.length)];

  /// Shuffles [opts] (the answer first) into a question.
  static ReasoningQuestion _question(String category, String type, Map<String, dynamic> puzzle, List<Map<String, dynamic>> opts) {
    final order = [0, 1, 2, 3]..shuffle(_r);
    return ReasoningQuestion(
      category: category,
      type: type,
      puzzle: puzzle,
      options: [for (final i in order) opts[i]],
      correctIndex: order.indexOf(0),
    );
  }

  static Map<String, dynamic> _text(String s) =>
      {'type': 'mirror_text', 'content': s, 'is_clock': false, 'mirror_h': false, 'mirror_v': false};

  // Letters that read the same to a child in any of the paper's fonts; no
  // I/J/O/Q/X so a word never looks like a number or a symbol.
  static const _letters = 'ABCDEFGHKLMNPRSTUVWY';

  /// [n] different letters.
  static List<String> _word(int n) => (_letters.split('')..shuffle(_r)).take(n).toList();

  // ── Odd Man: letter words ─────────────────────────────────────────────────

  // Look-alike pairs for Medium: the odd word differs by one similar letter.
  static const _twins = [('E', 'F'), ('P', 'R'), ('C', 'G'), ('M', 'N'), ('U', 'V'), ('B', 'D')];

  /// Three words use the same letters in different orders; the odd one has
  /// one letter changed. Easy: 3 letters, any new letter. Medium: 4 letters,
  /// the new letter looks like the old one (E/F, P/R, ...).
  static ReasoningQuestion? oddManLetters({bool medium = false}) {
    final n = medium ? 4 : 3;
    late List<String> word;
    late String from, to;
    if (medium) {
      final (a, b) = _pick(_twins);
      (from, to) = _r.nextBool() ? (a, b) : (b, a);
      word = [from, ...(_letters.split('')..removeWhere((c) => c == a || c == b)..shuffle(_r)).take(n - 1)]..shuffle(_r);
    } else {
      word = _word(n);
      from = _pick(word);
      to = _pick(_letters.split('')..removeWhere(word.contains));
    }
    final words = <String>{};
    while (words.length < 4) {
      words.add((List.of(word)..shuffle(_r)).join());
    }
    final [odd, ...alike] = words.toList();
    final changed = odd.replaceFirst(from, to);
    return _question('odd_man', medium ? 'odd_letters_medium' : 'odd_letters',
        {'type': 'odd_man', 'rule': 'letters'}, [_text(changed), for (final w in alike) _text(w)]);
  }

  // ── Odd Man: counting ─────────────────────────────────────────────────────

  /// Medium: five symbols of two kinds in a 3x3 box. Three figures have 3 of
  /// one kind and 2 of the other; the odd one has the counts the other way
  /// round. Places are random, so only the counts tell them apart.
  static ReasoningQuestion? oddManCount() {
    final (a, b) = _pick(const [('plus', 'cross'), ('plus', 'ring'), ('cross', 'ring'), ('ring', 'dot')]);
    LineFig fig(int na, int nb) {
      final cells = [for (int i = 0; i < 9; i++) (i % 3, i ~/ 3)]..shuffle(_r);
      return LineFig(3, 3, frame: true, glyphs: {
        for (int i = 0; i < na; i++) (cells[i].$1, cells[i].$2, a),
        for (int i = na; i < na + nb; i++) (cells[i].$1, cells[i].$2, b),
      });
    }

    final figs = [fig(2, 3), fig(3, 2), fig(3, 2), fig(3, 2)];
    if ({for (final f in figs) f.key}.length < 4) return null;
    return _question('odd_man', 'odd_count', {'type': 'odd_man', 'rule': 'count'}, [for (final f in figs) f.toMap()]);
  }

  // ── Series: letters shifting ──────────────────────────────────────────────

  static String _shift(String s, int k) {
    final n = s.length, m = ((k % n) + n) % n;
    return s.substring(m) + s.substring(0, m);
  }

  static String _swap(String s, int i) {
    final c = s.split('');
    final t = c[i];
    c[i] = c[i + 1];
    c[i + 1] = t;
    return c.join();
  }

  /// IPOZ, POZI, OZIP, ?: the first letter moves to the end each step. Easy:
  /// 4 letters, always to the left. Medium: 5 letters, left or right. Wrong
  /// options: two letters swapped, or the word read backwards.
  static ReasoningQuestion? seriesLetters({bool medium = false}) {
    final w = _word(medium ? 5 : 4).join();
    final step = medium && _r.nextBool() ? -1 : 1;
    final answer = _shift(w, 3 * step);
    final wrong = <String>{_swap(answer, 0), _swap(answer, answer.length - 2), answer.split('').reversed.join()}
      ..removeWhere((s) => s == answer || s == w || s == _shift(w, step) || s == _shift(w, 2 * step));
    if (wrong.length < 3) return null;
    return _question('figure_series', medium ? 'series_letters_medium' : 'series_letters', {
      'type': 'series',
      'rule': 'letters',
      'sequence': [for (int k = 0; k < 3; k++) _text(_shift(w, k * step))],
    }, [_text(answer), for (final s in wrong) _text(s)]);
  }

  // ── Series: round the box ─────────────────────────────────────────────────

  /// The eight edge places of a 3x3 box, clockwise from the top-left corner.
  static const _ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)];

  static LineFig _box(Map<String, int> at) =>
      LineFig(3, 3, frame: true, glyphs: {for (final e in at.entries) (_ring[e.value % 8].$1, _ring[e.value % 8].$2, e.key)});

  /// Symbols step round the edge of the box. Easy: one symbol, one place a
  /// step, clockwise or not. Medium: two symbols, one a place a step, the
  /// other two places or the other way round.
  static ReasoningQuestion? seriesRound({bool medium = false}) {
    if (!medium) {
      final g = _pick(const ['cross', 'plus', 'ring', 'dot']);
      final s = _pick(const [1, -1]), p = _r.nextInt(8);
      LineFig at(int k) => _box({g: p + s * k});
      // Wrong: didn't move, moved two places, went the other way.
      final opts = [at(3), at(2), at(4), _box({g: p - 3 * s})];
      if ({for (final o in opts) o.key}.length < 4) return null;
      return _question('figure_series', 'series_round', {
        'type': 'series',
        'rule': 'round',
        'sequence': [for (int k = 0; k < 3; k++) at(k).toMap()],
      }, [for (final o in opts) o.toMap()]);
    }
    for (int t = 0; t < 20; t++) {
      final q = _roundMedium();
      if (q != null) return q;
    }
    return null;
  }

  static ReasoningQuestion? _roundMedium() {
    final (a, b) = _pick(const [('cross', 'ring'), ('plus', 'dot'), ('ring', 'plus'), ('dot', 'cross')]);
    final sa = _pick(const [1, -1]);
    final sb = _pick([-sa, 2 * sa]);
    final pa = _r.nextInt(8), pb = _r.nextInt(8);
    int posA(int k) => (pa + sa * k) % 8;
    int posB(int k) => (pb + sb * k) % 8;
    // The symbols never share a place in the series.
    for (int k = 0; k < 3; k++) {
      if (posA(k) == posB(k)) return null;
    }
    LineFig f(int ka, int kb) => _box({a: pa + sa * ka, b: pb + sb * kb});
    final opts = [f(3, 3), f(3, 2), f(2, 3), _box({a: pb + sb * 3, b: pa + sa * 3})];
    if ({for (final o in opts) o.key}.length < 4 || opts.any((o) => {for (final g in o.glyphs) (g.$1, g.$2)}.length < 2)) return null;
    return _question('figure_series', 'series_round_medium', {
      'type': 'series',
      'rule': 'round',
      'sequence': [for (int k = 0; k < 3; k++) f(k, k).toMap()],
    }, [for (final o in opts) o.toMap()]);
  }

  // ── Punch Hole: paper folding ─────────────────────────────────────────────

  /// Straight lines inside the left half (x 0-2, y 0-4) of a 4x4 sheet,
  /// clear of its edges and the fold, as unit segments.
  static Set<(int, int, int, int)> _halfLines(int count) {
    const dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];
    final out = <(int, int, int, int)>{};
    var tries = 0;
    while (out.length < count * 2 && tries++ < 200) {
      final (dx, dy) = _pick(dirs);
      final len = 1 + _r.nextInt(2);
      final x = _r.nextInt(3), y = _r.nextInt(5);
      final line = LineFig.line(x, y, x + dx * len, y + dy * len);
      bool inside((int, int, int, int) s) {
        final (x1, y1, x2, y2) = s;
        if ([x1, x2].any((v) => v < 0 || v > 2) || [y1, y2].any((v) => v < 0 || v > 4)) return false;
        if (x1 == x2 && (x1 == 0 || x1 == 2)) return false; // on an edge or the fold
        if (y1 == y2 && (y1 == 0 || y1 == 4)) return false;
        return true;
      }

      if (line.every(inside) && !line.any(out.contains)) out.addAll(line);
      if (out.length >= count * 2) break;
    }
    return out;
  }

  static Set<(int, int, int, int)> _mapSegs(Set<(int, int, int, int)> s, (int, int) Function(int, int) f) => {
        for (final (x1, y1, x2, y2) in s)
          () {
            final (a, b) = f(x1, y1);
            final (c, d) = f(x2, y2);
            return (a, b, c, d);
          }(),
      };

  /// Medium: a see-through sheet with lines on both halves is folded along
  /// the dotted middle line, the right half over the left. The answer is the
  /// left half with the right half's lines flipped onto it. Wrong options:
  /// the right half slid across without flipping, flipped upside down, or
  /// the left half's own lines flipped instead.
  static ReasoningQuestion? paperFold() {
    final left = _halfLines(2);
    final rightAsLeft = _halfLines(2); // the right half's lines, seen after folding
    if (left.isEmpty || rightAsLeft.isEmpty || rightAsLeft.every(left.contains)) return null;
    final right = _mapSegs(rightAsLeft, (x, y) => (4 - x, y));
    LineFig half(Set<(int, int, int, int)> s) => LineFig(2, 4, frame: true, segs: s);
    final slid = _mapSegs(rightAsLeft, (x, y) => (2 - x, y));
    final upside = _mapSegs(rightAsLeft, (x, y) => (x, 4 - y));
    final leftFlipped = _mapSegs(left, (x, y) => (2 - x, y));
    final opts = [
      half({...left, ...rightAsLeft}),
      half({...left, ...slid}),
      half({...left, ...upside}),
      half({...leftFlipped, ...rightAsLeft}),
    ];
    if ({for (final o in opts) o.key}.length < 4) return null;
    final sheet = LineFig(4, 4, frame: true, segs: {...left, ...right}).toMap()..['fold'] = [2, 0, 2, 4];
    return _question('punch_hole', 'paper_fold', {'type': 'paper_fold', 'sheet': sheet}, [for (final o in opts) o.toMap()]);
  }
}
