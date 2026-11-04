import 'dart:convert';
import 'dart:math';

import 'line_figure.dart';
import 'morph.dart';

/// The line-drawing part of [Morph] (`'line_fig'` maps).
///
/// A line figure has a *body* (segments, arcs, arrows) and *tokens* that sit
/// in a cell or on a point (dots, rings, symbols, the black triangles of a
/// cell, a cell's hatching, black cells). The diff finds the turn or flip
/// that best carries the body of one figure onto the other, then glides the
/// tokens to their new places, and adds or removes what's left.
class MorphLine {
  MorphLine._();

  static const _sets = ['segs', 'cells', 'tris', 'dots', 'rings', 'arrows', 'hatch', 'arcs', 'glyphs'];

  static String _num(dynamic v) => v is num ? ((v * 1e6).round() / 1e6).toString() : '$v';

  /// A canonical string: element lists compared as sets, segments with
  /// their ends in order.
  static String canon(Map<String, dynamic> f) {
    if (f['center'] == true) return canon(uncentred(f));
    final out = <String, dynamic>{};
    for (final k in _sets) {
      final items = <String>{};
      for (final e in (f[k] as List? ?? const [])) {
        var l = [for (final x in e as List) _num(x)];
        if (k == 'segs') {
          final p = '${l[0]},${l[1]}', q = '${l[2]},${l[3]}';
          if (p.compareTo(q) > 0) l = [l[2], l[3], l[0], l[1]];
        }
        items.add(l.join(','));
      }
      out[k] = items.toList()..sort();
    }
    for (final k in ['w', 'h']) {
      out[k] = _num(f[k]);
    }
    out['frame'] = f['frame'] == true;
    if (f['fold'] != null) out['fold'] = [for (final x in f['fold'] as List) _num(x)];
    if (f['center'] == true) out['center'] = true;
    if (((f['turn'] as num?) ?? 0) != 0) out['turn'] = _num(f['turn']);
    if (((f['flip'] as num?) ?? 1) != 1) out['flip'] = _num(f['flip']);
    if (((f['zoom'] as num?) ?? 1) != 1) out['zoom'] = _num(f['zoom']);
    return jsonEncode(out);
  }

  /// A `'center': true` figure (drawn centred in its box) written as the
  /// same drawing without centring: every position shifted so the content
  /// sits where the painter would centre it (same rule as
  /// LineFigurePainter). Others are returned unchanged.
  static Map<String, dynamic> uncentred(Map<String, dynamic> f) {
    if (f['center'] != true) return f;
    List<List<num>> l(String k) => [for (final e in (f[k] as List? ?? const [])) (e as List).sublist(0, k == 'glyphs' ? 2 : null).cast<num>()];
    final xs = <num>[], ys = <num>[];
    for (final s in l('segs')) {
      xs..add(s[0].floor())..add(s[2].ceil());
      ys..add(s[1].floor())..add(s[3].ceil());
    }
    for (final c in [...l('cells'), ...l('dots'), ...l('tris'), ...l('hatch'), ...l('glyphs')]) {
      xs..add(c[0].floor())..add(c[0].ceil() + 1);
      ys..add(c[1].floor())..add(c[1].ceil() + 1);
    }
    for (final a in l('arrows')) {
      xs..add(a[0])..add(a[2]);
      ys..add(a[1])..add(a[3]);
    }
    for (final a in l('arcs')) {
      final (sx, sy) = LineFig.arcQuadrants[a[3].toInt()];
      xs..add((a[0] / 2).floor())..add(((a[0] + sx * a[2]) / 2).round());
      ys..add((a[1] / 2).floor())..add(((a[1] + sy * a[2]) / 2).round());
    }
    final out = Map<String, dynamic>.of(f)..remove('center');
    if (xs.isEmpty) return out;
    final dx = (f['w'] as num) / 2 - (xs.reduce(min) + xs.reduce(max)) / 2;
    final dy = (f['h'] as num) / 2 - (ys.reduce(min) + ys.reduce(max)) / 2;
    List<List<Object>> shift(String k, List<int> xi, List<int> yi, {num mul = 1}) => [
          for (final e in (f[k] as List? ?? const []))
            [
              for (int i = 0; i < (e as List).length; i++)
                xi.contains(i) ? (e[i] as num) + dx * mul : yi.contains(i) ? (e[i] as num) + dy * mul : e[i] as Object,
            ],
        ];
    for (final k in ['cells', 'dots', 'rings', 'tris', 'hatch', 'glyphs']) {
      if (f.containsKey(k)) out[k] = shift(k, [0], [1]);
    }
    for (final k in ['segs', 'arrows']) {
      if (f.containsKey(k)) out[k] = shift(k, [0, 2], [1, 3]);
    }
    if (f.containsKey('arcs')) out['arcs'] = shift('arcs', [0], [1], mul: 2);
    return out;
  }

