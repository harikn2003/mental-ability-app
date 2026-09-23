import 'dart:math';
import 'dart:ui';

/// Geometry of the geo_completion ("which piece completes this shape")
/// pieces, shared by the question-screen painter and the answer-option
/// painter so the two can never disagree. Each (shape, cut) splits a square
/// (0), triangle (1) or circle (2) into piece 0 and piece 1, which together
/// must exactly cover the whole shape - see test/geo_piece_path_test.dart.
class GeoPiecePath {
  GeoPiecePath._();

  /// The outline of [piece] (0 or 1) for [shape] / [cut], drawn inside [rect].
  static Path of(int shape, int cut, int piece, Rect rect) {
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    final cx = (l + r) / 2, cy = (t + b) / 2;
    switch (shape) {
      case 0:
        return _square(l, t, r, b, cx, cy, cut, piece);
      case 1:
        return _triangle(l, t, r, b, cx, cy, cut, piece);
      default:
        return _circle(cx, cy, (r - l) / 2, cut, piece);
    }
  }

  static Path _square(
    double l,
    double t,
    double r,
    double b,
    double cx,
    double cy,
    int cut,
    int piece,
  ) {
    switch (cut) {
      case 0:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(cx, t)
                ..lineTo(cx, b)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(cx, t)
                ..lineTo(r, t)
                ..lineTo(r, b)
                ..lineTo(cx, b)
                ..close());
      case 1:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(r, cy)
                ..lineTo(l, cy)
                ..close())
            : (Path()
                ..moveTo(l, cy)
                ..lineTo(r, cy)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 2:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(r, b)
                ..close())
            : (Path()
                ..moveTo(l, t)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 3:
        return piece == 0
            ? (Path()
                ..moveTo(l, t)
                ..lineTo(r, t)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(r, t)
                ..lineTo(r, b)
                ..lineTo(l, b)
                ..close());
      case 4:
        {
          final sx = l + (r - l) * 0.6;
          final sy = t + (b - t) * 0.4;
          return piece == 0
              ? (Path()
                  ..moveTo(l, t)
                  ..lineTo(sx, t)
                  ..lineTo(sx, sy)
                  ..lineTo(r, sy)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(sx, t)
                  ..lineTo(r, t)
                  ..lineTo(r, sy)
                  ..lineTo(sx, sy)
                  ..close());
        }
      case 5:
        {
          final sx = l + (r - l) * 0.6;
          final sy = t + (b - t) * 0.6;
          return piece == 0
              ? (Path()
                  ..moveTo(l, t)
                  ..lineTo(r, t)
                  ..lineTo(r, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(sx, sy)
                  ..lineTo(r, sy)
                  ..lineTo(r, b)
                  ..lineTo(sx, b)
                  ..close());
        }
      case 6:
        {
          final sx = l + (r - l) * 0.4;
          final sy = t + (b - t) * 0.6;
          // BUGFIX: piece 0 used to be the square minus a 0.4 x 0.6 block at
          // the TOP-left while piece 1 was a 0.4 x 0.4 block at the BOTTOM-left
          // - the "answer" didn't complete the shown shape at all, and the
          // true complement (a tall rectangle) could appear as a "wrong"
          // option (tracker: "Geo completion picks the wrong answer").
          // Piece 0 is now the square minus exactly piece 1.
          return piece == 0
              ? (Path()
                  ..moveTo(l, t)
                  ..lineTo(r, t)
                  ..lineTo(r, b)
                  ..lineTo(sx, b)
                  ..lineTo(sx, sy)
                  ..lineTo(l, sy)
                  ..close())
              : (Path()
                  ..moveTo(l, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, b)
                  ..lineTo(l, b)
                  ..close());
        }
      default:
        {
          final sx = l + (r - l) * 0.4;
          final sy = t + (b - t) * 0.4;
          return piece == 0
              ? (Path()
                  ..moveTo(l, sy)
                  ..lineTo(sx, sy)
                  ..lineTo(sx, t)
                  ..lineTo(r, t)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close())
              : (Path()
                  ..moveTo(l, t)
                  ..lineTo(sx, t)
                  ..lineTo(sx, sy)
                  ..lineTo(l, sy)
                  ..close());
        }
    }
  }

  static Path _triangle(
    double l,
    double t,
    double r,
    double b,
    double cx,
    double cy,
    int cut,
    int piece,
  ) {
    switch (cut) {
      case 0:
        {
          final my = t + (b - t) * 0.5;
          final mll = l + (my - t) / (b - t) * (cx - l);
          final mlr = cx + (my - t) / (b - t) * (r - cx);
          return piece == 0
              ? (Path()
                  ..moveTo(cx, t)
                  ..lineTo(mlr, my)
                  ..lineTo(mll, my)
                  ..close())
              : (Path()
                  ..moveTo(mll, my)
                  ..lineTo(mlr, my)
                  ..lineTo(r, b)
                  ..lineTo(l, b)
                  ..close());
        }
      case 1:
        return piece == 0
            ? (Path()
                ..moveTo(cx, t)
                ..lineTo(cx, b)
                ..lineTo(l, b)
                ..close())
            : (Path()
                ..moveTo(cx, t)
                ..lineTo(r, b)
                ..lineTo(cx, b)
                ..close());
      case 2:
        {
          final mx = (cx + r) / 2;
          final my = (t + b) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(l, b)
                  ..lineTo(cx, t)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(l, b)
                  ..lineTo(mx, my)
                  ..lineTo(r, b)
                  ..close());
        }
      default:
        {
          final mx = (cx + l) / 2;
          final my = (t + b) / 2;
          return piece == 0
              ? (Path()
                  ..moveTo(r, b)
                  ..lineTo(cx, t)
                  ..lineTo(mx, my)
                  ..close())
              : (Path()
                  ..moveTo(r, b)
                  ..lineTo(mx, my)
                  ..lineTo(l, b)
                  ..close());
        }
    }
  }

  static Path _circle(double cx, double cy, double r, int cut, int piece) {
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final p = Path();
    switch (cut) {
      case 0:
        p.moveTo(cx, cy - r);
        p.arcTo(rect, -pi / 2, piece == 0 ? -pi : pi, false);
        p.close();
        return p;
      case 1:
        p.moveTo(cx - r, cy);
        p.arcTo(rect, pi, piece == 0 ? -pi : pi, false);
        p.close();
        return p;
      case 2:
        p.moveTo(cx, cy);
        if (piece == 0) {
          p.arcTo(rect, 0, 3 * pi / 2, false);
        } else {
          p.arcTo(rect, -pi / 2, pi / 2, false);
        }
        p.close();
        return p;
      default:
        p.moveTo(cx, cy);
        if (piece == 0) {
          p.arcTo(rect, pi / 2, 3 * pi / 2, false);
        } else {
          p.arcTo(rect, 0, pi / 2, false);
        }
        p.close();
        return p;
    }
  }
}
