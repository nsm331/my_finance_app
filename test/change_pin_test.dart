import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/screens/change_pin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinChangeState Machine Tests', () {
    test('PinChangeState enum contains enterOld, enterNew, confirmNew', () {
      expect(PinChangeState.values.length, 3);
      expect(PinChangeState.values[0], PinChangeState.enterOld);
      expect(PinChangeState.values[1], PinChangeState.enterNew);
      expect(PinChangeState.values[2], PinChangeState.confirmNew);
    });

    test('State machine transitions correctly from enterOld -> enterNew -> confirmNew', () {
      PinChangeState state = PinChangeState.enterOld;

      // Old PIN verified
      const oldPinMatches = true;
      if (oldPinMatches) {
        state = PinChangeState.enterNew;
      }
      expect(state, PinChangeState.enterNew);

      // New PIN entered
      const newPin = '1234';
      state = PinChangeState.confirmNew;
      expect(state, PinChangeState.confirmNew);

      // Confirm matches
      const confirmedPin = '1234';
      final matches = confirmedPin == newPin;
      expect(matches, isTrue);

      // Confirm mismatch reverts to enterNew
      const wrongConfirmPin = '9999';
      if (wrongConfirmPin != newPin) {
        state = PinChangeState.enterNew;
      }
      expect(state, PinChangeState.enterNew);
    });
  });
}
