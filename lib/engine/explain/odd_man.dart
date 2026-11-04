import 'dart:ui' show Color, Offset, Size;

import '../morph.dart';
import '../reasoning_question.dart';
import '../scene.dart';

/// The odd one's outline.
const oddRed = Color(0xFFDC2626);

/// Odd Man Out: show what the three alike options share, outline the odd one
/// in red; the reveal frames it green.
Scene? oddManScene(ReasoningQuestion q) {
  if (q.options.length != 4) return null;
  final opts = [for (final o in q.options) Morph.plain(o)];
  final odd = q.correctIndex;
  final alike = [for (int i = 0; i < 4; i++) if (i != odd) i];
  final steps = switch (q.type) {
    'odd_man_mirror' => _lineUp(opts, odd, alike, (b) => b is TurnBeat),
    'odd_letters' || 'odd_letters_medium' => _lineUp(opts, odd, alike, (b) => b is GlideBeat),
    'odd_count' || 'odd_man_translational_numerosity' => _count(opts, odd, alike),
    'odd_man_arithmetic' => _arithmetic(opts, odd, alike),
    'odd_man_rotational_repetition' => _nested(opts, odd, alike, turn: true),
    'odd_man_scaling_repetition' => _nested(opts, odd, alike, turn: false),
    _ => _onePart(opts, odd, alike),
  };
  if (steps == null) return null;
  const size = 64.0, gap = 14.0;
  return Scene(
    extent: const Size(4 * size + 3 * gap, size + 22),
    slots: [for (int i = 0; i < 4; i++) Slot(figure: opts[i], at: Offset(i * (size + gap), 0), size: size)],
    steps: [...steps, const RevealStep()],
    answerSlot: odd,
  );
}

PulseStep _red(int odd) => PulseStep([odd], colour: oddRed, stay: true, weight: 0.7);

/// Turned copies (or the same letters): each alike option flies onto the
/// first, turning (letters gliding) until it matches; the odd one can't.
List<SceneStep>? _lineUp(List<Map<String, dynamic>> opts, int odd, List<int> alike, bool Function(Beat) ok) {
  final ref = alike.first;
  final flies = <SceneStep>[];
  for (final i in alike.skip(1)) {
    final beats = Morph.diff(opts[i], opts[ref]);
    if (beats == null || !beats.every(ok)) return null;
    flies.add(FlyStep(i, ref, beats, figure: opts[i], weight: 1.2));
  }
  return [...flies, _red(odd)];
}

/// The three alike options are the same figure; a copy of one changes into
/// the odd one, showing the part that differs.
List<SceneStep>? _onePart(List<Map<String, dynamic>> opts, int odd, List<int> alike) {
  final ref = alike.first;
  if (!alike.every((i) => Morph.same(opts[i], opts[ref]))) return null;
  final beats = Morph.diff(opts[ref], opts[odd]);
  if (beats == null || beats.isEmpty) return null;
  return [
    PulseStep(alike, weight: 0.7),
    FlyStep(ref, odd, beats, figure: opts[ref], weight: 1.4),
    _red(odd),
  ];
}

List<Map<String, dynamic>> _features(Map<String, dynamic> f) => [
      for (final l in f['layers'] as List? ?? const [])
        for (final x in (l as Map)['features'] as List? ?? const []) Morph.plain(x as Map),
    ];

/// Single-layer cell with [features] in place of its own.
Map<String, dynamic>? _withFeatures(Map<String, dynamic> f, List<Map<String, dynamic>> features) {
  final layers = f['layers'];
  if (layers is! List || layers.length != 1) return null;
  return {
    ...f,
    'layers': [
      {...Morph.plain(layers.first as Map), 'features': features},
    ],
  };
}

/// What can be counted in a figure, by name.
Map<String, int> _counts(Map<String, dynamic> f) {
  if (f['type'] == 'sandia_cell') return {'features': _features(f).length};
  final out = <String, int>{};
  for (final k in ['segs', 'cells', 'tris', 'dots', 'rings', 'glyphs']) {
    final l = f[k];
    if (l is List) out[k] = l.length;
  }
  for (final g in f['glyphs'] as List? ?? const []) {
    final name = 'glyph:${(g as List)[2]}';
    out[name] = (out[name] ?? 0) + 1;
  }
  return out;
}

