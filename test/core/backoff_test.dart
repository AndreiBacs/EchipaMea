import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/network/backoff.dart';

void main() {
  test('doubles from 2s and stays at the 60s cap', () {
    final backoff = Backoff();
    final delays = [for (var i = 0; i < 8; i++) backoff.next().inSeconds];
    expect(delays, [2, 4, 8, 16, 32, 60, 60, 60]);
  });

  test('reset starts over', () {
    final backoff = Backoff()
      ..next()
      ..next()
      ..reset();
    expect(backoff.next(), const Duration(seconds: 2));
  });

  test('many failures never overflow the delay', () {
    final backoff = Backoff();
    for (var i = 0; i < 1000; i++) {
      backoff.next();
    }
    expect(backoff.next(), const Duration(seconds: 60));
  });
}
