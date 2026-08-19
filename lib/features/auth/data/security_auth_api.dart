import '../../../core/network/api_client.dart' hide JsonMap;
import 'models/security_models.dart';

class SecurityAuthApi {
  const SecurityAuthApi(this._client);

  final ApiClient _client;

  Future<T> withTemporaryAccessToken<T>(
    String accessToken,
    Future<T> Function() action,
  ) {
    return _client.withTemporaryAccessToken(accessToken, action);
  }

  Future<RegisterResponse> register({
    required String phoneNumber,
    required String password,
    required String displayName,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/register',
      {
        'phoneNumber': phoneNumber,
        'password': password,
        'displayName': displayName,
        'deviceContext': deviceContext.toJson(),
      },
      RegisterResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<PasswordLoginResponse> loginWithPassword({
    required String phoneNumber,
    required String password,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/password',
      {
        'phoneNumber': phoneNumber,
        'password': password,
        'deviceContext': deviceContext.toJson(),
      },
      PasswordLoginResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<BeginRegistrationPasskeyResponse> beginRegistrationPasskey({
    required String userId,
    required String displayName,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/register/passkey/begin',
      {
        'userId': userId,
        'displayName': displayName,
        'deviceContext': deviceContext.toJson(),
      },
      BeginRegistrationPasskeyResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<FinishRegistrationPasskeyResponse> finishRegistrationPasskey({
    required String userId,
    required String ceremonyId,
    required JsonMap credential,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/register/passkey/finish',
      {
        'userId': userId,
        'ceremonyId': ceremonyId,
        'credential': credential,
        'deviceContext': deviceContext.toJson(),
      },
      FinishRegistrationPasskeyResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<PasskeyLoginBeginResponse> beginPasskeyLogin({
    String? loginIdentifier,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/passkey/begin',
      {
        if (loginIdentifier != null && loginIdentifier.isNotEmpty)
          'loginIdentifier': loginIdentifier,
        'deviceContext': deviceContext.toJson(),
      },
      PasskeyLoginBeginResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<PasskeyLoginFinishResponse> finishPasskeyLogin({
    required String ceremonyId,
    required JsonMap credential,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/passkey/finish',
      {
        'ceremonyId': ceremonyId,
        'credential': credential,
        'deviceContext': deviceContext.toJson(),
      },
      PasskeyLoginFinishResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<SecurityProfile> securityProfile() async {
    final response = await _client.get(
      '/api/v1/accounts/me/security-profile',
      SecurityProfile.fromJson,
    );
    return response.data;
  }

  Future<BeginSmartOtpEnrollmentResponse> beginSmartOtpEnrollment({
    required String deviceName,
    required String platform,
    required String appInstanceIdHash,
    required String keyAlgorithm,
    required String candidatePublicKeySpki,
    required String candidatePublicKeyThumbprint,
  }) async {
    final response = await _client
        .post('/api/v1/smart-otp/devices/enroll/begin', {
          'deviceName': deviceName,
          'platform': platform,
          'appInstanceIdHash': appInstanceIdHash,
          'keyAlgorithm': keyAlgorithm,
          'candidatePublicKeySpki': candidatePublicKeySpki,
          'candidatePublicKeyThumbprint': candidatePublicKeyThumbprint,
        }, BeginSmartOtpEnrollmentResponse.fromJson);
    return response.data;
  }

  Future<SmartOtpDeviceStateResponse> confirmSmartOtpEnrollment({
    required String enrollmentId,
    required String clientNonce,
    required String deviceSignature,
  }) async {
    final response = await _client
        .post('/api/v1/smart-otp/devices/enroll/confirm', {
          'enrollmentId': enrollmentId,
          'clientNonce': clientNonce,
          'deviceSignature': deviceSignature,
        }, SmartOtpDeviceStateResponse.fromJson);
    return response.data;
  }

  Future<StepUpChallengeResponse> startSmartOtpLogin({
    required String userId,
    required String deviceId,
    required String externalTransactionId,
    required String transactionDigest,
    required DateTime expiresAtUtc,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/smart-otp/start',
      {
        'userId': userId,
        'deviceId': deviceId,
        'externalTransactionId': externalTransactionId,
        'transactionDigest': transactionDigest,
        'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
      },
      StepUpChallengeResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<StepUpRevealResponse> revealSmartOtpLogin({
    required String userId,
    required String challengeId,
    required String deviceId,
    required String deviceKeyId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required String revealRequestId,
    required DateTime issuedAtUtc,
    required DateTime proofExpiresAtUtc,
    required String deviceSignature,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/smart-otp/reveal',
      {
        'userId': userId,
        'challengeId': challengeId,
        'deviceId': deviceId,
        'deviceKeyId': deviceKeyId,
        'purpose': purpose,
        'externalTransactionId': externalTransactionId,
        'transactionDigest': transactionDigest,
        'revealRequestId': revealRequestId,
        'issuedAtUtc': issuedAtUtc.toUtc().toIso8601String(),
        'proofExpiresAtUtc': proofExpiresAtUtc.toUtc().toIso8601String(),
        'deviceSignature': deviceSignature,
      },
      StepUpRevealResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<PasswordLoginResponse> completeSmartOtpLogin({
    required String userId,
    required String challengeId,
    required String deviceId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required String otp,
    required DeviceContext deviceContext,
  }) async {
    final response = await _client.post(
      '/api/v1/auth/login/smart-otp/complete',
      {
        'userId': userId,
        'challengeId': challengeId,
        'deviceId': deviceId,
        'purpose': purpose,
        'externalTransactionId': externalTransactionId,
        'transactionDigest': transactionDigest,
        'otp': otp,
        'deviceContext': deviceContext.toJson(),
      },
      PasswordLoginResponse.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<StepUpChallengeResponse> startSmartOtpStepUp({
    required String deviceId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required DateTime expiresAtUtc,
  }) async {
    final response = await _client.post('/api/v1/smart-otp/step-up/start', {
      'deviceId': deviceId,
      'purpose': purpose,
      'externalTransactionId': externalTransactionId,
      'transactionDigest': transactionDigest,
      'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
    }, StepUpChallengeResponse.fromJson);
    return response.data;
  }

  Future<StepUpRevealResponse> revealSmartOtpStepUp({
    required String challengeId,
    required String deviceId,
    required String deviceKeyId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required String revealRequestId,
    required DateTime issuedAtUtc,
    required DateTime proofExpiresAtUtc,
    required String deviceSignature,
  }) async {
    final response = await _client.post('/api/v1/smart-otp/step-up/reveal', {
      'challengeId': challengeId,
      'deviceId': deviceId,
      'deviceKeyId': deviceKeyId,
      'purpose': purpose,
      'externalTransactionId': externalTransactionId,
      'transactionDigest': transactionDigest,
      'revealRequestId': revealRequestId,
      'issuedAtUtc': issuedAtUtc.toUtc().toIso8601String(),
      'proofExpiresAtUtc': proofExpiresAtUtc.toUtc().toIso8601String(),
      'deviceSignature': deviceSignature,
    }, StepUpRevealResponse.fromJson);
    return response.data;
  }

  Future<StepUpGrantResponse> verifySmartOtpStepUp({
    required String challengeId,
    required String deviceId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required String otp,
  }) async {
    final response = await _client.post('/api/v1/smart-otp/step-up/verify', {
      'challengeId': challengeId,
      'deviceId': deviceId,
      'purpose': purpose,
      'externalTransactionId': externalTransactionId,
      'transactionDigest': transactionDigest,
      'otp': otp,
    }, StepUpGrantResponse.fromJson);
    return response.data;
  }

  Future<TokenPair> refreshSession({
    required String refreshToken,
    String? sessionId,
  }) async {
    final body = <String, Object?>{'refreshToken': refreshToken};
    if (sessionId != null) {
      body['sessionId'] = sessionId;
    }
    final response = await _client.post(
      '/api/v1/sessions/refresh',
      body,
      TokenPair.fromJson,
      authenticated: false,
    );
    return response.data;
  }

  Future<List<SessionSummary>> listSessions() async {
    final response = await _client.get('/api/v1/sessions', (json) {
      final items = json is List<dynamic>
          ? json
          : ((json as JsonMap)['items'] as List<dynamic>? ?? const []);
      return items.map(SessionSummary.fromJson).toList(growable: false);
    });
    return response.data;
  }

  Future<LogoutAllSessionsResponse> logoutAllSessions({
    required String reasonCode,
    required bool includeCurrentSession,
  }) async {
    final response = await _client.post('/api/v1/sessions/logout-all', {
      'reasonCode': reasonCode,
      'includeCurrentSession': includeCurrentSession,
    }, LogoutAllSessionsResponse.fromJson);
    return response.data;
  }
}
