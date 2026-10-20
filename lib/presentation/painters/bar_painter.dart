import 'dart:math';

import 'package:flutter/material.dart';
import 'package:receipt_tracker/core/formatters.dart';

class BarPainter extends CustomPainter {
  BarPainter({
    required this.values,
    required this.labels,
    required this.progress,
    required this.barColor,
    required this.highlightColor,
    required this.textColor,
    required this.gridColor,
  }) : super(repaint: progress);

  final List<double> values;
  final List<String> labels;
  final Animation<double> progress;
  final Color barColor;
  final Color highlightColor;
  final Color textColor;
  final Color gridColor;

  void _text(Canvas c, String s, Offset o, {double size = 11, bool center = false, bool right = false, FontWeight w = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: textColor, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (center) dx -= tp.width / 2;
    if (right) dx -= tp.width;
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 40.0;
    const top = 22.0;
    final bottom = size.height - 24;
    final h = bottom - top;
    var maxV = values.fold<double>(0, max);
    if (maxV <= 0) maxV = 1;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = bottom - h * i / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      _text(canvas, fmtCompact(maxV * i / 3), Offset(leftPad - 6, y), right: true, size: 10);
    }

    final n = values.length;
    final slot = (size.width - leftPad) / n;
    final bw = slot * 0.5;
    final maxIdx = values.indexOf(values.fold<double>(0, max));
    for (var i = 0; i < n; i++) {
      final x = leftPad + slot * i + (slot - bw) / 2;
      final bh = values[i] / maxV * h * progress.value;
      final rect = Rect.fromLTWH(x, bottom - bh, bw, bh);
      final paint = Paint()..color = (i == maxIdx && values[i] > 0) ? highlightColor : barColor;
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(8), topRight: const Radius.circular(8)),
        paint,
      );
      if (progress.value > 0.8 && values[i] > 0) {
        _text(canvas, fmtCompact(values[i]), Offset(x + bw / 2, bottom - bh - 9), center: true, size: 10, w: FontWeight.w700);
      }
      _text(canvas, labels[i], Offset(x + bw / 2, bottom + 12), center: true);
    }
  }

  @override
  bool shouldRepaint(covariant BarPainter old) =>
      old.values != values || old.barColor != barColor || old.textColor != textColor;
}
