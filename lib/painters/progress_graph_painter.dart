import 'package:flutter/material.dart';

class ProgressGraphPainter extends CustomPainter {
  final bool isWeekly;
  final double progress;
  final Color color;
  final List<double> points;  // Changed from 'data' to 'points'

  ProgressGraphPainter({
    required this.isWeekly,
    required this.progress,
    required this.color,
    required this.points,  // Changed from 'data' to 'points'
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final points = _generatePoints(size);
    
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    // Create smooth line between points
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      
      final controlPoint1 = Offset(
        p0.dx + (p1.dx - p0.dx) / 2,
        p0.dy,
      );
      final controlPoint2 = Offset(
        p0.dx + (p1.dx - p0.dx) / 2,
        p1.dy,
      );
      
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
    }

    // Create and draw fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw dots
    for (var point in points) {
      canvas.drawCircle(point, 4 * progress, dotPaint);
    }
  }

  List<Offset> _generatePoints(Size size) {
    if (points.isEmpty) return [];  // Changed from 'data' to 'points'

    final pointsList = <Offset>[];
    final stepX = size.width / (points.length - 1);  // Changed from 'data' to 'points'
    final height = size.height * 0.8; // Use 80% of height for better visibility
    final baseY = size.height * 0.9; // Base line position

    for (int i = 0; i < points.length; i++) {  // Changed from 'data' to 'points'
      final x = stepX * i;
      // If completed (1.0), point goes up, if not completed (0.0), stays down
      final y = baseY - (points[i] * height * progress);  // Changed from 'data' to 'points'
      pointsList.add(Offset(x, y));
    }

    return pointsList;
  }

  @override
  bool shouldRepaint(ProgressGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isWeekly != isWeekly ||
           oldDelegate.color != color ||
           oldDelegate.points != points;  // Changed from 'data' to 'points'
  }
}
