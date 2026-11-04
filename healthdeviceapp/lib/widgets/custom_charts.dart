import 'dart:math';

import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../theme/app_theme.dart';

/// Clean line chart widget matching reference screens D and D1.
/// Features smooth gradient fill, horizontal reference grid, and custom axis labels.
class HealthLineChart extends StatelessWidget {
  final List<ChartDataPoint> points;
  final double minY;
  final double maxY;
  final List<double> yLabels;
  final Color lineColor;
  final Color gradientColor;
  final double height;

  const HealthLineChart({
    super.key,
    required this.points,
    required this.minY,
    required this.maxY,
    this.yLabels = const [],
    this.lineColor = AppTheme.cyan,
    this.gradientColor = AppTheme.primaryBlue,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Y Axis Labels
          if (yLabels.isNotEmpty)
            SizedBox(
              width: 32,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: yLabels.reversed.map((yVal) {
                  return Text(
                    yVal.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Chart Canvas
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LineChartPainter(
                      points: points,
                      minY: minY,
                      maxY: maxY,
                      yGridCount: yLabels.isNotEmpty ? yLabels.length : 4,
                      lineColor: lineColor,
                      gradientColor: gradientColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // X Axis Labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: points
                      .where((p) => p.label.isNotEmpty)
                      .map(
                        (p) => Text(
                          p.label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final double minY;
  final double maxY;
  final int yGridCount;
  final Color lineColor;
  final Color gradientColor;

  _LineChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.yGridCount,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    // Draw subtle horizontal grid lines
    for (int i = 0; i < yGridCount; i++) {
      final y = size.height * (i / (yGridCount - 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / max(1, points.length - 1);
    final rangeY = max(1.0, maxY - minY);

    final screenPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i].y - minY) / rangeY;
      final y =
          size.height - (normalizedY * size.height).clamp(0.0, size.height);
      screenPoints.add(Offset(x, y));
    }

    path.moveTo(screenPoints[0].dx, screenPoints[0].dy);
    fillPath.moveTo(screenPoints[0].dx, size.height);
    fillPath.lineTo(screenPoints[0].dx, screenPoints[0].dy);

    for (int i = 0; i < screenPoints.length - 1; i++) {
      final p0 = screenPoints[i];
      final p1 = screenPoints[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    fillPath.lineTo(screenPoints.last.dx, size.height);
    fillPath.close();

    // Fill gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gradientColor.withValues(alpha: 0.28),
        gradientColor.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

/// Mini sparkline chart embedded directly inside modular metric cards (Screen B).
class MiniSparkline extends StatelessWidget {
  final List<ChartDataPoint> points;
  final Color lineColor;
  final double height;

  const MiniSparkline({
    super.key,
    required this.points,
    this.lineColor = AppTheme.cyan,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);

    double minY = points.map((p) => p.y).reduce(min);
    double maxY = points.map((p) => p.y).reduce(max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          points: points,
          minY: minY,
          maxY: maxY,
          yGridCount: 0,
          lineColor: lineColor,
          gradientColor: lineColor,
        ),
      ),
    );
  }
}

/// Clean vertical bar chart widget matching reference Screen C1 and A1.
class HealthBarChart extends StatelessWidget {
  final List<ChartDataPoint> bars;
  final Color barColor;
  final double height;
  final double? maxVal;

  const HealthBarChart({
    super.key,
    required this.bars,
    this.barColor = AppTheme.cyan,
    this.height = 140,
    this.maxVal,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return SizedBox(height: height);

    final highest = maxVal ?? max(1.0, bars.map((b) => b.y).reduce(max));

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: bars.map((b) {
                final ratio = (b.y / highest).clamp(0.04, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      height: (height - 24) * ratio,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: b.y > 0 ? 0.9 : 0.2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: bars
                .where((b) => b.label.isNotEmpty)
                .map(
                  (b) => Text(
                    b.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
