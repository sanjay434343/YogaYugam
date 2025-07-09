import 'package:flutter/material.dart';

class CurvedProgressGraph extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool isWeekly;
  final double animationValue;

  const CurvedProgressGraph({
    super.key,
    required this.values,
    required this.color,
    required this.animationValue,
    this.isWeekly = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CurvedProgressPainter(
        values: values,
        color: color,
        animationValue: animationValue,
        isWeekly: isWeekly,
      ),
    );
  }
}

class CurvedProgressPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool isWeekly;
  final double animationValue;

  CurvedProgressPainter({
    required this.values,
    required this.color,
    required this.animationValue,
    this.isWeekly = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final segmentWidth = width / (values.length - 1);

    if (values.isNotEmpty) {
      path.moveTo(0, height - (values[0] * height * animationValue));
      
      for (int i = 1; i < values.length; i++) {
        final x = segmentWidth * i;
        final y = height - (values[i] * height * animationValue);
        
        final controlPoint1X = segmentWidth * (i - 0.5);
        final controlPoint1Y = height - (values[i - 1] * height * animationValue);
        final controlPoint2X = segmentWidth * (i - 0.5);
        final controlPoint2Y = height - (values[i] * height * animationValue);
        
        path.cubicTo(
          controlPoint1X, controlPoint1Y,
          controlPoint2X, controlPoint2Y,
          x, y,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurvedProgressPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.color != color ||
           oldDelegate.values != values;
  }
}