  /// [fig] as a map, keeping [like]'s other keys (fold, center, ...).
  static Map<String, dynamic> _map(LineFig fig, Map<String, dynamic> like) =>
      {for (final e in like.entries) if (!_sets.contains(e.key) && e.key != 'w' && e.key != 'h') e.key: e.value, ...fig.toMap()};

  // ── Ops ───────────────────────────────────────────────────────────────────

  /// A turn by 45° about the centre (clockwise if [cw]) that keeps the
  /// figure on the lattice: a straight line becomes a diagonal one √2 longer
  /// ([up]) or a diagonal one becomes straight, 1/√2 as long. Null if a part
  /// would fall off the lattice or can't turn by 45° (cells, symbols ...).
  static LineFig? turn45(LineFig f, {required bool cw, required bool up}) {
    if (f.w != f.h || f.cells.isNotEmpty || f.tris.isNotEmpty || f.hatch.isNotEmpty || f.arcs.isNotEmpty || f.glyphs.isNotEmpty || f.dots.isNotEmpty) return null;
    final c = f.w; // doubled centre
    (int, int)? pt(int x, int y) {
      final X = 2 * x - c, Y = 2 * y - c;
      var (nx, ny) = cw ? (X - Y, X + Y) : (X + Y, Y - X);
      if (!up) {
        if (nx % 2 != 0 || ny % 2 != 0) return null;
        nx ~/= 2;
        ny ~/= 2;
      }
      final rx = nx + c, ry = ny + c;
      if (rx % 2 != 0 || ry % 2 != 0) return null;
      final (px, py) = (rx ~/ 2, ry ~/ 2);
      if (px < 0 || py < 0 || px > f.w || py > f.h) return null;
      return (px, py);
    }

    (int, int, int, int)? seg((int, int, int, int) s) {
      final a = pt(s.$1, s.$2), b = pt(s.$3, s.$4);
      return a == null || b == null ? null : (a.$1, a.$2, b.$1, b.$2);
    }

    final segs = <(int, int, int, int)>{};
    for (final s in f.segs) {
      final r = seg(s);
      if (r == null) return null;
      // A turned unit segment may span two lattice steps: split it.
      segs.addAll(LineFig.line(r.$1, r.$2, r.$3, r.$4));
    }
    final arrows = <(int, int, int, int)>{};
    for (final s in f.arrows) {
      final r = seg(s);
      if (r == null) return null;
      arrows.add(r);
    }
    final rings = <(int, int)>{};
    for (final (x, y) in f.rings) {
      final r = pt(x, y);
      if (r == null) return null;
      rings.add(r);
    }
    return LineFig(f.w, f.h, frame: f.frame, segs: segs, arrows: arrows, rings: rings);
  }

  // ── Tokens ────────────────────────────────────────────────────────────────

