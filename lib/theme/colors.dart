import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Light Blue Shades
  static const Color primary = Color(0xFFADD8E6);     // Base Light Sky Blue
  static const Color secondary = Color.fromARGB(255, 0, 160, 218);   // Slightly lighter blue
  static const Color tertiary = Color(0xFF00BBFF);    // Even lighter blue
  static const Color accent = Color.fromARGB(255, 176, 241, 255);      // Very light blue
  static const Color background = Color(0xFFF0F9FC);  // Almost white blue
  static const Color darkBlue = Color(0xFF1E3A8A);    // Dark Blue
  
  // Text colors - Darker shades
  static const Color textDark = Color(0xFF000000);       // Pure black for primary text
  static const Color textMedium = Color(0xFF333333);     // Dark gray for medium emphasis
  static const Color textLight = Color(0xFF444444);      // Medium dark for subtle text
  static const Color textWhite = Colors.white;           // White text (for dark backgrounds)
  
  // Background colors
  static const Color cardBg = Colors.white;
  static const Color shadowColor = Color(0x20ADD8E6); // Light Blue Shadow
  
  // Gradient colors - Blue Gradients
  static List<Color> primaryGradient = [
    primary,
    secondary.withOpacity(0.8),
  ];
  
  // Special gradients
  static List<Color> blueGradient = [
    primary,
    tertiary.withOpacity(0.7),
  ];

  // Backward compatibility
  static const Color oceanBlue = primary;
  static const Color skyBlue = tertiary;
  static const Color lightBlue = background;

  // Opacity variations
  static Color primaryWithShadow = primary.withOpacity(0.1);
  static Color primaryWithOpacity = primary.withOpacity(0.1);
  static Color darkPeriwinkleWithOpacity = primary.withOpacity(0.15);
  
  // Special Effects Colors
  static Color overlayLight = Colors.white.withOpacity(0.8);
  static Color overlayDark = Colors.black.withOpacity(0.05);

  // Legacy mappings
  static const Color darkGreen = primary;
  static const Color mediumDarkGreen = secondary;
  static const Color mediumLightGreen = tertiary;
  static const Color lightGreen = accent;
  static const Color veryLightGreen = background;

  // Text Theme Colors (renamed to avoid conflicts)
  static const Color headingText = Color(0xFF000000);    // For headings
  static const Color bodyText = Color(0xFF222222);       // For body text
  static const Color subtleText = Color(0xFF555555);     // For subtle text
}
