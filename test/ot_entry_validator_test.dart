import 'package:flutter_test/flutter_test.dart';
import 'package:ot_diary/utils/ot_entry_validator.dart';

void main() {
  group('OT hour validation', () {
    test('accepts 0, 24 and decimal hours', () {
      expect(OtEntryValidator.isValidHours(0), isTrue);
      expect(OtEntryValidator.isValidHours(24), isTrue);
      expect(OtEntryValidator.isValidHours(3.5), isTrue);
      expect(OtEntryValidator.isValidHours(7.25), isTrue);
    });
    test('rejects negative, over-limit and non-finite values', () {
      expect(OtEntryValidator.isValidHours(-0.01), isFalse);
      expect(OtEntryValidator.isValidHours(24.01), isFalse);
      expect(OtEntryValidator.isValidHours(double.nan), isFalse);
      expect(OtEntryValidator.isValidHours(double.infinity), isFalse);
      expect(OtEntryValidator.isValidHours(null), isFalse);
    });
  });
  group('OT date validation', () {
    test('accepts valid dates including leap day', () {
      expect(OtEntryValidator.isValidDate(2024, 2, 29), isTrue);
      expect(OtEntryValidator.isValidDate(2026, 11, 30), isTrue);
    });
    test('rejects invalid calendar dates', () {
      expect(OtEntryValidator.isValidDate(2026, 2, 29), isFalse);
      expect(OtEntryValidator.isValidDate(2024, 2, 30), isFalse);
      expect(OtEntryValidator.isValidDate(2026, 13, 1), isFalse);
    });
    test('throws for invalid records', () {
      expect(() => OtEntryValidator.validate(2026, 11, 31, 4), throwsArgumentError);
      expect(() => OtEntryValidator.validate(2026, 11, 1, 25), throwsArgumentError);
    });
  });
}