  /// Tokens by kind: anchor point -> what's there. Triangles and hatching of
  /// one cell travel together.
  static Map<String, List<(int, int)>> _tokens(LineFig f) {
    final out = <String, List<(int, int)>>{};
    void add(String kind, (int, int) at) => (out[kind] ??= []).add(at);
    for (final d in f.dots) {
      add('dot', d);
    }
    for (final r in f.rings) {
      add('ring', r);
    }
    for (final c in f.cells) {
      add('cell', c);
    }
    for (final (x, y, g) in f.glyphs) {
      add('glyph:$g', (x, y));
    }
    final tris = <(int, int), List<int>>{};
    for (final (x, y, k) in f.tris) {
      (tris[(x, y)] ??= []).add(k);
    }
    for (final e in tris.entries) {
      add('tri:${(e.value..sort()).join(',')}', e.key);
    }
    final hatch = <(int, int), List<String>>{};
    for (final (x, y, p, d) in f.hatch) {
      (hatch[(x, y)] ??= []).add('$p/$d');
    }
    for (final e in hatch.entries) {
      add('hatch:${(e.value..sort()).join(',')}', e.key);
    }
    return out;
  }

  static double _dist((int, int) a, (int, int) b) => sqrt(pow(a.$1 - b.$1, 2) + pow(a.$2 - b.$2, 2).toDouble());

  /// Pairs each token of [a] with one of [b] of the same kind, closest first
  /// overall (exact for small sets). Returns pairs and the total distance;
  /// unpaired tokens count 50 each.
  static (List<(String, (int, int), (int, int))>, double) _match(Map<String, List<(int, int)>> a, Map<String, List<(int, int)>> b) {
    final pairs = <(String, (int, int), (int, int))>[];
    var cost = 0.0;
    for (final kind in {...a.keys, ...b.keys}) {
      final xs = a[kind] ?? const [], ys = b[kind] ?? const [];
      cost += 50.0 * (xs.length - ys.length).abs();
      final n = min(xs.length, ys.length);
      if (n == 0) continue;
      // Best assignment of the shorter list into the longer one.
      List<int>? best;
      var bestCost = double.infinity;
      final small = xs.length <= ys.length;
      final from = small ? xs : ys, to = small ? ys : xs;
      if (to.length <= 7) {
        void search(List<int> chosen, double c) {
          if (c >= bestCost) return;
          if (chosen.length == from.length) {
            bestCost = c;
            best = List.of(chosen);
            return;
          }
          for (int j = 0; j < to.length; j++) {
            if (chosen.contains(j)) continue;
            search([...chosen, j], c + _dist(from[chosen.length], to[j]));
          }
        }

        search([], 0);
      } else {
        final used = <int>{};
        best = [];
        bestCost = 0;
        for (final p in from) {
          var bj = -1;
          for (int j = 0; j < to.length; j++) {
            if (!used.contains(j) && (bj < 0 || _dist(p, to[j]) < _dist(p, to[bj]))) bj = j;
          }
          used.add(bj);
          best.add(bj);
          bestCost += _dist(p, to[bj]);
        }
      }
      cost += bestCost;
      for (int i = 0; i < from.length; i++) {
        final (p, q) = (from[i], to[best![i]]);
        pairs.add(small ? (kind, p, q) : (kind, q, p));
      }
    }
    return (pairs, cost);
  }

  static int _bodyDiff(LineFig a, LineFig b) =>
      a.segs.difference(b.segs).length +
      b.segs.difference(a.segs).length +
      a.arcs.difference(b.arcs).length +
      b.arcs.difference(a.arcs).length +
      a.arrows.difference(b.arrows).length +
      b.arrows.difference(a.arrows).length;

  // ── Diff ──────────────────────────────────────────────────────────────────

