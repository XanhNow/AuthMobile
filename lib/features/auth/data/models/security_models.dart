typedef JsonMap = Map<String, dynamic>;

class DeviceContext {
  const DeviceContext({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.ipAddress,
    this.userAgent,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String? ipAddress;
  final String? userAgent;

  JsonMap toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    if (ipAddress != null) 'ipAddress': ipAddress,
    if (userAgent != null) 'userAgent': userAgent,
  };
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAtUtc,
    required this.refreshTokenExpiresAtUtc,
    this.sessionId,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAtUtc;
  final DateTime refreshTokenExpiresAtUtc;
  final String? sessionId;
  final String tokenType;

  factory TokenPair.fromJson(Object? json) {
    final map = json as JsonMap;
    return TokenPair(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      accessTokenExpiresAtUtc: DateTime.parse(
        map['accessTokenExpiresAtUtc'] as String,
      ),
      refreshTokenExpiresAtUtc: DateTime.parse(
        map['refreshTokenExpiresAtUtc'] as String,
      ),
      sessionId: map['sessionId'] as String?,
      tokenType: (map['tokenType'] as String?) ?? 'Bearer',
    );
  }

  JsonMap toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc.toIso8601String(),
    'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc.toIso8601String(),
    if (sessionId != null) 'sessionId': sessionId,
    'tokenType': tokenType,
  };
}

class RegisterResponse {
  const RegisterResponse({
    required this.userId,
    required this.status,
    required this.registrationStatus,
    required this.registeredAtUtc,
  });

  final String userId;
  final String status;
  final String registrationStatus;
  final DateTime registeredAtUtc;

  factory RegisterResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return RegisterResponse(
      userId: map['userId'] as String,
      status: map['status'] as String,
      registrationStatus: map['registrationStatus'] as String,
      registeredAtUtc: DateTime.parse(map['registeredAtUtc'] as String),
    );
  }
}

class PasswordLoginResponse {
  const PasswordLoginResponse({
    required this.state,
    required this.userId,
    this.tokens,
    this.mfa,
    this.reasonCode,
  });

  final String state;
  final String userId;
  final TokenPair? tokens;
  final MfaChallengeResponse? mfa;
  final String? reasonCode;

  bool get isCompleted => state == 'Completed' && tokens != null;
  bool get isPasskeyRequired => state == 'PasskeyRequired';
  bool get isMfaRequired => state == 'MfaRequired';

  factory PasswordLoginResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return PasswordLoginResponse(
      state: map['state'] as String,
      userId: map['userId'] as String,
      tokens: map['tokens'] == null ? null : TokenPair.fromJson(map['tokens']),
      mfa: map['mfa'] == null
          ? null
          : MfaChallengeResponse.fromJson(map['mfa']),
      reasonCode: map['reasonCode'] as String?,
    );
  }
}

class MfaChallengeResponse {
  const MfaChallengeResponse({
    required this.challengeId,
    required this.method,
    required this.expiresAtUtc,
  });

  final String challengeId;
  final String method;
  final DateTime expiresAtUtc;

  factory MfaChallengeResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return MfaChallengeResponse(
      challengeId: map['challengeId'] as String,
      method: map['method'] as String,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
    );
  }
}

class BeginRegistrationPasskeyResponse {
  const BeginRegistrationPasskeyResponse({
    required this.userId,
    required this.ceremonyId,
    required this.publicKeyOptions,
    required this.expiresAtUtc,
  });

  final String userId;
  final String ceremonyId;
  final JsonMap publicKeyOptions;
  final DateTime expiresAtUtc;

  factory BeginRegistrationPasskeyResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return BeginRegistrationPasskeyResponse(
      userId: map['userId'] as String,
      ceremonyId: map['ceremonyId'] as String,
      publicKeyOptions: map['publicKeyOptions'] as JsonMap,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
    );
  }
}

class FinishRegistrationPasskeyResponse {
  const FinishRegistrationPasskeyResponse({
    required this.userId,
    required this.registrationStatus,
    required this.completedAtUtc,
  });

  final String userId;
  final String registrationStatus;
  final DateTime completedAtUtc;

  factory FinishRegistrationPasskeyResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return FinishRegistrationPasskeyResponse(
      userId: map['userId'] as String,
      registrationStatus: map['registrationStatus'] as String,
      completedAtUtc: DateTime.parse(map['completedAtUtc'] as String),
    );
  }
}

class PasskeyLoginBeginResponse {
  const PasskeyLoginBeginResponse({
    required this.ceremonyId,
    required this.publicKeyOptions,
    required this.expiresAtUtc,
  });

  final String ceremonyId;
  final JsonMap publicKeyOptions;
  final DateTime expiresAtUtc;

  factory PasskeyLoginBeginResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return PasskeyLoginBeginResponse(
      ceremonyId: map['ceremonyId'] as String,
      publicKeyOptions: map['publicKeyOptions'] as JsonMap,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
    );
  }
}

class PasskeyLoginFinishResponse {
  const PasskeyLoginFinishResponse({
    required this.state,
    required this.userId,
    this.tokens,
    this.mfa,
    this.reasonCode,
  });

  final String state;
  final String userId;
  final TokenPair? tokens;
  final MfaChallengeResponse? mfa;
  final String? reasonCode;

  bool get isCompleted => state == 'Completed' && tokens != null;
  bool get isMfaRequired => state == 'MfaRequired';

  factory PasskeyLoginFinishResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return PasskeyLoginFinishResponse(
      state: map['state'] as String,
      userId: map['userId'] as String,
      tokens: map['tokens'] == null ? null : TokenPair.fromJson(map['tokens']),
      mfa: map['mfa'] == null
          ? null
          : MfaChallengeResponse.fromJson(map['mfa']),
      reasonCode: map['reasonCode'] as String?,
    );
  }
}

