import 'dart:convert';
import 'dart:math';

import 'morph_line.dart';

/// The kinds of figure maps the app draws (see OptionRenderer).
enum FigureKind { classic, line, sandiaLayers, sandiaFeatures, letters, geoPiece }

/// One single change between two figures, as two real figure maps: [from]
/// and [to] differ only in that change. An answer explanation plays a chain
/// of beats; [Morph.frame] gives the figure in between.
sealed class Beat {
  final Map<String, dynamic> from, to;

  /// Which part changes: null = the whole figure; otherwise a short path
  /// such as 'L1' (layer 1) or 'features' (several features at once).
  final String? part;
  const Beat(this.from, this.to, {this.part});
}

/// A turn by [degrees] (clockwise positive).
class TurnBeat extends Beat {
  final double degrees;

  /// Line drawings turned by 45° also stretch (or shrink) by √2 to stay on
  /// the lattice.
  final double zoom;
  const TurnBeat(super.from, super.to, this.degrees, {super.part, this.zoom = 1});
}

/// The whole figure flips over a vertical line (mirror image).
class FlipBeat extends Beat {
  const FlipBeat(super.from, super.to);
}

/// A part grows or shrinks.
class ResizeBeat extends Beat {
  const ResizeBeat(super.from, super.to, {super.part});
}

/// A part slides to a new place.
class MoveBeat extends Beat {
  const MoveBeat(super.from, super.to, {super.part});
}

/// Tokens (dots, rings, symbols, letters) glide to new places. For letters,
/// [tokens] maps each letter's index in [from] to its index in [to].
class GlideBeat extends Beat {
  final List<(int, int)> tokens;
  const GlideBeat(super.from, super.to, {this.tokens = const []});
}

/// Separate shapes of a line drawing move (and grow or shrink) to new
/// places, e.g. drawn apart in one figure and inside each other in the
/// next. [pieces] pairs each shape as drawn in [from] with itself in [to].
class RegroupBeat extends Beat {
  final List<(Map<String, dynamic>, Map<String, dynamic>)> pieces;
  const RegroupBeat(super.from, super.to, this.pieces);
}

/// A part changes into something else (shape, fill, count, detail): shown
/// as a cross-fade with a green flash. [changed] names what changed.
class SwapBeat extends Beat {
  final Set<String> changed;
  const SwapBeat(super.from, super.to, this.changed, {super.part});
}

class Morph {
  Morph._();

  /// A deep copy as plain JSON-like data (maps restored from Hive come back
  /// as `Map<dynamic, dynamic>`).
  static Map<String, dynamic> plain(Map m) => {for (final e in m.entries) '${e.key}': _plainValue(e.value)};
  static dynamic _plainValue(dynamic v) => v is Map ? plain(v) : v is List ? [for (final x in v) _plainValue(x)] : v;

  static FigureKind? kindOf(Map fig) {
    final type = fig['type'];
    if (type == 'line_fig') return FigureKind.line;
    if (type == 'mirror_text') return FigureKind.letters;
    if (type == 'geo_piece') return FigureKind.geoPiece;
    if (type == 'sandia_cell') {
      final layers = fig['layers'] as List? ?? const [];
      return layers.any((l) => (l as Map).containsKey('features')) ? FigureKind.sandiaFeatures : FigureKind.sandiaLayers;
    }
    if (type == null && fig.containsKey('shape')) return FigureKind.classic;
    return null;
  }

  // ── Equality as drawn ─────────────────────────────────────────────────────

  static const _classicDefaults = <String, dynamic>{
    'shape': 0, 'filled': false, 'rotation': 0, 'mirror': false, 'dots': 0,
    'inner': 0, 'lines': 0, 'missingCorner': 0, 'dense': false, 'selective_mirror_trap': false,
  };

  /// True when [a] and [b] are the same figure (rotations compared modulo a
  /// full turn, 1 and 1.0 equal, defaults filled in).
  static bool same(Map a, Map b) => _canon(plain(a)) == _canon(plain(b));

