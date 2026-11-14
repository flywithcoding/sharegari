import 'package:flutter_test/flutter_test.dart';
import 'package:sharegari/core/theme/app_motion.dart';

void main() {
  test('AppMotion tokens smoke test', () {
    expect(AppMotion.fast.inMilliseconds, 150);
    expect(AppMotion.normal.inMilliseconds, 250);
    expect(AppMotion.slow.inMilliseconds, 400);
  });
}
