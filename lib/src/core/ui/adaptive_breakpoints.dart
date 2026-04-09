import 'package:flutter/widgets.dart';

enum AdaptiveSizeClass { compact, medium, expanded }

class AdaptiveBreakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 1024;

  static AdaptiveSizeClass sizeClassForWidth(double width) {
    if (width < compactMax) return AdaptiveSizeClass.compact;
    if (width < mediumMax) return AdaptiveSizeClass.medium;
    return AdaptiveSizeClass.expanded;
  }

  static AdaptiveSizeClass fromContext(BuildContext context) {
    return sizeClassForWidth(MediaQuery.sizeOf(context).width);
  }
}
