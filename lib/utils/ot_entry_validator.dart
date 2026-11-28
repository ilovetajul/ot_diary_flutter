/// Shared validation for OT entry input, import and persistence.
class OtEntryValidator {
  static bool isValidHours(double? hours) =>
      hours != null && hours.isFinite && hours >= 0 && hours <= 24;

  static bool isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100 || month < 1 || month > 12) return false;
    final lastDay = DateTime(year, month + 1, 0).day;
    return day >= 1 && day <= lastDay;
  }

  static void validate(int year, int month, int day, double hours) {
    if (!isValidDate(year, month, day)) throw ArgumentError('Invalid OT date');
    if (!isValidHours(hours)) {
      throw ArgumentError.value(hours, 'hours', 'Must be finite and between 0 and 24');
    }
  }
}
