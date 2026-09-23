import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/line_figure.dart';

void main() {
  // An L-ish stroke with a dot, a black triangle and a ring: no symmetry at all.
  final f = LineFig(3, 2,
      segs: {...LineFig.line(0, 0, 0, 2), ...LineFig.line(0, 2, 2, 2), (2, 2, 3, 1)},
      tris: {(1, 0, 0)},
      dots: {(2, 0)},
      rings: {(3, 1)});

  test('four quarter turns and two flips are the identity', () {
    expect(f.rot(4).key, f.key);
    expect(f.rot90().rot90().rot90().rot90().key, f.key);
    expect(f.mirrorX().mirrorX().key, f.key);
    expect(f.mirrorY().mirrorY().key, f.key);
  });

  test('water image = mirror + half turn', () {
    expect(f.mirrorY().key, f.mirrorX().rot(2).key);
  });

  test('a fully asymmetric figure has 8 distinct turns/flips', () {
    expect(f.dihedral().map((g) => g.key).toSet().length, 8);
  });

  test('quarter turn moves the top-right corner to the bottom-right', () {
    final corner = LineFig(2, 2, segs: {(1, 0, 2, 0)}, tris: {(1, 0, 1)});
    final r = corner.rot90();
    expect(r.segs, {(2, 1, 2, 2)});
    expect(r.tris, {(1, 1, 2)}); // TR corner of cell (1,0) -> BR corner of cell (1,1)
  });

  test('mirror of a chiral piece is not any turn of it', () {
    final l = LineFig(2, 3, cells: {(0, 0), (0, 1), (0, 2), (1, 2)});
    expect(l.mirrorX().rotationClassKey, isNot(l.rotationClassKey));
    expect(l.rot(1).rotationClassKey, l.rotationClassKey);
  });

  test('embeds finds shifted copies only, not flipped ones', () {
    final t = LineFig(1, 2, segs: {(0, 0, 0, 1), (0, 1, 1, 2)});
    final host = LineFig(4, 4, segs: {...LineFig.line(0, 0, 4, 0), (2, 1, 2, 2), (2, 2, 3, 3), (1, 1, 1, 2)});
    expect(host.embeds(t), isTrue);
    expect(host.embeds(t.mirrorX()), isFalse);
  });

  test('cellBoundary outlines a region', () {
    expect(LineFig.cellBoundary({(0, 0), (1, 0)}).length, 6);
  });

  test('map round-trip', () {
    expect(LineFig.fromMap(f.toMap()).key, f.key);
  });
}
