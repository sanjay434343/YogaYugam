import 'package:flutter/material.dart';

class AnimatedProgressGraph extends StatelessWidget {
  final List<double>? graphData;
  final bool isWeekly;
  final Color color;
  final double progress;

  const AnimatedProgressGraph({
    super.key,
    this.graphData,
    required this.isWeekly,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ProgressGraphPainter(
        graphData: graphData ?? List.generate(isWeekly ? 7 : 30, (index) => 0.0),
        isWeekly: isWeekly,
        color: color,
        progress: progress,
      ),
      size: Size.infinite,
    );
  }
}

class ProgressGraphPainter extends CustomPainter {
  final List<double> graphData;
  final bool isWeekly;
  final Color color;
  final double progress;

  ProgressGraphPainter({
    required this.graphData,
    required this.isWeekly,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = _generatePoints(size);

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final current = points[i - 1];
      final next = points[i];
      final controlPoint1 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        current.dy,
      );
      final controlPoint2 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        next.dy,
      );
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        next.dx, next.dy,
      );
    }

    canvas.drawPath(path, paint);

    // Draw dots
    for (var i = 0; i < points.length; i += isWeekly ? 1 : 5) {
      canvas.drawCircle(points[i], 4, dotPaint);
    }
  }

  List<Offset> _generatePoints(Size size) {
    if (graphData.isEmpty) return [];

    final points = <Offset>[];
    final stepX = size.width / (graphData.length - 1);
    final height = size.height * 0.8;
    final baseY = size.height * 0.9;

    for (int i = 0; i < graphData.length; i++) {
      final x = stepX * i;
      final y = baseY - (graphData[i] * height * progress);
      points.add(Offset(x, y));
    }

    return points;
  }

  @override
  bool shouldRepaint(ProgressGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isWeekly != isWeekly ||
           oldDelegate.color != color ||
           oldDelegate.graphData != graphData;
  }
}
