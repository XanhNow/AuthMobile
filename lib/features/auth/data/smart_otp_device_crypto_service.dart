import 'package:flutter/services.dart';

class SmartOtpDeviceKeyMaterial {
  const SmartOtpDeviceKeyMaterial({
    required this.keyAlgorithm,
    required this.appInstanceIdHash,
    required this.candidatePublicKeySpki,
    required this.candidatePublicKeyThumbprint,
  });

  final String keyAlgorithm;
  final String appInstanceIdHash;
  final String candidatePublicKeySpki;
  final String candidatePublicKeyThumbprint;

  factory SmartOtpDeviceKeyMaterial.fromMap(Map<Object?, Object?> map) {
    return SmartOtpDeviceKeyMaterial(
      keyAlgorithm: map['keyAlgorithm'] as String,
      appInstanceIdHash: map['appInstanceIdHash'] as String,
      candidatePublicKeySpki: map['candidatePublicKeySpki'] as String,
      candidatePublicKeyThumbprint:
          map['candidatePublicKeyThumbprint'] as String,
    );
  }
}

class SmartOtpBindingProof {
  const SmartOtpBindingProof({
    required this.clientNonce,
    required this.deviceSignature,
  });

  final String clientNonce;
  final String deviceSignature;

  factory SmartOtpBindingProof.fromMap(Map<Object?, Object?> map) {
    return SmartOtpBindingProof(
      clientNonce: map['clientNonce'] as String,
      deviceSignature: map['deviceSignature'] as String,
    );
  }
}

class SmartOtpRevealProof {
  const SmartOtpRevealProof({required this.deviceSignature});

  final String deviceSignature;

  factory SmartOtpRevealProof.fromMap(Map<Object?, Object?> map) {
    return SmartOtpRevealProof(
      deviceSignature: map['deviceSignature'] as String,
    );
  }
}

class SmartOtpDeviceCryptoService {
  SmartOtpDeviceCryptoService({
    MethodChannel channel = const MethodChannel(
      'xanhnow.smart_otp/device_crypto',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<SmartOtpDeviceKeyMaterial> prepareDeviceKey() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'prepareDeviceKey',
    );
    if (result == null) {
      throw PlatformException(
        code: 'SMART_OTP_DEVICE_CRYPTO_EMPTY',
        message: 'Smart OTP device key material was empty.',
      );
    }
    return SmartOtpDeviceKeyMaterial.fromMap(result);
  }

  Future<SmartOtpBindingProof> signBinding({
    required String userId,
    required String enrollmentId,
    required String serverChallenge,
    required String candidatePublicKeyThumbprint,
    required String appInstanceIdHash,
    required DateTime createdAtUtc,
    required DateTime expiresAtUtc,
  }) async {
    final createdAtUnixMs = createdAtUtc.toUtc().millisecondsSinceEpoch;
    final expiresAtUnixMs = expiresAtUtc.toUtc().millisecondsSinceEpoch;
    final result = await _channel
        .invokeMapMethod<Object?, Object?>('signBinding', {
          'enrollmentId': enrollmentId,
          'externalUserId': _toSmartOtpExternalUserId(userId),
          'serverChallenge': serverChallenge,
          'candidatePublicKeyThumbprint': candidatePublicKeyThumbprint,
          'appInstanceIdHash': appInstanceIdHash,
          'createdAtUnixMs': createdAtUnixMs,
          'expiresAtUnixMs': expiresAtUnixMs,
        });
    if (result == null) {
      throw PlatformException(
        code: 'SMART_OTP_DEVICE_SIGNATURE_EMPTY',
        message: 'Smart OTP device signature was empty.',
      );
    }
    return SmartOtpBindingProof.fromMap(result);
  }

  Future<SmartOtpRevealProof> signReveal({
    required String challengeId,
    required String revealRequestId,
    required String externalUserId,
    required String deviceId,
    required String deviceKeyId,
    required String originServiceId,
    required String purpose,
    required String externalTransactionId,
    required String transactionDigest,
    required DateTime issuedAtUtc,
    required DateTime proofExpiresAtUtc,
  }) async {
    final result = await _channel
        .invokeMapMethod<Object?, Object?>('signReveal', {
          'challengeId': challengeId,
          'revealRequestId': revealRequestId,
          'externalUserId': externalUserId,
          'deviceId': deviceId,
          'deviceKeyId': deviceKeyId,
          'originServiceId': originServiceId,
          'purpose': purpose,
          'externalTransactionId': externalTransactionId,
          'transactionDigest': transactionDigest,
          'issuedAtUnixMs': issuedAtUtc.toUtc().millisecondsSinceEpoch,
          'proofExpiresAtUnixMs': proofExpiresAtUtc
              .toUtc()
              .millisecondsSinceEpoch,
        });
    if (result == null) {
      throw PlatformException(
        code: 'SMART_OTP_REVEAL_SIGNATURE_EMPTY',
        message: 'Smart OTP reveal signature was empty.',
      );
    }
    return SmartOtpRevealProof.fromMap(result);
  }

  String _toSmartOtpExternalUserId(String userId) {
    final hex = userId.replaceAll('-', '');
    if (hex.length != 32) {
      throw FormatException('Invalid user id.', userId);
    }

    final bytes = <int>[
      _hexByte(hex, 6),
      _hexByte(hex, 4),
      _hexByte(hex, 2),
      _hexByte(hex, 0),
      _hexByte(hex, 10),
      _hexByte(hex, 8),
      _hexByte(hex, 14),
      _hexByte(hex, 12),
      for (var index = 16; index < 32; index += 2) _hexByte(hex, index),
    ];

    final upper = _littleEndianUInt64(bytes, 0);
    final lower = _littleEndianUInt64(bytes, 8);
    var value = (upper << 64) | lower;
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final chars = List<String>.filled(26, '0');
    for (var index = 25; index >= 0; index--) {
      chars[index] = alphabet[(value & BigInt.from(31)).toInt()];
      value >>= 5;
    }
    return chars.join();
  }

  int _hexByte(String hex, int offset) =>
      int.parse(hex.substring(offset, offset + 2), radix: 16);

  BigInt _littleEndianUInt64(List<int> bytes, int offset) {
    var value = BigInt.zero;
    for (var index = 7; index >= 0; index--) {
      value = (value << 8) | BigInt.from(bytes[offset + index]);
    }
    return value;
  }
}
