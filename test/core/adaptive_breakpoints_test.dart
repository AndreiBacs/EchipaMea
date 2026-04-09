import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/ui/adaptive_breakpoints.dart';

void main() {
  group('AdaptiveBreakpoints.sizeClassForWidth', () {
    test('returns compact for widths below 600', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(0),
        AdaptiveSizeClass.compact,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(100),
        AdaptiveSizeClass.compact,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(599.9),
        AdaptiveSizeClass.compact,
      );
    });

    test('returns compact for width exactly at lower bound', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(0),
        AdaptiveSizeClass.compact,
      );
    });

    test('returns medium for width exactly at 600', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(600),
        AdaptiveSizeClass.medium,
      );
    });

    test('returns medium for widths between 600 and 1024', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(600),
        AdaptiveSizeClass.medium,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(800),
        AdaptiveSizeClass.medium,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1023.9),
        AdaptiveSizeClass.medium,
      );
    });

    test('returns expanded for width exactly at 1024', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1024),
        AdaptiveSizeClass.expanded,
      );
    });

    test('returns expanded for widths at or above 1024', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1024),
        AdaptiveSizeClass.expanded,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1280),
        AdaptiveSizeClass.expanded,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1920),
        AdaptiveSizeClass.expanded,
      );
    });

    test('boundary: 599.9 is compact, 600 is medium', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(599.9),
        AdaptiveSizeClass.compact,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(600),
        AdaptiveSizeClass.medium,
      );
    });

    test('boundary: 1023.9 is medium, 1024 is expanded', () {
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1023.9),
        AdaptiveSizeClass.medium,
      );
      expect(
        AdaptiveBreakpoints.sizeClassForWidth(1024),
        AdaptiveSizeClass.expanded,
      );
    });
  });

  group('AdaptiveBreakpoints constants', () {
    test('compactMax is 600', () {
      expect(AdaptiveBreakpoints.compactMax, 600);
    });

    test('mediumMax is 1024', () {
      expect(AdaptiveBreakpoints.mediumMax, 1024);
    });
  });
}
