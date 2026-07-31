import 'package:capstone_app/services/offline_step_reconciliation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline step baseline is scoped to the signed-in user', () {
    expect(
      offlineStepBaselineKey(' user-id '),
      'offline_steps.baseline.user-id',
    );
  });

  test('missing baseline does not grant offline steps', () {
    expect(calculateOfflineStepDelta(baseline: null, current: 1200), 0);
  });

  test('step counter difference becomes offline steps', () {
    expect(calculateOfflineStepDelta(baseline: 1200, current: 1350), 150);
  });

  test('rebooted step counter does not grant invalid steps', () {
    expect(calculateOfflineStepDelta(baseline: 1200, current: 50), 0);
  });
}