class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.status,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    this.isCurrent,
  });

  final String sessionId;
  final String status;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;
  final bool? isCurrent;

  factory SessionSummary.fromJson(Object? json) {
    final map = json as JsonMap;
    return SessionSummary(
      sessionId: map['sessionId'] as String,
      status: map['status'] as String,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String),
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
      isCurrent: map['isCurrent'] as bool?,
    );
  }
}

class SecurityProfile {
  const SecurityProfile({
    required this.userId,
    required this.status,
    required this.hasPasskey,
    required this.hasSmartOtp,
    this.maskedPhoneNumber,
  });

  final String userId;
  final String status;
  final bool hasPasskey;
  final bool hasSmartOtp;
  final String? maskedPhoneNumber;

  factory SecurityProfile.fromJson(Object? json) {
    final map = json as JsonMap;
    return SecurityProfile(
      userId: map['userId'] as String,
      status: map['status'] as String,
      hasPasskey: map['hasPasskey'] as bool,
      hasSmartOtp: map['hasSmartOtp'] as bool,
      maskedPhoneNumber: map['maskedPhoneNumber'] as String?,
    );
  }
}

class BeginSmartOtpEnrollmentResponse {
  const BeginSmartOtpEnrollmentResponse({
    required this.enrollmentId,
    required this.serverChallenge,
    required this.challengeFormatVersion,
    required this.createdAtUtc,
    required this.expiresAtUtc,
    required this.status,
  });

  final String enrollmentId;
  final String serverChallenge;
  final int challengeFormatVersion;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;
  final String status;

  factory BeginSmartOtpEnrollmentResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return BeginSmartOtpEnrollmentResponse(
      enrollmentId: map['enrollmentId'] as String,
      serverChallenge: map['serverChallenge'] as String,
      challengeFormatVersion: map['challengeFormatVersion'] as int,
      createdAtUtc: DateTime.parse(map['createdAtUtc'] as String),
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
      status: map['status'] as String,
    );
  }
}

class SmartOtpDeviceStateResponse {
  const SmartOtpDeviceStateResponse({
    required this.deviceId,
    required this.deviceKeyId,
    required this.status,
    required this.isEnabled,
    required this.updatedAtUtc,
  });

  final String deviceId;
  final String deviceKeyId;
  final String status;
  final bool isEnabled;
  final DateTime updatedAtUtc;

  factory SmartOtpDeviceStateResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return SmartOtpDeviceStateResponse(
      deviceId: map['deviceId'] as String,
      deviceKeyId: map['deviceKeyId'] as String,
      status: map['status'] as String,
      isEnabled: map['isEnabled'] as bool,
      updatedAtUtc: DateTime.parse(map['updatedAtUtc'] as String),
    );
  }
}

class StepUpChallengeResponse {
  const StepUpChallengeResponse({
    required this.challengeId,
    required this.externalUserId,
    required this.deviceId,
    required this.deviceKeyId,
    required this.purpose,
    required this.externalTransactionId,
    required this.transactionDigest,
    required this.expiresAtUtc,
    required this.codeLength,
    required this.maxAttempts,
  });

  final String challengeId;
  final String externalUserId;
  final String deviceId;
  final String deviceKeyId;
  final String purpose;
  final String externalTransactionId;
  final String transactionDigest;
  final DateTime expiresAtUtc;
  final int codeLength;
  final int maxAttempts;

  factory StepUpChallengeResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return StepUpChallengeResponse(
      challengeId: map['challengeId'] as String,
      externalUserId: map['externalUserId'] as String,
      deviceId: map['deviceId'] as String,
      deviceKeyId: map['deviceKeyId'] as String,
      purpose: map['purpose'] as String,
      externalTransactionId: map['externalTransactionId'] as String,
      transactionDigest: map['transactionDigest'] as String,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
      codeLength: map['codeLength'] as int,
      maxAttempts: map['maxAttempts'] as int,
    );
  }
}

class StepUpRevealResponse {
  const StepUpRevealResponse({
    required this.challengeId,
    required this.otpCode,
    required this.expiresAtUtc,
    required this.revealCount,
    required this.releasedAtUtc,
  });

  final String challengeId;
  final String otpCode;
  final DateTime expiresAtUtc;
  final int revealCount;
  final DateTime releasedAtUtc;

  factory StepUpRevealResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return StepUpRevealResponse(
      challengeId: map['challengeId'] as String,
      otpCode: map['otpCode'] as String,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
      revealCount: map['revealCount'] as int,
      releasedAtUtc: DateTime.parse(map['releasedAtUtc'] as String),
    );
  }
}

class StepUpGrantResponse {
  const StepUpGrantResponse({
    required this.challengeId,
    required this.stepUpGrant,
    required this.purpose,
    required this.expiresAtUtc,
  });

  final String challengeId;
  final String stepUpGrant;
  final String purpose;
  final DateTime expiresAtUtc;

  factory StepUpGrantResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return StepUpGrantResponse(
      challengeId: map['challengeId'] as String,
      stepUpGrant: map['stepUpGrant'] as String,
      purpose: map['purpose'] as String,
      expiresAtUtc: DateTime.parse(map['expiresAtUtc'] as String),
    );
  }
}

class LogoutAllSessionsResponse {
  const LogoutAllSessionsResponse({
    required this.revokedCount,
    required this.revokedAtUtc,
  });

  final int revokedCount;
  final DateTime revokedAtUtc;

  factory LogoutAllSessionsResponse.fromJson(Object? json) {
    final map = json as JsonMap;
    return LogoutAllSessionsResponse(
      revokedCount: map['revokedCount'] as int,
      revokedAtUtc: DateTime.parse(map['revokedAtUtc'] as String),
    );
  }
}