  static List<Beat>? diff(Map<String, dynamic> a, Map<String, dynamic> b, int turnSign) {
    late final LineFig fa, fb;
    try {
      fa = LineFig.fromMap(a);
      fb = LineFig.fromMap(b);
    } catch (_) {
      return null;
    }
    final tb = _tokens(fb);
    // Candidate ops: (beats builder, result, penalty). Plain turns before
    // flips, smaller turns first.
    final ops = <(String, LineFig, double)>[
      ('id', fa, 0),
      ('r1', fa.rot(1), 0.2),
      ('r3', fa.rot(3), 0.2),
      ('r2', fa.rot(2), 0.3),
      for (int r = 0; r < 4; r++) ('m$r', fa.mirrorX().rot(r), 0.4 + 0.1 * r),
      // Turns by 45° and 135° (a quarter turn first): the clockwise 45°
      // after r quarter turns is a turn by 90r + 45, shown the short way.
      for (int r = 0; r < 4; r++)
        for (final up in [true, false])
          if (turn45(fa.rot(r), cw: true, up: up) case final t?) ('t$r${up ? 'u' : 'd'}', t, r == 0 || r == 3 ? 0.25 : 0.35),
    ];
    (String, LineFig, double)? best;
    var bestScore = double.infinity;
    for (final op in ops) {
      if (op.$2.w != fb.w || op.$2.h != fb.h) continue;
      final score = _bodyDiff(op.$2, fb) * 1000 + _match(_tokens(op.$2), tb).$2 + op.$3;
      if (score < bestScore) {
        bestScore = score;
        best = op;
      }
    }
    final bodySize = max(1, fb.segs.length + fb.arcs.length + fb.arrows.length);
    if (best == null || _bodyDiff(best.$2, fb) > max(4, bodySize ~/ 3)) {
      return _regroup(a, b, fa, fb);
    }

    final beats = <Beat>[];
    var cur = a;
    var curFig = fa;
    void step(Beat Function(Map<String, dynamic>, Map<String, dynamic>) make, LineFig next) {
      final m = _map(next, a);
      beats.add(make(cur, m));
      cur = m;
      curFig = next;
    }

    final op = best.$1;
    if (op.startsWith('m')) {
      step((f, t) => FlipBeat(f, t), fa.mirrorX());
    }
    final quarters = switch (op) { 'r1' || 'm1' => 1, 'r3' || 'm3' => -1, 'r2' || 'm2' => 2 * turnSign, _ => 0 };
    if (quarters != 0) step((f, t) => TurnBeat(f, t, 90.0 * quarters), best.$2);
    if (op.startsWith('t')) {
      final deg = (90 * int.parse(op[1]) + 45 + 180) % 360 - 180;
      step((f, t) => TurnBeat(f, t, deg.toDouble(), zoom: op[2] == 'u' ? sqrt2 : 1 / sqrt2), best.$2);
    }
    if (_bodyDiff(curFig, fb) > 0) {
      step((f, t) => SwapBeat(f, t, {'lines'}), curFig.copyWith(segs: fb.segs, arcs: fb.arcs, arrows: fb.arrows));
    }
    // Tokens glide; written in the same order in both ends so the frames
    // in between are a straight blend.
    final (pairs, _) = _match(_tokens(curFig), tb);
    if (pairs.any((p) => p.$2 != p.$3)) {
      final (from, to) = (_tokenMap(curFig, cur, pairs, false), _tokenMap(curFig, cur, pairs, true));
      beats.add(GlideBeat(from, to));
      cur = to;
    }
    if (!Morph.same(cur, b)) beats.add(SwapBeat(cur, b, {'tokens'}));
    return beats;
  }