/// Ticks under each option, one per item counted: three rows are equally
/// long, the odd one's isn't.
List<SceneStep>? _count(List<Map<String, dynamic>> opts, int odd, List<int> alike) {
  final counts = [for (final o in opts) _counts(o)];
  final names = (counts[odd].keys.toSet()..addAll(counts[alike.first].keys)).toList()..sort();
  for (final name in names) {
    final n = [for (final c in counts) c[name] ?? 0];
    if (alike.every((i) => n[i] == n[alike.first]) && n[odd] != n[alike.first]) {
      return [
        TogetherStep([
          for (int i = 0; i < 4; i++) TickStep(i, n[i], colour: i == odd ? oddRed : const TickStep(0, 0).colour),
        ], weight: 2.0),
        _red(odd),
      ];
    }
  }
  return null;
}

/// Dots: the top and middle rows slide down onto the bottom row. In the
/// alike options they cover it exactly; in the odd one a dot is left over
/// or missing. Then the dots slide back.
List<SceneStep>? _arithmetic(List<Map<String, dynamic>> opts, int odd, List<int> alike) {
  final down = <Map<String, dynamic>>[];
  for (final o in opts) {
    final f = _features(o);
    final dots = [for (int k = 0; k < f.length; k++) if (f[k]['shape'] == 'ellipse') k];
    if (dots.isEmpty) return null;
    double cy(int k) => (f[k]['cy'] as num).toDouble();
    double cx(int k) => (f[k]['cx'] as num).toDouble();
    final bottomY = dots.map(cy).reduce((a, b) => a > b ? a : b);
    final bottom = dots.where((k) => (cy(k) - bottomY).abs() < 0.01).toList()..sort((a, b) => cx(a).compareTo(cx(b)));
    final movers = dots.where((k) => (cy(k) - bottomY).abs() >= 0.01).toList()
      ..sort((a, b) => cy(a) != cy(b) ? cy(a).compareTo(cy(b)) : cx(a).compareTo(cx(b)));
    if (movers.isEmpty) return null;
    final moved = [for (final x in f) {...x}];
    for (int j = 0; j < movers.length; j++) {
      final double x = j < bottom.length
          ? cx(bottom[j])
          : (bottom.isEmpty ? 0.2 : cx(bottom.last)) + 0.14 * (j - bottom.length + (bottom.isEmpty ? 0 : 1));
      moved[movers[j]]['cx'] = x.clamp(0.08, 0.92);
      moved[movers[j]]['cy'] = bottomY;
    }
    final d = _withFeatures(o, moved);
    if (d == null) return null;
    down.add(d);
  }
  final there = [for (int i = 0; i < 4; i++) Morph.diff(opts[i], down[i])];
  final back = [for (int i = 0; i < 4; i++) Morph.diff(down[i], opts[i])];
  if ([...there, ...back].any((b) => b == null || b.isEmpty)) return null;
  return [
    TogetherStep([for (int i = 0; i < 4; i++) MorphStep(i, there[i]!)], weight: 1.8),
    _red(odd),
    TogetherStep([for (int i = 0; i < 4; i++) MorphStep(i, back[i]!)], weight: 0.8),
  ];
}

/// An inner copy of the outer shape: every inner copy turns (or grows) by the
/// amount the alike options share; there it lands exactly on the outer
/// shape, in the odd one it doesn't. Then the copies go back.
List<SceneStep>? _nested(List<Map<String, dynamic>> opts, int odd, List<int> alike, {required bool turn}) {
  num? amount;
  final moved = <Map<String, dynamic>>[];
  for (final i in [...alike, odd]) {
    final f = _features(opts[i]);
    if (f.length != 2) return null;
    final (outer, inner) = (f[0], f[1]);
    final a = turn
        ? (((inner['rot'] as num) - (outer['rot'] as num)) % 360)
        : (outer['w'] as num) / (inner['w'] as num);
    if (i != odd) {
      amount ??= a;
      if ((a - amount).abs() > 1e-6) return null;
    }
  }
  if (amount == null) return null;
  for (int i = 0; i < 4; i++) {
    final f = _features(opts[i]);
    final inner = f[1];
    f[1] = turn
        ? {...inner, 'rot': ((inner['rot'] as num) - amount) % 360}
        : {...inner, 'w': (inner['w'] as num) * amount, 'h': (inner['h'] as num) * amount};
    final m = _withFeatures(opts[i], f);
    if (m == null) return null;
    moved.add(m);
  }
  final there = [for (int i = 0; i < 4; i++) Morph.diff(opts[i], moved[i])];
  final back = [for (int i = 0; i < 4; i++) Morph.diff(moved[i], opts[i])];
  if ([...there, ...back].any((b) => b == null || b.isEmpty)) return null;
  return [
    TogetherStep([for (int i = 0; i < 4; i++) MorphStep(i, there[i]!)], weight: 1.8),
    _red(odd),
    TogetherStep([for (int i = 0; i < 4; i++) MorphStep(i, back[i]!)], weight: 0.8),
  ];
}
