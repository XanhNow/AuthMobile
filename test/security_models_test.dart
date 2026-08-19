import 'package:flutter_test/flutter_test.dart';
import 'package:xanhnow_auth_module/features/auth/data/models/security_models.dart';

void main() {
  test('RegisterResponse parses mandatory passkey registration status', () {
    final response = RegisterResponse.fromJson({
      'userId': '6cc3fd06-bf1d-48cd-81ae-3c87f9e4acd7',
      'status': 'Active',
      'registrationStatus': 'PendingPasskey',
      'registeredAtUtc': '2026-08-07T08:11:44.2342757+00:00',
    });

    expect(response.registrationStatus, 'PendingPasskey');
    expect(response.status, 'Active');
  });

  test('PasswordLoginResponse treats PasskeyRequired as not authenticated', () {
    final response = PasswordLoginResponse.fromJson({
      'state': 'PasskeyRequired',
      'userId': '6cc3fd06-bf1d-48cd-81ae-3c87f9e4acd7',
      'tokens': null,
      'reasonCode': 'registration_passkey_required',
    });

    expect(response.isPasskeyRequired, isTrue);
    expect(response.isCompleted, isFalse);
    expect(response.tokens, isNull);
  });

  test('TokenPair preserves optional session id', () {
    final response = TokenPair.fromJson({
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'accessTokenExpiresAtUtc': '2026-08-14T05:20:00Z',
      'refreshTokenExpiresAtUtc': '2026-08-21T05:20:00Z',
      'sessionId': 'session-1',
      'tokenType': 'Bearer',
    });

    expect(response.sessionId, 'session-1');
    expect(response.tokenType, 'Bearer');
  });
}