  /// [fig] with its paired tokens written pair by pair, at their own place
  /// or ([moved]) at their partner's.
  static Map<String, dynamic> _tokenMap(LineFig fig, Map<String, dynamic> like, List<(String, (int, int), (int, int))> pairs, bool moved) {
    final m = _map(fig, like);
    final out = <String, List<List<Object>>>{'dots': [], 'rings': [], 'cells': [], 'glyphs': [], 'tris': [], 'hatch': []};
    final paired = <String>{};
    for (final (kind, p, q) in pairs) {
      final (x, y) = moved ? q : p;
      paired.add('$kind@${p.$1},${p.$2}');
      if (kind == 'dot') out['dots']!.add([x, y]);
      if (kind == 'ring') out['rings']!.add([x, y]);
      if (kind == 'cell') out['cells']!.add([x, y]);
      if (kind.startsWith('glyph:')) out['glyphs']!.add([x, y, kind.substring(6)]);
      if (kind.startsWith('tri:')) {
        for (final k in kind.substring(4).split(',')) {
          out['tris']!.add([x, y, int.parse(k)]);
        }
      }
      if (kind.startsWith('hatch:')) {
        for (final ph in kind.substring(6).split(',')) {
          final [part, dir] = ph.split('/');
          out['hatch']!.add([x, y, int.parse(part), int.parse(dir)]);
        }
      }
    }
    // Unpaired tokens stay where they are (a later swap adds/removes them).
    for (final e in _tokens(fig).entries) {
      for (final at in e.value) {
        if (paired.contains('${e.key}@${at.$1},${at.$2}')) continue;
        _tokenMap(fig, like, [(e.key, at, at)], false).forEach((k, v) {
          if (out.containsKey(k)) out[k]!.addAll([for (final x in v as List) (x as List).cast<Object>()]);
        });
      }
    }
    for (final e in out.entries) {
      m[e.key] = e.value;
    }
    return m;
  }

  // ── Regrouping (the "nest" analogy: shapes drawn apart, then inside each
  // other) ───────────────────────────────────────────────────────────────

  /// Each separate shape of [fig] as its own figure on [fig]'s lattice.
  static List<Map<String, dynamic>> pieces(LineFig fig, Map<String, dynamic> like) {
    final parent = <(int, int), (int, int)>{};
    (int, int) find((int, int) p) {
      while (parent[p] != p) {
        p = parent[p] = parent[parent[p]!]!;
      }
      return p;
    }

    void union((int, int) a, (int, int) b) {
      parent.putIfAbsent(a, () => a);
      parent.putIfAbsent(b, () => b);
      parent[find(a)] = find(b);
    }

    for (final (x1, y1, x2, y2) in fig.segs) {
      union((x1, y1), (x2, y2));
    }
    final groups = <(int, int), List<(int, int, int, int)>>{};
    for (final s in fig.segs) {
      (groups[find((s.$1, s.$2))] ??= []).add(s);
    }
    final circles = <String, List<(int, int, int, int)>>{};
    for (final a in fig.arcs) {
      (circles['${a.$1},${a.$2},${a.$3}'] ??= []).add(a);
    }
    return [
      for (final g in groups.values) _map(LineFig(fig.w, fig.h, segs: g.toSet()), like),
      for (final c in circles.values) _map(LineFig(fig.w, fig.h, arcs: c.toSet()), like),
    ];
  }

  /// The straight lines of [segs], merged from unit segments.
  static List<(int, int, int, int)> lines(Set<(int, int, int, int)> segs) {
    final lines = <(int, int, int, int)>[];
    final left = Set.of(segs);
    while (left.isNotEmpty) {
      var (x1, y1, x2, y2) = left.first;
      left.remove(left.first);
      final dx = (x2 - x1).sign, dy = (y2 - y1).sign;
      while (left.remove(LineFig.line(x2, y2, x2 + dx, y2 + dy).first)) {
        x2 += dx;
        y2 += dy;
      }
      while (left.remove(LineFig.line(x1 - dx, y1 - dy, x1, y1).first)) {
        x1 -= dx;
        y1 -= dy;
      }
      lines.add((x1, y1, x2, y2));
    }
    return lines;
  }

  static String _linesKey(List<(int, int, int, int)> lines) {
    final xs = [for (final l in lines) ...[l.$1, l.$3]], ys = [for (final l in lines) ...[l.$2, l.$4]];
    final mx = xs.reduce(min), my = ys.reduce(min);
    final ext = max(xs.reduce(max) - mx, ys.reduce(max) - my);
    String n(int v, int o) => ((v - o) / ext * 1000).round().toString();
    final keys = [
      for (final l in lines)
        () {
          final p = '${n(l.$1, mx)},${n(l.$2, my)}', q = '${n(l.$3, mx)},${n(l.$4, my)}';
          return p.compareTo(q) < 0 ? '$p-$q' : '$q-$p';
        }(),
    ]..sort();
    return keys.join(';');
  }