  static String _canon(Map<String, dynamic> f) {
    final kind = kindOf(f);
    dynamic norm(dynamic v) {
      if (v is num) return (v * 1e6).round() / 1e6;
      if (v is Map) return {for (final k in (v.keys.toList()..sort())) k: norm(v[k])};
      if (v is List) return [for (final x in v) norm(x)];
      return v;
    }

    final g = plain(f);
    switch (kind) {
      case FigureKind.classic:
        for (final e in _classicDefaults.entries) {
          g.putIfAbsent(e.key, () => e.value);
        }
        g['rotation'] = _mod((g['rotation'] as num).toDouble(), 4);
      case FigureKind.sandiaLayers:
        for (final l in g['layers'] as List) {
          (l as Map)['rotation'] = _mod(((l['rotation'] as num?) ?? 0).toDouble(), 4);
        }
      case FigureKind.sandiaFeatures:
        for (final l in g['layers'] as List) {
          for (final f in ((l as Map)['features'] as List? ?? const [])) {
            (f as Map)['rot'] = _mod(((f['rot'] as num?) ?? 0).toDouble(), 360);
          }
        }
      case FigureKind.line:
        return MorphLine.canon(g);
      default:
        break;
    }
    return jsonEncode(norm(g));
  }

  static double _mod(double x, double m) {
    final r = x % m;
    return (r - m).abs() < 1e-6 ? 0 : r;
  }

  // ── Diff ──────────────────────────────────────────────────────────────────

  /// The chain of single changes that turns [a] into [b], or null if the
  /// difference can't be explained. Empty when they are the same.
  /// [turnSign] (+1 clockwise, -1 anticlockwise) picks the way of a half
  /// turn, which the figures alone leave open.
  static List<Beat>? diff(Map a, Map b, {int turnSign = 1}) {
    final pa = plain(a), pb = plain(b);
    final kind = kindOf(pa);
    if (kind == null || kind != kindOf(pb)) return null;
    if (same(pa, pb)) return const [];
    final beats = switch (kind) {
      FigureKind.classic => _classic(pa, pb, turnSign),
      FigureKind.sandiaLayers => _layers(pa, pb, turnSign),
      FigureKind.sandiaFeatures => _features(pa, pb, turnSign),
      FigureKind.letters => _letters(pa, pb),
      FigureKind.line => MorphLine.diff(pa, pb, turnSign),
      FigureKind.geoPiece => [SwapBeat(pa, pb, {for (final k in {...pa.keys, ...pb.keys}) if (jsonEncode(pa[k]) != jsonEncode(pb[k])) k})],
    };
    if (beats == null) return null;
    assert(beats.isEmpty || same(beats.last.to, pb));
    return beats;
  }

  /// Signed quarter turns from [ra] to [rb], or 0.
  static int _quarters(num ra, num rb, int turnSign) {
    final d = ((rb - ra).round() % 4 + 4) % 4;
    return switch (d) { 1 => 1, 3 => -1, 2 => 2 * turnSign, _ => 0 };
  }

  static double _degrees(num ra, num rb, int turnSign) {
    var d = ((rb - ra) % 360 + 360) % 360;
    if ((d - 180).abs() < 1e-6) return 180.0 * turnSign;
    if (d > 180) d -= 360;
    return d.toDouble();
  }

  static List<Beat> _classic(Map<String, dynamic> a, Map<String, dynamic> b, int turnSign) {
    final cur = {..._classicDefaults, ...a};
    final tgt = {..._classicDefaults, ...b};
    final beats = <Beat>[];
    void step(Beat Function(Map<String, dynamic> from, Map<String, dynamic> to) make, Map<String, dynamic> next) {
      beats.add(make(Map.of(cur), Map.of(next)));
      cur
        ..clear()
        ..addAll(next);
    }

    bool differs(String k) => jsonEncode(cur[k]) != jsonEncode(tgt[k]);
    if (differs('shape')) step((f, t) => SwapBeat(f, t, {'shape'}), {...cur, 'shape': tgt['shape']});
    final q = _quarters(cur['rotation'] as num, tgt['rotation'] as num, turnSign);
    if (q != 0) step((f, t) => TurnBeat(f, t, 90.0 * q), {...cur, 'rotation': tgt['rotation']});
    if (differs('rotation')) cur['rotation'] = tgt['rotation']; // same turn, other count of full turns
    if (differs('mirror')) step((f, t) => FlipBeat(f, t), {...cur, 'mirror': tgt['mirror']});
    for (final k in ['filled', 'inner', 'dots']) {
      if (differs(k)) step((f, t) => SwapBeat(f, t, {k}), {...cur, k: tgt[k]});
    }
    final rest = {for (final k in tgt.keys) if (differs(k)) k};
    if (rest.isNotEmpty) step((f, t) => SwapBeat(f, t, rest), Map.of(tgt));
    return beats;
  }

