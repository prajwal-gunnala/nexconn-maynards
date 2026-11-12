import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/format.dart';

void main() {
  group('Fmt.rupees', () {
    test('uses Indian grouping', () {
      expect(Fmt.rupees(0), '₹0');
      expect(Fmt.rupees(1320), '₹1,320');
      expect(Fmt.rupees(125000), '₹1,25,000');
      expect(Fmt.rupees(12345678), '₹1,23,45,678');
    });
    test('rounds and handles negatives', () {
      expect(Fmt.rupees(99.6), '₹100');
      expect(Fmt.rupees(-420), '-₹420');
    });
  });

  test('savePercent', () {
    expect(Fmt.savePercent(price: 88, retail: 120), 27);
    expect(Fmt.savePercent(price: 120, retail: 120), isNull);
    expect(Fmt.savePercent(price: 10, retail: 0), isNull);
  });

  test('timeLeft', () {
    final now = DateTime(2026, 11, 16, 6);
    expect(Fmt.timeLeft(now.add(const Duration(hours: 2, minutes: 15)), now: now), '2h 15m left');
    expect(Fmt.timeLeft(now.add(const Duration(minutes: 12)), now: now), '12m left');
    expect(Fmt.timeLeft(now.add(const Duration(days: 1, hours: 3)), now: now), '1d 3h left');
    expect(Fmt.timeLeft(now.subtract(const Duration(minutes: 1)), now: now), 'Closed');
  });

  test('time is lower-case 12h', () {
    expect(Fmt.time(DateTime(2026, 11, 16, 8, 30)), '8:30 am');
  });
}
