import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../core/device/device_context_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/auth_identity_store.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/validation/phone_number_normalizer.dart';
import '../data/models/security_models.dart';
import '../data/passkey_ceremony_service.dart';
import '../data/security_auth_api.dart';
import '../data/smart_otp_device_crypto_service.dart';

class AuthRepository {
  const AuthRepository({
    required SecurityAuthApi api,
    required PasskeyCeremonyService passkeys,
    required SmartOtpDeviceCryptoService smartOtpCrypto,
    required DeviceContextService deviceContext,
    required SecureTokenStore tokenStore,
    required AuthIdentityStore identityStore,
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    Uuid uuid = const Uuid(),
  }) : _api = api,
       _passkeys = passkeys,
       _smartOtpCrypto = smartOtpCrypto,
       _deviceContext = deviceContext,
       _tokenStore = tokenStore,
       _identityStore = identityStore,
       _secureStorage = secureStorage,
       _uuid = uuid;

  final SecurityAuthApi _api;
  final PasskeyCeremonyService _passkeys;
  final SmartOtpDeviceCryptoService _smartOtpCrypto;
  final DeviceContextService _deviceContext;
  final SecureTokenStore _tokenStore;
  final AuthIdentityStore _identityStore;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  static const _smartOtpBindingKey = 'xanhnow.smart_otp.binding';
  static const _registeredPhoneNumberKey =
      'xanhnow.registration.bound_phone_number';
  static const _smartOtpOriginServiceId = 'xanhnow-auth-login';

  Future<RegisterResponse> registerWithPassword({
    required String phoneNumber,
    required String password,
    required String displayName,
  }) async {
    final device = await _deviceContext.current();
    final normalizedPhone = PhoneNumberNormalizer.normalizeVietnamesePhone(
      phoneNumber,
    );
    final registeredPhone = await _secureStorage.read(
      key: _registeredPhoneNumberKey,
    );
    if (registeredPhone != null &&
        registeredPhone.isNotEmpty &&
        registeredPhone != normalizedPhone) {
      throw const AppException(
        'App này đã đăng ký với một số điện thoại khác. Vui lòng dùng đúng số đã đăng ký trên thiết bị này.',
      );
    }

    final result = await _api.register(
      phoneNumber: normalizedPhone,
      password: password,
      displayName: displayName,
      deviceContext: device,
    );
    await _secureStorage.write(
      key: _registeredPhoneNumberKey,
      value: normalizedPhone,
    );
    return result;
  }

  Future<FinishRegistrationPasskeyResponse> completeMandatoryPasskey({
    required String userId,
    required String displayName,
  }) async {
    final device = await _deviceContext.current();
    if (device.deviceId.isEmpty) {
      throw const AppException('Device id is required for passkey.');
    }

    final begin = await _api.beginRegistrationPasskey(
      userId: userId,
      displayName: await _passkeyDisplayName(displayName),
      deviceContext: device,
    );
    final credential = await _passkeys.createCredential(begin.publicKeyOptions);
    return _api.finishRegistrationPasskey(
      userId: userId,
      ceremonyId: begin.ceremonyId,
      credential: credential,
      deviceContext: device,
    );
  }

