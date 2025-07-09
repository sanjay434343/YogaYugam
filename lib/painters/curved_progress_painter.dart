import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'dart:math' show sin;  // Add this import for sin function

class WeeklyGraphPainter extends CustomPainter {
  final bool animate;
  final Color color;
  final double value;
  final double progress; // Add this for animation progress

  WeeklyGraphPainter({
    this.animate = false,
    this.color = AppColors.primary,
    this.value = 0.0,
    this.progress = 1.0, // Default to fully drawn
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create path for the thread
    final path = Path();
    
    // Calculate control points for smooth curve
    final points = List.generate(7, (index) {
      final x = size.width * index / 6;
      final progress = index / 6;
      // Add some natural variation to make it look more organic
      final yVariation = (index % 2 == 0 ? 0.05 : -0.05) * value;
      final y = size.height * (0.8 - (value * 0.6 * progress) + yVariation);
      return Offset(x, y);
    });

    // Start path
    path.moveTo(points[0].dx, points[0].dy);

    // Calculate how many points to draw based on progress
    final pointsToDraw = (points.length * progress).round();
    
    // Create smooth curve through points
    for (int i = 0; i < pointsToDraw - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlPoint1 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        current.dy
      );
      final controlPoint2 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        next.dy
      );
      
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        next.dx, next.dy
      );
    }

    // Only draw the fill if animation is complete
    if (progress == 1.0) {
      final gradientPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.0),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill;

      canvas.drawPath(gradientPath, gradientPaint);
    }

    // Draw thread glow with progress-based opacity
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Draw main thread
    final threadPaint = Paint()
      ..color = color.withOpacity(progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, threadPaint);
  }

  @override
  bool shouldRepaint(covariant WeeklyGraphPainter oldDelegate) {
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
    // Create path for the thread
    final path = Path();
    
    // Calculate control points for smooth curve with more variations
    final points = List.generate(12, (index) {
      final x = size.width * index / 11;
      final progress = index / 11;
      // Create more natural variations
      final yVariation = sin(progress * 3.14) * 0.1 * value;
      final y = size.height * (0.8 - (value * 0.6 * progress) + yVariation);
      return Offset(x, y);
    });

    // Start path
    path.moveTo(points[0].dx, points[0].dy);

    // Calculate how many points to draw based on progress
    final pointsToDraw = (points.length * progress).round();
    
    // Create smooth curve through points
    for (int i = 0; i < pointsToDraw - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlPoint1 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        current.dy
      );
      final controlPoint2 = Offset(
        current.dx + (next.dx - current.dx) / 2,
        next.dy
      );
      
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        next.dx, next.dy
      );
    }

    // Only draw the fill if animation is complete
    if (progress == 1.0) {
      final gradientPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.0),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill;

      canvas.drawPath(gradientPath, gradientPaint);
    }

    // Draw thread glow with progress-based opacity
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Draw main thread
    final threadPaint = Paint()
      ..color = color.withOpacity(progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, threadPaint);
  }

  @override
  bool shouldRepaint(covariant MonthlyGraphPainter oldDelegate) {
    return oldDelegate.value != value ||
           oldDelegate.color != color ||
           oldDelegate.animate != animate ||
           oldDelegate.progress != progress;
  }
}

class CurvedProgressGraphPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<double> graphData;

  CurvedProgressGraphPainter({
    required this.progress,
    required this.color,
    required this.graphData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final stepX = size.width / (graphData.length - 1);
    final maxPoints = graphData.reduce((curr, next) => curr > next ? curr : next);
    
    // Start from bottom left
    path.moveTo(0, size.height);

    Offset? previousPoint;
    for (var i = 0; i < graphData.length; i++) {
      final x = i * stepX;
      // Calculate y position with full height utilization
      final y = size.height - (graphData[i] / maxPoints) * size.height;
      final currentPoint = Offset(x, y);
      
      if (i == 0) {
        path.lineTo(x, y);
      } else if (previousPoint != null) {
        // Control points for smooth curve
        final controlX1 = x - stepX / 2;
        final controlX2 = x - stepX / 2;
        path.cubicTo(
          controlX1, previousPoint.dy,
          controlX2, y,
          x, y,
        );
      }
      previousPoint = currentPoint;
    }

    // Complete the path by going to bottom right and back to start
    path.lineTo(size.width, size.height);
    path.close();

    // Draw the filled area with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.3),
        color.withOpacity(0.1),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    // Clip the path animation based on progress
    final progressPath = Path();
    final pathMetrics = path.computeMetrics().toList();
    
    for (final metric in pathMetrics) {
      progressPath.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }

    canvas.drawPath(progressPath, fillPaint);
    canvas.drawPath(progressPath, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < graphData.length; i++) {
      final x = i * stepX;
      final y = size.height - (graphData[i] / maxPoints) * size.height;
      
      // Outer circle (white background)
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = Colors.white,
      );
      
      // Inner circle (colored dot)
      canvas.drawCircle(
        Offset(x, y),
        3,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CurvedProgressGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.graphData != graphData;
  }
}
