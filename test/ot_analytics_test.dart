import 'package:flutter_test/flutter_test.dart';
import 'package:ot_diary/utils/ot_analytics.dart';

void main() {
  group('OtAnalytics.groupByHours', () {
    test('counts how many days each OT duration occurred', () {
      final result = OtAnalytics.groupByHours({
        1: 3,
        2: 5,
        3: 3,
        4: 7,
        5: 5,
        6: 3.5,
      });

      expect(
        result.map((item) => item.hours).toList(),
        [3.0, 3.5, 5.0, 7.0],
      );
      expect(
        result.map((item) => item.days).toList(),
        [2, 1, 2, 1],
      );
    });

    test('ignores empty or non-positive OT values', () {
      final result = OtAnalytics.groupByHours({
        1: 0,
        2: -1,
        3: 4,
      });

      expect(result.length, 1);
      expect(result.first.hours, 4);
      expect(result.first.days, 1);
    });

    test('normalizes values to two decimal places', () {
      final result = OtAnalytics.groupByHours({
        1: 3.001,
        2: 3.004,
        3: 3.5,
      });

      expect(result.first.hours, 3.0);
      expect(result.first.days, 2);
    });
  });
}