  /// A key that is the same for a shape moved or scaled: its straight
  /// lines as fractions of its bounding box.
  static String shapeKey(Map<String, dynamic> piece) {
    final f = LineFig.fromMap(piece);
    if (f.segs.isEmpty) return 'circle:${f.arcs.length}';
    return _linesKey(lines(f.segs));
  }

  static Set<(int, int, int, int)> _unit(Iterable<(int, int, int, int)> ls) => {for (final l in ls) ...LineFig.line(l.$1, l.$2, l.$3, l.$4)};

  static List<Beat>? _regroup(Map<String, dynamic> a, Map<String, dynamic> b, LineFig fa, LineFig fb) {
    if (fa.cells.isNotEmpty || fa.tris.isNotEmpty || fa.dots.isNotEmpty || fa.glyphs.isNotEmpty || fa.rings.isNotEmpty) return null;
    if (fb.cells.isNotEmpty || fb.tris.isNotEmpty || fb.dots.isNotEmpty || fb.glyphs.isNotEmpty || fb.rings.isNotEmpty) return null;
    // The shapes of [a] are drawn apart; in [b] they may touch, so each is
    // looked for among [b]'s straight lines (and circles).
    final pa = pieces(fa, a);
    if (pa.length < 2) return null;
    final lb = lines(fb.segs);
    final usedLines = <int>{};
    final circles = <String, Set<(int, int, int, int)>>{};
    for (final x in fb.arcs) {
      (circles['${x.$1},${x.$2},${x.$3}'] ??= {}).add(x);
    }
    final usedCircles = <String>{};
    final pairs = <(Map<String, dynamic>, Map<String, dynamic>)>[];
    // Biggest shapes first: fewer ways to place them.
    final order = [for (int i = 0; i < pa.length; i++) i]..sort((x, y) => LineFig.fromMap(pa[y]).segs.length.compareTo(LineFig.fromMap(pa[x]).segs.length));
    for (final i in order) {
      final p = LineFig.fromMap(pa[i]);
      if (p.segs.isEmpty) {
        final c = circles.keys.firstWhere((k) => !usedCircles.contains(k) && circles[k]!.length == p.arcs.length, orElse: () => '');
        if (c.isEmpty) return null;
        usedCircles.add(c);
        pairs.add((pa[i], _map(LineFig(fb.w, fb.h, arcs: circles[c]!), b)));
        continue;
      }
      final key = _linesKey(lines(p.segs)), k = lines(p.segs).length;
      final free = [for (int j = 0; j < lb.length; j++) if (!usedLines.contains(j)) j];
      List<int>? found;
      void search(int from, List<int> chosen) {
        if (found != null) return;
        if (chosen.length == k) {
          if (_linesKey([for (final j in chosen) lb[j]]) == key) found = List.of(chosen);
          return;
        }
        for (int x = from; x < free.length; x++) {
          search(x + 1, [...chosen, free[x]]);
        }
      }

      if (free.length > 16) return null;
      search(0, []);
      if (found == null) return null;
      usedLines.addAll(found!);
      pairs.add((pa[i], _map(LineFig(fb.w, fb.h, segs: _unit([for (final j in found!) lb[j]])), b)));
    }
    if (usedLines.length != lb.length || usedCircles.length != circles.length) return null;
    return [RegroupBeat(a, b, [for (final i in [for (int i = 0; i < pa.length; i++) i]) pairs[order.indexOf(i)]])];
  }

  // ── Frames ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> turnFrame(TurnBeat beat, double t) =>
      {...beat.from, 'turn': beat.degrees / 90 * t, if (beat.zoom != 1) 'zoom': 1 + (beat.zoom - 1) * t};

  static Map<String, dynamic> flipFrame(FlipBeat beat, double t) =>
      t < 0.5 ? {...beat.from, 'flip': cos(pi * t)} : {...beat.to, 'flip': -cos(pi * t)};
}
