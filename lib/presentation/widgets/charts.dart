import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_tracker/presentation/painters/bar_painter.dart';
import 'package:receipt_tracker/presentation/painters/donut_painter.dart';

const double kHoleRatio = 0.62;

class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    required this.centerLabel,
    required this.centerValue,
    this.donut = true,
    this.selected,
    this.onSelected,
    this.size = 240,
  });

  final List<double> values;
  final List<Color> colors;
  final String centerLabel;
  final String centerValue;
  final bool donut;
  final int? selected;
  final ValueChanged<int?>? onSelected;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final Animation<double> _anim =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(covariant DonutChart old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.values, widget.values) || old.donut != widget.donut) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hole = widget.donut ? kHoleRatio : 0.0;
    final s = Size.square(widget.size);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final i = DonutPainter.getSegmentAt(
              d.localPosition, s, widget.values, hole);
          widget.onSelected?.call(i == widget.selected ? null : i);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: s,
              painter: DonutPainter(
                values: widget.values,
                colors: widget.colors,
                progress: _anim,
                emptyColor: cs.surfaceContainerHighest,
                selected: widget.selected,
                holeRatio: hole,
              ),
            ),
            if (widget.donut)
              Padding(
                padding: EdgeInsets.all(widget.size * 0.24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.centerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.centerValue,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({super.key, required this.values, this.height = 200});
  final List<double> values;
  final double height;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final Animation<double> _anim =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

  @override
  void didUpdateWidget(covariant WeeklyBarChart old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.values, widget.values)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: BarPainter(
          values: widget.values,
          labels: List.generate(widget.values.length, (i) => 'Tuần ${i + 1}'),
          progress: _anim,
          barColor: cs.secondary,
          highlightColor: cs.primary,
          textColor: cs.onSurfaceVariant,
          gridColor: cs.outlineVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}
