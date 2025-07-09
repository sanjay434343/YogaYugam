import 'package:flutter/material.dart';
import '../theme/colors.dart';

class WeeklyGraphPainter extends CustomPainter {
  final bool animate;
  final Color color;
  final double value;
  final double progress;

  WeeklyGraphPainter({
    this.animate = false,
    this.color = AppColors.primary,
    this.value = 0.0,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Create points for the graph
    final points = List.generate(7, (i) {
      final x = (width * i) / 6;
      final normalizedValue = (i / 6) * value;
      final y = height - (height * normalizedValue * progress);
      return Offset(x, y);
    });

    // Draw the path through points
    path.moveTo(points[0].dx, points[0].dy);
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

    // Draw path
    canvas.drawPath(path, paint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(WeeklyGraphPainter oldDelegate) {
    return oldDelegate.value != value ||
           oldDelegate.color != color ||
           oldDelegate.animate != animate ||
           oldDelegate.progress != progress;
  }
}

class MonthlyGraphPainter extends CustomPainter {
  final bool animate;
  final Color color;
  final double value;
  final double progress;

  MonthlyGraphPainter({
    this.animate = false,
    this.color = AppColors.primary,
    this.value = 0.0,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Create points for the graph with more variations
    final points = List.generate(30, (i) {
      final x = (width * i) / 29;
      final normalizedValue = (i / 29) * value;
      // Add some natural variation
      final variation = (i % 2 == 0 ? 0.05 : -0.05) * value;
      final y = height - (height * (normalizedValue + variation) * progress);
      return Offset(x, y);
    });

    // Draw the path through points
    path.moveTo(points[0].dx, points[0].dy);
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

    // Draw path
    canvas.drawPath(path, paint);

    // Draw dots at key points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < points.length; i += 5) {
      canvas.drawCircle(points[i], 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(MonthlyGraphPainter oldDelegate) {
    return oldDelegate.value != value ||
           oldDelegate.color != color ||
           oldDelegate.animate != animate ||
           oldDelegate.progress != progress;
  }
}