  static List<Map<String, dynamic>> _layerList(Map f) => [for (final l in f['layers'] as List? ?? const []) plain(l as Map)];

  static List<Beat> _layers(Map<String, dynamic> a, Map<String, dynamic> b, int turnSign) {
    final la = _layerList(a), lb = _layerList(b);
    if (la.length != lb.length) return [SwapBeat(a, b, {'layers'})];
    var cur = plain(a);
    final beats = <Beat>[];
    List<Map<String, dynamic>> layersOf(Map<String, dynamic> f) => _layerList(f);
    Map<String, dynamic> withKey(Map<String, dynamic> f, String k) {
      final ls = layersOf(f);
      for (int i = 0; i < ls.length; i++) {
        if (lb[i].containsKey(k)) {
          ls[i][k] = lb[i][k];
        } else {
          ls[i].remove(k);
        }
      }
      return {...f, 'layers': ls};
    }

    bool keyDiffers(String k) {
      final ls = layersOf(cur);
      return [for (int i = 0; i < ls.length; i++) jsonEncode(ls[i][k]) != jsonEncode(lb[i][k])].any((x) => x);
    }

    void add(Beat Function(Map<String, dynamic>, Map<String, dynamic>) make, Map<String, dynamic> next) {
      beats.add(make(cur, next));
      cur = next;
    }

    if (keyDiffers('surface')) add((f, t) => SwapBeat(f, t, {'surface'}), withKey(cur, 'surface'));
    // Turns: the whole figure when every layer turns the same way.
    final qs = [for (int i = 0; i < la.length; i++) _quarters((la[i]['rotation'] as num?) ?? 0, (lb[i]['rotation'] as num?) ?? 0, turnSign)];
    if (qs.any((q) => q != 0)) {
      if (qs.toSet().length == 1) {
        add((f, t) => TurnBeat(f, t, 90.0 * qs.first), withKey(cur, 'rotation'));
      } else {
        for (int i = 0; i < qs.length; i++) {
          if (qs[i] == 0) continue;
          final ls = layersOf(cur);
          ls[i]['rotation'] = lb[i]['rotation'];
          add((f, t) => TurnBeat(f, t, 90.0 * qs[i], part: 'L$i'), {...cur, 'layers': ls});
        }
      }
    }
    if (keyDiffers('rotation')) cur = withKey(cur, 'rotation');
    if (keyDiffers('scale')) add((f, t) => ResizeBeat(f, t, part: 'layers'), withKey(cur, 'scale'));
    for (final k in ['mirror_h', 'fill']) {
      if (keyDiffers(k)) add((f, t) => SwapBeat(f, t, {k}), withKey(cur, k));
    }
    final rest = {for (final l in lb) ...l.keys}.where(keyDiffers).toSet();
    final top = {for (final k in {...cur.keys, ...b.keys}) if (k != 'layers' && jsonEncode(cur[k]) != jsonEncode(b[k])) k};
    if (rest.isNotEmpty || top.isNotEmpty) add((f, t) => SwapBeat(f, t, {...rest, ...top}), plain(b));
    return beats;
  }

  // Sandia features: each layer holds features with shape, w, h, rot (degrees),
  // cx, cy (cell fractions), scale, fill, mirror.

  static List<List<Map<String, dynamic>>> _featureLists(Map f) =>
      [for (final l in _layerList(f)) [for (final x in (l['features'] as List? ?? const [])) plain(x as Map)]];

  static Map<String, dynamic> _withFeatures(Map<String, dynamic> f, List<List<Map<String, dynamic>>> fs) {
    final ls = _layerList(f);
    return {...f, 'layers': [for (int i = 0; i < ls.length; i++) {...ls[i], 'features': fs[i]}]};
  }

  /// The whole cell turned by [degrees] clockwise about its centre.
  static Map<String, dynamic> turnCell(Map<String, dynamic> f, double degrees) {
    final r = degrees * pi / 180, c = cos(r), s = sin(r);
    return _withFeatures(f, [
      for (final l in _featureLists(f))
        [
          for (final x in l)
            {
              ...x,
              'cx': 0.5 + (((x['cx'] as num?) ?? 0.5) - 0.5) * c - (((x['cy'] as num?) ?? 0.5) - 0.5) * s,
              'cy': 0.5 + (((x['cx'] as num?) ?? 0.5) - 0.5) * s + (((x['cy'] as num?) ?? 0.5) - 0.5) * c,
              // A mirrored feature is drawn mirror-then-turn, so the cell's
              // turn reads as the opposite turn in its own frame.
              'rot': ((x['rot'] as num?) ?? 0) + ((x['mirror'] == true) ? -degrees : degrees),
            },
        ],
    ]);
  }

