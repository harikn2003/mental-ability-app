import 'dart:convert';

import 'morph.dart';

/// The line-drawing part of [Morph]: equality, diff and turning frames for
/// `'line_fig'` maps.
class MorphLine {
  MorphLine._();

  static const _sets = ['segs', 'cells', 'tris', 'dots', 'rings', 'arrows', 'hatch', 'arcs', 'glyphs'];

  static String _num(dynamic v) => v is num ? ((v * 1e6).round() / 1e6).toString() : '$v';

  /// A canonical string: element lists compared as sets, segments with
  /// their ends in order.
  static String canon(Map<String, dynamic> f) {
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

  static List<Beat>? diff(Map<String, dynamic> a, Map<String, dynamic> b, int turnSign) => null;

  static Map<String, dynamic> turnFrame(TurnBeat beat, double t) => t < 0.5 ? beat.from : beat.to;
}
