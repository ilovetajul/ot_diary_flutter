class OtHourGroup {
  final double hours;
  final int days;

  const OtHourGroup({
    required this.hours,
    required this.days,
  });
}

class OtAnalytics {
  /// Groups daily entries by the exact OT duration (rounded to 2 decimals).
  /// Zero/negative values are ignored.
  static List<OtHourGroup> groupByHours(Map<int, double> dailyHours) {
    final counts = <double, int>{};

    for (final value in dailyHours.values) {
      if (value <= 0) continue;
      final normalized = double.parse(value.toStringAsFixed(2));
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }

    final hours = counts.keys.toList()..sort();
    return hours
        .map((value) => OtHourGroup(
              hours: value,
              days: counts[value] ?? 0,
            ))
        .toList();
  }

  static String formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
