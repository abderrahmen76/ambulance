import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
/// Provides breakpoints, padding, spacing, and layout helpers
class Responsive {
  final BuildContext context;

  Responsive(this.context);

  /// Screen width
  double get screenWidth => MediaQuery.of(context).size.width;

  /// Screen height
  double get screenHeight => MediaQuery.of(context).size.height;

  /// Device orientation
  Orientation get orientation => MediaQuery.of(context).orientation;

  /// Is landscape orientation
  bool get isLandscape => orientation == Orientation.landscape;

  /// Is portrait orientation
  bool get isPortrait => orientation == Orientation.portrait;

  /// Get device type based on screen width
  DeviceType get deviceType {
    if (screenWidth < 600) {
      return DeviceType.phone;
    } else if (screenWidth < 1000) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// Is small phone (< 380px)
  bool get isSmallPhone => screenWidth < 380;

  /// Is phone (< 600px)
  bool get isPhone => screenWidth < 600;

  /// Is tablet (600px - 1000px)
  bool get isTablet => screenWidth >= 600 && screenWidth < 1000;

  /// Is desktop (>= 1000px)
  bool get isDesktop => screenWidth >= 1000;

  /// Responsive padding helper - scales based on screen size
  double getPadding(double baseValue) {
    if (isSmallPhone) return baseValue * 0.75;
    if (isPhone) return baseValue * 0.9;
    if (isTablet) return baseValue * 1.2;
    return baseValue * 1.5;
  }

  /// Responsive margin helper
  double getMargin(double baseValue) => getPadding(baseValue);

  /// Responsive spacing helper
  double getSpacing(double baseValue) => getPadding(baseValue);

  /// Standard padding values
  EdgeInsets get paddingXSmall => EdgeInsets.all(getPadding(4));
  EdgeInsets get paddingSmall => EdgeInsets.all(getPadding(8));
  EdgeInsets get paddingMedium => EdgeInsets.all(getPadding(12));
  EdgeInsets get paddingLarge => EdgeInsets.all(getPadding(16));
  EdgeInsets get paddingXLarge => EdgeInsets.all(getPadding(20));
  EdgeInsets get paddingXXLarge => EdgeInsets.all(getPadding(24));

  /// Horizontal padding
  EdgeInsets get paddingHorizontalSmall =>
      EdgeInsets.symmetric(horizontal: getPadding(8));
  EdgeInsets get paddingHorizontalMedium =>
      EdgeInsets.symmetric(horizontal: getPadding(12));
  EdgeInsets get paddingHorizontalLarge =>
      EdgeInsets.symmetric(horizontal: getPadding(16));

  /// Vertical padding
  EdgeInsets get paddingVerticalSmall =>
      EdgeInsets.symmetric(vertical: getPadding(8));
  EdgeInsets get paddingVerticalMedium =>
      EdgeInsets.symmetric(vertical: getPadding(12));
  EdgeInsets get paddingVerticalLarge =>
      EdgeInsets.symmetric(vertical: getPadding(16));

  /// Scalar padding values (for use in EdgeInsets.symmetric, etc.)
  double get paddingValueXSmall => getPadding(4);
  double get paddingValueSmall => getPadding(8);
  double get paddingValueMedium => getPadding(12);
  double get paddingValueLarge => getPadding(16);
  double get paddingValueXLarge => getPadding(20);
  double get paddingValueXXLarge => getPadding(24);

  /// Responsive spacing values
  double get spacingXSmall => getPadding(4);
  double get spacingSmall => getPadding(8);
  double get spacingMedium => getPadding(12);
  double get spacingLarge => getPadding(16);
  double get spacingXLarge => getPadding(20);
  double get spacingXXLarge => getPadding(24);

  /// Responsive font size helper
  double getFontSize(double baseSize) {
    if (isSmallPhone) return baseSize * 0.85;
    if (isPhone) return baseSize * 0.95;
    if (isTablet) return baseSize * 1.15;
    return baseSize * 1.3;
  }

  /// Standard font sizes
  double get fontSizeSmall => getFontSize(12);
  double get fontSizeMedium => getFontSize(14);
  double get fontSizeLarge => getFontSize(16);
  double get fontSizeXLarge => getFontSize(18);
  double get fontSizeTitle => getFontSize(20);
  double get fontSizeHeading => getFontSize(24);

  /// Responsive width - returns percentage of screen width
  /// Example: width(80) returns 80% of screen width
  double width(double percentage) => screenWidth * (percentage / 100);

  /// Responsive height - returns percentage of screen height
  double height(double percentage) => screenHeight * (percentage / 100);

  /// Get grid column count for responsive grid
  int get gridColumns {
    if (isPhone) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Get grid column count for 2-column layouts
  int get gridColumns2 {
    if (isPhone) return 1;
    return 2;
  }

  /// Get grid column count for 3-column layouts
  int get gridColumns3 {
    if (isPhone) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Get grid column count for 4-column layouts
  int get gridColumns4 {
    if (isPhone) return 2;
    if (isTablet) return 3;
    return 4;
  }

  /// Responsive aspect ratio for cards
  double get cardAspectRatio {
    if (isSmallPhone) return 0.8;
    if (isPhone) return 1.0;
    if (isTablet) return 1.2;
    return 1.4;
  }

  /// Responsive border radius
  double getBorderRadius(double baseValue) {
    if (isSmallPhone) return baseValue * 0.75;
    if (isPhone) return baseValue * 0.9;
    if (isTablet) return baseValue * 1.1;
    return baseValue * 1.3;
  }

  /// Standard border radius values
  BorderRadius get radiusSmall => BorderRadius.circular(getBorderRadius(4));
  BorderRadius get radiusMedium => BorderRadius.circular(getBorderRadius(8));
  BorderRadius get radiusLarge => BorderRadius.circular(getBorderRadius(12));
  BorderRadius get radiusXLarge => BorderRadius.circular(getBorderRadius(16));

  /// Maximum width for content (prevents overly wide layouts)
  double get maxContentWidth {
    if (isPhone) return screenWidth;
    if (isTablet) return screenWidth * 0.9;
    return 1200;
  }

  /// Get safe padding (accounts for system UI)
  EdgeInsets get safePadding => EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + getPadding(8),
        bottom: MediaQuery.of(context).padding.bottom + getPadding(8),
        left: getPadding(8),
        right: getPadding(8),
      );

  /// Responsive icon size
  double getIconSize(double baseSize) {
    if (isSmallPhone) return baseSize * 0.8;
    if (isPhone) return baseSize * 0.9;
    if (isTablet) return baseSize * 1.2;
    return baseSize * 1.4;
  }

  /// Standard icon sizes
  double get iconSizeSmall => getIconSize(16);
  double get iconSizeMedium => getIconSize(24);
  double get iconSizeLarge => getIconSize(32);
  double get iconSizeXLarge => getIconSize(48);
}

/// Device type enumeration
enum DeviceType { phone, tablet, desktop }

/// Extension on BuildContext for easy access to Responsive
extension ResponsiveExtension on BuildContext {
  Responsive get responsive => Responsive(this);
}

/// Responsive widget helper
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Responsive responsive) phone;
  final Widget Function(BuildContext context, Responsive responsive)? tablet;
  final Widget Function(BuildContext context, Responsive responsive)? desktop;

  const ResponsiveBuilder({
    Key? key,
    required this.phone,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);

    if (responsive.isDesktop && desktop != null) {
      return desktop!(context, responsive);
    } else if (responsive.isTablet && tablet != null) {
      return tablet!(context, responsive);
    } else {
      return phone(context, responsive);
    }
  }
}