  /// The whole cell mirrored left to right.
  static Map<String, dynamic> flipCell(Map<String, dynamic> f) => _withFeatures(f, [
        for (final l in _featureLists(f))
          [
            for (final x in l) {...x, 'cx': 1 - ((x['cx'] as num?) ?? 0.5), 'mirror': !(x['mirror'] == true)},
          ],
      ]);

  static List<Beat> _features(Map<String, dynamic> a, Map<String, dynamic> b, int turnSign) {
    final fa = _featureLists(a), fb = _featureLists(b);
    if (fa.length != fb.length) return [SwapBeat(a, b, {'layers'})];
    // The whole cell turned and/or mirrored.
    for (final flip in [false, true]) {
      final base = flip ? flipCell(a) : a;
      for (final deg in [0.0, 90.0, 180.0, 270.0]) {
        if (!flip && deg == 0) continue;
        final turned = deg == 0 ? base : turnCell(base, deg);
        if (!same(turned, b)) continue;
        final signed = deg == 270 ? -90.0 : deg == 180 ? 180.0 * turnSign : deg;
        return [
          if (flip) FlipBeat(a, base),
          if (deg != 0) TurnBeat(base, b, signed),
        ];
      }
    }
    // Feature by feature, one beat per kind of change.
    final beats = <Beat>[];
    var cur = plain(a);
    if ([for (int i = 0; i < fa.length; i++) fa[i].length != fb[i].length].any((x) => x)) {
      // Features added or removed: keep the ones that match, then swap.
      return [SwapBeat(a, b, {'count'})];
    }
    List<List<Map<String, dynamic>>> curF() => _featureLists(cur);
    bool differs(List<String> keys) {
      final c = curF();
      for (int i = 0; i < c.length; i++) {
        for (int j = 0; j < c[i].length; j++) {
          for (final k in keys) {
            if (k == 'rot') {
              if (_degrees((c[i][j]['rot'] as num?) ?? 0, (fb[i][j]['rot'] as num?) ?? 0, 1).abs() > 1e-6) return true;
            } else if (jsonEncode(c[i][j][k]) != jsonEncode(fb[i][j][k])) {
              return true;
            }
          }
        }
      }
      return false;
    }

    Map<String, dynamic> apply(List<String> keys) {
      final c = curF();
      for (int i = 0; i < c.length; i++) {
        for (int j = 0; j < c[i].length; j++) {
          for (final k in keys) {
            if (fb[i][j].containsKey(k)) {
              c[i][j][k] = fb[i][j][k];
            } else {
              c[i][j].remove(k);
            }
          }
        }
      }
      return _withFeatures(cur, c);
    }

    void add(Beat Function(Map<String, dynamic>, Map<String, dynamic>) make, List<String> keys) {
      final next = apply(keys);
      beats.add(make(cur, next));
      cur = next;
    }

    if (differs(['shape'])) add((f, t) => SwapBeat(f, t, {'shape'}, part: 'features'), ['shape']);
    if (differs(['rot'])) {
      final c = curF();
      final ds = <double>{
        for (int i = 0; i < c.length; i++)
          for (int j = 0; j < c[i].length; j++) _degrees((c[i][j]['rot'] as num?) ?? 0, (fb[i][j]['rot'] as num?) ?? 0, turnSign),
      }..remove(0.0);
      add((f, t) => TurnBeat(f, t, ds.length == 1 ? ds.first : double.nan, part: 'features'), ['rot']);
    }
    if (differs(['mirror'])) add((f, t) => SwapBeat(f, t, {'mirror'}, part: 'features'), ['mirror']);
    if (differs(['w', 'h', 'scale'])) add((f, t) => ResizeBeat(f, t, part: 'features'), ['w', 'h', 'scale']);
    if (differs(['cx', 'cy'])) add((f, t) => MoveBeat(f, t, part: 'features'), ['cx', 'cy']);
    if (differs(['fill'])) add((f, t) => SwapBeat(f, t, {'fill'}, part: 'features'), ['fill']);
    if (!same(cur, b)) beats.add(SwapBeat(cur, plain(b), {'detail'}));
    return beats;
  }

