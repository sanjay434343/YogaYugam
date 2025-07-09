import 'package:flutter/material.dart';

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double defaultSize;
  static late double scale;
  static late Orientation orientation;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
    
    // Base size for a typical 5.5-inch device (iPhone 8 Plus)
    defaultSize = orientation == Orientation.landscape 
        ? screenHeight * 0.024
        : screenWidth * 0.024;

    // Calculate scale factor based on design width (assuming 375 is base width)
    scale = screenWidth / 375;
  }

  static double getProportionateScreenHeight(double inputHeight) {
    return inputHeight * screenHeight / 812; // 812 is layout height for iPhone 12
  }

  static double getProportionateScreenWidth(double inputWidth) {
    return inputWidth * screenWidth / 375; // 375 is layout width for iPhone 12
  }

  // Helper method for responsive font sizes
  static double fontSize(double size) {
    return size * scale;
  }

  // Helper for responsive padding
  static EdgeInsets padding(double horizontal, double vertical) {
    return EdgeInsets.symmetric(
      horizontal: getProportionateScreenWidth(horizontal),
      vertical: getProportionateScreenHeight(vertical),
    );
  }

  // Helper for responsive margins
  static EdgeInsets margin(double horizontal, double vertical) {
    return EdgeInsets.symmetric(
      horizontal: getProportionateScreenWidth(horizontal),
      vertical: getProportionateScreenHeight(vertical),
    );
  }

  // Helper for responsive radius
  static double radius(double r) {
    return r * scale;
  }
}
