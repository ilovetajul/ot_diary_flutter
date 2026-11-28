import 'package:flutter_test/flutter_test.dart';
import 'package:ot_diary/services/extra_tools.dart';

void main() {
  test('validates daily overtime and numeric Firebase list keys', () {
    expect(ExtraTools.validHours(double.nan), isFalse);
    expect(ExtraTools.validHours(double.infinity), isFalse);
    expect(ExtraTools.validHours(-0.01), isFalse);
    expect(ExtraTools.validHours(25), isFalse);
    expect(ExtraTools.validHours(0), isTrue);
    expect(ExtraTools.validHours(24), isTrue);
    expect(ExtraTools.validHours(3.5), isTrue);
    expect(ExtraTools.decodeDays([null, 3, 5.5, null], '2026_11'), {'1': 3.0, '2': 5.5});
    expect(ExtraTools.decodeDays({'29': 4, '30': 3}, '2024_02'), {'29': 4.0});
  });
  test('rejects foreign or malformed backups before restore', () {
    final good = <String, dynamic>{'format': 'ot-diary-backup-v1', 'uid': 'user1', 'ot': {'2026_11': {'1': 3.5}}};
    expect(ExtraTools.validatedBackup(good, 'user1')['2026_11'], {'1': 3.5});
    expect(() => ExtraTools.validatedBackup(good, 'user2'), throwsFormatException);
    expect(() => ExtraTools.validatedBackup({...good, 'ot': {'2026_02': {'30': 3}}}, 'user1'), throwsFormatException);
    expect(() => ExtraTools.validatedBackup({...good, 'ot': {'2026_11': {'1': -5}}}, 'user1'), throwsFormatException);
  });
  test('CSV covers the entire month and calculates estimated OT', () {
    final csv = ExtraTools.csv(2026, 11, {1: 3.5}, 60);
    expect(csv.startsWith('\uFEFFDate,OT Hours,Estimated OT BDT'), isTrue);
    expect(csv, contains('2026-11-01,3.50,210.00'));
    expect(csv, contains('2026-11-30,0.00,0.00'));
    expect(csv, isNot(contains('2026-11-31')));
  });
}
