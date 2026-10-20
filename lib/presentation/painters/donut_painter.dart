import 'dart:math';

import 'package:flutter/material.dart';

/// Pie / Donut tự vẽ. [holeRatio] = 0 -> Pie đặc.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.emptyColor,
    this.selected,
    this.holeRatio = 0.62,
  }) : super(repaint: progress);

  final List<double> values;
  final List<Color> colors;
  final Animation<double> progress;
  final Color emptyColor;
  final int? selected;
  final double holeRatio;

  static double outerRadius(Size size) => min(size.width, size.height) / 2 - 8;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = size.center(Offset.zero);
    final outer = outerRadius(size);

    if (total <= 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer * (1 - holeRatio)
        ..color = emptyColor;
      canvas.drawCircle(
        center,
        outer - outer * (1 - holeRatio) / 2,
        ring,
      );
      return;
    }

    var start = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;

      final sweep = values[i] / total * 2 * pi * progress.value;
      final isSel = selected == i;
      final r = isSel ? outer + 4 : outer;
      final paint = Paint()
        ..isAntiAlias = true
        ..color = colors[i % colors.length];

      if (holeRatio > 0) {
        final stroke = r * (1 - holeRatio);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;

        final gap = (values.length > 1 && sweep > 0.05) ? 0.025 : 0.0;

        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: r - stroke / 2,
          ),
          start + gap / 2,
          max(sweep - gap, 0.0001),
          false,
          paint,
        );
      } else {
        paint.style = PaintingStyle.fill;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          start,
          sweep,
          true,
          paint,
        );

        if (values.length > 1) {
          final sep = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = emptyColor.withOpacity(0.6);

          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r),
            start,
            sweep,
            true,
            sep,
          );
        }
      }

      start += sweep;
    }
  }

  /// Trả về index lát cắt tại điểm chạm, hoặc null.
  /// Dùng tên getSegmentAt để tránh xung đột với CustomPainter.hitTest.
  static int? getSegmentAt(
    Offset p,
    Size size,
    List<double> values,
    double holeRatio,
  ) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;

    final d = p - size.center(Offset.zero);
    final outer = outerRadius(size) + 4;
    final dist = d.distance;

    if (dist > outer || dist < outer * holeRatio) return null;

    var ang = atan2(d.dy, d.dx) + pi / 2;
    // 0 ở đỉnh, chiều kim đồng hồ
    if (ang < 0) ang += 2 * pi;

    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      acc += values[i] / total * 2 * pi;
      if (ang <= acc && values[i] > 0) return i;
    }

    return null;
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.selected != selected ||
      old.holeRatio != holeRatio ||
      old.emptyColor != emptyColor;
}