  Future<PasswordLoginResponse> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    final result = await _api.loginWithPassword(
      phoneNumber: PhoneNumberNormalizer.normalizeVietnamesePhone(phoneNumber),
      password: password,
      deviceContext: await _deviceContext.current(),
    );
    return _withStoredPhoneIdentity(result);
  }

  Future<PasskeyLoginFinishResponse> loginWithPasskey({
    String? loginIdentifier,
  }) async {
    final device = await _deviceContext.current();
    final storedRegisteredPhone = await _secureStorage.read(
      key: _registeredPhoneNumberKey,
    );
    final effectiveIdentifier =
        loginIdentifier == null || loginIdentifier.trim().isEmpty
        ? storedRegisteredPhone
        : loginIdentifier;
    final normalizedIdentifier =
        effectiveIdentifier == null || effectiveIdentifier.trim().isEmpty
        ? null
        : PhoneNumberNormalizer.normalizeVietnamesePhone(effectiveIdentifier);
    final begin = await _api.beginPasskeyLogin(
      loginIdentifier: normalizedIdentifier,
      deviceContext: device,
    );
    final credential = await _passkeys.authenticate(begin.publicKeyOptions);
    final result = await _api.finishPasskeyLogin(
      ceremonyId: begin.ceremonyId,
      credential: credential,
      deviceContext: device,
    );
    return _withStoredPhoneIdentityForPasskey(result);
  }

  Future<SecurityProfile> securityProfile() => _api.securityProfile();

  Future<SmartOtpDeviceStateResponse> enrollSmartOtpDevice({
    required String userId,
    required TokenPair authorizationTokens,
  }) async {
    return _api.withTemporaryAccessToken(
      authorizationTokens.accessToken,
      () async {
        final device = await _deviceContext.current();
        final keyMaterial = await _smartOtpCrypto.prepareDeviceKey();
        final begin = await _api.beginSmartOtpEnrollment(
          deviceName: device.deviceName,
          platform: _toSmartOtpPlatform(device.platform),
          appInstanceIdHash: keyMaterial.appInstanceIdHash,
          keyAlgorithm: keyMaterial.keyAlgorithm,
          candidatePublicKeySpki: keyMaterial.candidatePublicKeySpki,
          candidatePublicKeyThumbprint:
              keyMaterial.candidatePublicKeyThumbprint,
        );
        final proof = await _smartOtpCrypto.signBinding(
          userId: userId,
          enrollmentId: begin.enrollmentId,
          serverChallenge: begin.serverChallenge,
          candidatePublicKeyThumbprint:
              keyMaterial.candidatePublicKeyThumbprint,
          appInstanceIdHash: keyMaterial.appInstanceIdHash,
          createdAtUtc: begin.createdAtUtc,
          expiresAtUtc: begin.expiresAtUtc,
        );
        final result = await _api.confirmSmartOtpEnrollment(
          enrollmentId: begin.enrollmentId,
          clientNonce: proof.clientNonce,
          deviceSignature: proof.deviceSignature,
        );
        if (result.isEnabled) {
          await _saveSmartOtpBinding(userId: userId, state: result);
        }
        return result;
      },
    );
  }

  Future<SmartOtpCodeChallenge> revealLoginSmartOtpCode({
    required String userId,
  }) async {
    final binding = await _readSmartOtpBinding(userId: userId);
    if (binding == null) {
      throw const AppException(
        'Thiết bị này chưa thiết lập Smart OTP cho tài khoản này. Vui lòng đăng nhập bằng thiết bị đã đăng ký Smart OTP.',
      );
    }

    const externalTransactionId = '';
    const transactionDigest = '';
    final now = DateTime.now().toUtc();
    final challenge = await _api.startSmartOtpLogin(
      userId: userId,
      deviceId: binding.deviceId,
      externalTransactionId: externalTransactionId,
      transactionDigest: transactionDigest,
      expiresAtUtc: now.add(const Duration(seconds: 30)),
    );
    final revealRequestId = _uuid.v4();
    final issuedAt = DateTime.now().toUtc();
    final proofExpiresAt = issuedAt.add(const Duration(seconds: 30));
    final proof = await _smartOtpCrypto.signReveal(
      challengeId: challenge.challengeId,
      revealRequestId: revealRequestId,
      externalUserId: challenge.externalUserId,
      deviceId: challenge.deviceId,
      deviceKeyId: challenge.deviceKeyId,
      originServiceId: _smartOtpOriginServiceId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      issuedAtUtc: issuedAt,
      proofExpiresAtUtc: proofExpiresAt,
    );

    final reveal = await _api.revealSmartOtpLogin(
      userId: userId,
      challengeId: challenge.challengeId,
      deviceId: challenge.deviceId,
      deviceKeyId: challenge.deviceKeyId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      revealRequestId: revealRequestId,
      issuedAtUtc: issuedAt,
      proofExpiresAtUtc: proofExpiresAt,
      deviceSignature: proof.deviceSignature,
    );
    return SmartOtpCodeChallenge(challenge: challenge, reveal: reveal);
  }

  Future<PasswordLoginResponse> verifyLoginSmartOtpCode({
    required String userId,
    required StepUpChallengeResponse challenge,
    required String otp,
  }) async {
    final result = await _api.completeSmartOtpLogin(
      userId: userId,
      challengeId: challenge.challengeId,
      deviceId: challenge.deviceId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      otp: otp,
      deviceContext: await _deviceContext.current(),
    );
    return _withStoredPhoneIdentity(result);
  }

  Future<SmartOtpCodeChallenge> revealSmartOtpCode() async {
    final binding = await _readSmartOtpBinding();
    if (binding == null) {
      throw const AppException(
        'Thiết bị này chưa thiết lập Smart OTP. Vui lòng đăng ký Smart OTP trước.',
      );
    }

    const purpose = 'login_smart_otp';
    const externalTransactionId = '';
    const transactionDigest = '';
    final now = DateTime.now().toUtc();
    final challenge = await _api.startSmartOtpStepUp(
      deviceId: binding.deviceId,
      purpose: purpose,
      externalTransactionId: externalTransactionId,
      transactionDigest: transactionDigest,
      expiresAtUtc: now.add(const Duration(seconds: 30)),
    );
    final revealRequestId = _uuid.v4();
    final issuedAt = DateTime.now().toUtc();
    final proofExpiresAt = issuedAt.add(const Duration(seconds: 30));
    final proof = await _smartOtpCrypto.signReveal(
      challengeId: challenge.challengeId,
      revealRequestId: revealRequestId,
      externalUserId: challenge.externalUserId,
      deviceId: challenge.deviceId,
      deviceKeyId: challenge.deviceKeyId,
      originServiceId: _smartOtpOriginServiceId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      issuedAtUtc: issuedAt,
      proofExpiresAtUtc: proofExpiresAt,
    );

    final reveal = await _api.revealSmartOtpStepUp(
      challengeId: challenge.challengeId,
      deviceId: challenge.deviceId,
      deviceKeyId: challenge.deviceKeyId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      revealRequestId: revealRequestId,
      issuedAtUtc: issuedAt,
      proofExpiresAtUtc: proofExpiresAt,
      deviceSignature: proof.deviceSignature,
    );
    return SmartOtpCodeChallenge(challenge: challenge, reveal: reveal);
  }

  Future<StepUpGrantResponse> verifySmartOtpCode({
    required StepUpChallengeResponse challenge,
    required String otp,
  }) {
    return _api.verifySmartOtpStepUp(
      challengeId: challenge.challengeId,
      deviceId: challenge.deviceId,
      purpose: challenge.purpose,
      externalTransactionId: challenge.externalTransactionId,
      transactionDigest: challenge.transactionDigest,
      otp: otp,
    );
  }

  Future<void> _saveSmartOtpBinding({
    required String userId,
    required SmartOtpDeviceStateResponse state,
  }) {
    return _secureStorage.write(
      key: _smartOtpBindingKey,
      value: jsonEncode({
        'userId': userId,
        'deviceId': state.deviceId,
        'deviceKeyId': state.deviceKeyId,
      }),
    );
  }

  Future<_SmartOtpBinding?> _readSmartOtpBinding({String? userId}) async {
    final raw = await _secureStorage.read(key: _smartOtpBindingKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final bindingUserId = map['userId'] as String?;
    if (userId != null && bindingUserId != userId) {
      return null;
    }
    return _SmartOtpBinding(
      userId: bindingUserId,
      deviceId: map['deviceId'] as String,
      deviceKeyId: map['deviceKeyId'] as String,
    );
  }

  String _toSmartOtpPlatform(String platform) {
    return switch (platform.toLowerCase()) {
      'android' => 'ANDROID',
      'ios' => 'IOS',
      _ => platform.toUpperCase(),
    };
  }

  Future<String> _passkeyDisplayName(String displayName) async {
    final phoneNumber = await _storedRegisteredPhone();
    final maskedPhone = _maskPhoneNumber(phoneNumber);
    if (maskedPhone == null || maskedPhone.isEmpty) {
      return displayName;
    }
    return '$displayName ($maskedPhone)';
  }

  Future<String?> _storedRegisteredPhone() async {
    final phone = await _secureStorage.read(key: _registeredPhoneNumberKey);
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }
    return PhoneNumberNormalizer.normalizeVietnamesePhone(phone);
  }

  AuthIdentity _identityWithStoredPhone(
    String userId,
    AuthIdentity? identity,
    String? storedPhone,
  ) {
    final phoneNumber = identity?.phoneNumber ?? storedPhone;
    return AuthIdentity(
      userId: identity?.userId ?? userId,
      phoneNumber: phoneNumber,
      maskedPhoneNumber:
          identity?.maskedPhoneNumber ?? _maskPhoneNumber(phoneNumber),
    );
  }

  Future<PasswordLoginResponse> _withStoredPhoneIdentity(
    PasswordLoginResponse response,
  ) async {
    final storedPhone = await _storedRegisteredPhone();
    return PasswordLoginResponse(
      state: response.state,
      userId: response.userId,
      tokens: response.tokens,
      mfa: response.mfa,
      reasonCode: response.reasonCode,
      identity: _identityWithStoredPhone(
        response.userId,
        response.identity,
        storedPhone,
      ),
    );
  }

  Future<PasskeyLoginFinishResponse> _withStoredPhoneIdentityForPasskey(
    PasskeyLoginFinishResponse response,
  ) async {
    final storedPhone = await _storedRegisteredPhone();
    return PasskeyLoginFinishResponse(
      state: response.state,
      userId: response.userId,
      tokens: response.tokens,
      mfa: response.mfa,
      reasonCode: response.reasonCode,
      identity: _identityWithStoredPhone(
        response.userId,
        response.identity,
        storedPhone,
      ),
    );
  }

  String? _maskPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return null;
    }
    if (phoneNumber.length <= 4) {
      return phoneNumber;
    }
    return phoneNumber
        .substring(phoneNumber.length - 4)
        .padLeft(phoneNumber.length, '*');
  }

  Future<TokenPair?> refreshStoredSession() async {
    final current = await _tokenStore.read();
    if (current == null) {
      return null;
    }
    final refreshed = await _api.refreshSession(
      refreshToken: current.refreshToken,
      sessionId: current.sessionId,
    );
    await _tokenStore.save(refreshed);
    return refreshed;
  }

  Future<List<SessionSummary>> listSessions() => _api.listSessions();

  Future<LogoutAllSessionsResponse> logoutAll() async {
    try {
      return await _api.logoutAllSessions(
        reasonCode: 'mobile_logout_all',
        includeCurrentSession: true,
      );
    } on AppException catch (error) {
      if (error.statusCode == 401) {
        return LogoutAllSessionsResponse(
          revokedCount: 0,
          revokedAtUtc: DateTime.now().toUtc(),
        );
      }

      rethrow;
    } finally {
      await _tokenStore.clear();
      await _identityStore.clear();
    }
  }
}

class _SmartOtpBinding {
  const _SmartOtpBinding({
    required this.userId,
    required this.deviceId,
    required this.deviceKeyId,
  });

  final String? userId;
  final String deviceId;
  final String deviceKeyId;
}

class SmartOtpCodeChallenge {
  const SmartOtpCodeChallenge({required this.challenge, required this.reveal});

  final StepUpChallengeResponse challenge;
  final StepUpRevealResponse reveal;
}
