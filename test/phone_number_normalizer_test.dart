import 'package:flutter_test/flutter_test.dart';
import 'package:xanhnow_auth_module/core/validation/phone_number_normalizer.dart';

void main() {
  test('normalizes local Vietnamese mobile phone number to E.164', () {
    expect(
      PhoneNumberNormalizer.normalizeVietnamesePhone('0979982917'),
      '+84979982917',
    );
  });

  test('keeps already normalized Vietnamese phone number', () {
    expect(
      PhoneNumberNormalizer.normalizeVietnamesePhone('+84979982917'),
      '+84979982917',
    );
  });

  test('adds plus sign to 84-prefixed phone number', () {
    expect(
      PhoneNumberNormalizer.normalizeVietnamesePhone('84979982917'),
      '+84979982917',
    );
  });
}