  static List<Beat> _letters(Map<String, dynamic> a, Map<String, dynamic> b) {
    final sa = a['content'] as String? ?? '', sb = b['content'] as String? ?? '';
    final flagsSame = ['is_clock', 'clock_hour', 'clock_minute', 'mirror_h', 'mirror_v'].every((k) => jsonEncode(a[k]) == jsonEncode(b[k]));
    final ca = sa.split('')..sort();
    final cb = sb.split('')..sort();
    if (flagsSame && a['is_clock'] != true && ca.join() == cb.join()) {
      final used = <int>{};
      final tokens = <(int, int)>[];
      for (int i = 0; i < sa.length; i++) {
        for (int j = 0; j < sb.length; j++) {
          if (!used.contains(j) && sb[j] == sa[i]) {
            used.add(j);
            tokens.add((i, j));
            break;
          }
        }
      }
      return [GlideBeat(a, b, tokens: tokens)];
    }
    return [SwapBeat(a, b, {'content'})];
  }

  // ── Frames ────────────────────────────────────────────────────────────────

  /// The figure [t] (0..1) of the way through [beat]: a real figure map.
  /// Swaps, flips and letter glides change at the half-way point; the
  /// player draws their cross-fade / turn-over / slide around this.
  static Map<String, dynamic> frame(Beat beat, double t) {
    if (t <= 0) return beat.from;
    if (t >= 1) return beat.to;
    final from = beat.from;
    switch (beat) {
      case TurnBeat(:final degrees, :final part):
        switch (kindOf(from)) {
          case FigureKind.classic:
            return {...from, 'rotation': (from['rotation'] as num? ?? 0) + degrees / 90 * t};
          case FigureKind.sandiaLayers:
            final ls = _layerList(from);
            for (int i = 0; i < ls.length; i++) {
              if (part == null || part == 'L$i') ls[i]['rotation'] = ((ls[i]['rotation'] as num?) ?? 0) + degrees / 90 * t;
            }
            return {...from, 'layers': ls};
          case FigureKind.sandiaFeatures:
            if (part == null) return turnCell(from, degrees * t);
            final fa = _featureLists(from), fb = _featureLists(beat.to);
            return _withFeatures(from, [
              for (int i = 0; i < fa.length; i++)
                [
                  for (int j = 0; j < fa[i].length; j++)
                    {
                      ...fa[i][j],
                      'rot': ((fa[i][j]['rot'] as num?) ?? 0) +
                          t * (degrees.isNaN ? _degrees((fa[i][j]['rot'] as num?) ?? 0, (fb[i][j]['rot'] as num?) ?? 0, 1) : (_degrees((fa[i][j]['rot'] as num?) ?? 0, (fb[i][j]['rot'] as num?) ?? 0, 1) == 0 ? 0 : degrees)),
                    },
                ],
            ]);
          case FigureKind.line:
            return MorphLine.turnFrame(beat, t);
          default:
            return t < 0.5 ? from : beat.to;
        }
      case ResizeBeat() || MoveBeat():
        return _lerp(from, beat.to, t) as Map<String, dynamic>;
      case GlideBeat(:final tokens):
        if (kindOf(from) == FigureKind.letters) {
          final targets = List<int>.generate((from['content'] as String).length, (i) => i);
          for (final (i, j) in tokens) {
            targets[i] = j;
          }
          return {...from, 'glide_to': beat.to['content'], 'targets': targets, 't': t};
        }
        return _lerp(from, beat.to, t) as Map<String, dynamic>;
      case FlipBeat():
        return kindOf(from) == FigureKind.line ? MorphLine.flipFrame(beat, t) : (t < 0.5 ? from : beat.to);
      case SwapBeat() || RegroupBeat():
        return t < 0.5 ? from : beat.to;
    }
  }

  static dynamic _lerp(dynamic a, dynamic b, double t) {
    if (a == b) return a;
    if (a is num && b is num) return a + (b - a) * t;
    if (a is Map && b is Map) return {for (final k in a.keys) '$k': b.containsKey(k) ? _lerp(a[k], b[k], t) : a[k]};
    if (a is List && b is List && a.length == b.length) return [for (int i = 0; i < a.length; i++) _lerp(a[i], b[i], t)];
    return t < 0.5 ? a : b;
  }

  /// Exposed for the line-drawing part.
  static dynamic lerp(dynamic a, dynamic b, double t) => _lerp(a, b, t);
}
