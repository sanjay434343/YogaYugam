import 'package:flutter/material.dart';

class ProfilePatternPainter extends CustomPainter {
  final double opacity;

  ProfilePatternPainter({this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    final width = size.width;
    final height = size.height;

    // Draw diagonal lines
    for (double i = 0; i < width + height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(0, i),
        paint,
      );
    }

    // Draw circles
    for (double x = 0; x < width; x += spacing * 2) {
      for (double y = 0; y < height; y += spacing * 2) {
        canvas.drawCircle(
          Offset(x, y),
          3,
          paint..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
