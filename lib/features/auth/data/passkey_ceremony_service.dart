import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../../../core/errors/app_exception.dart';
import 'models/security_models.dart';

class PasskeyCeremonyService {
  PasskeyCeremonyService({PasskeyAuthenticator? authenticator})
    : _authenticator = authenticator ?? PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  Future<bool> canAuthenticate() async {
    try {
      if (kIsWeb) {
        return (await _authenticator.getAvailability().web()).hasPasskeySupport;
      }
      return switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          (await _authenticator.getAvailability().android()).hasPasskeySupport,
        TargetPlatform.iOS =>
          (await _authenticator.getAvailability().iOS()).hasPasskeySupport,
        TargetPlatform.windows =>
          (await _authenticator.getAvailability().windows()).hasPasskeySupport,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }

  Future<JsonMap> createCredential(JsonMap publicKeyOptions) async {
    try {
      final request = RegisterRequestType.fromJson(
        _publicKey(publicKeyOptions),
      );
      final credential = await _authenticator.register(request);
      return credential.toJson();
    } catch (error) {
      debugPrint('XanhNow passkey create failed: $error');
      throw _mapPasskeyError(error);
    }
  }

  Future<JsonMap> authenticate(JsonMap publicKeyOptions) async {
    try {
      final request = AuthenticateRequestType.fromJson(
        _publicKey(publicKeyOptions),
        preferImmediatelyAvailableCredentials: false,
      );
      final credential = await _authenticator.authenticate(request);
      return credential.toJson();
    } catch (error) {
      debugPrint('XanhNow passkey authenticate failed: $error');
      throw _mapPasskeyError(error);
    }
  }

  JsonMap _publicKey(JsonMap options) {
    final nested = options['publicKey'];
    if (nested is JsonMap) {
      return nested;
    }
    return options;
  }

  AppException _mapPasskeyError(Object error) {
    final message = error.toString();
    if (message.contains('RP ID cannot be validated')) {
      return const AppException(
        'Android chưa liên kết app với api.ioxy.site. Cần cấu hình '
        'assetlinks.json cho package Android và SHA-256 ký app, rồi cài lại.',
      );
    }
    if (message.contains('NoCredential') ||
        message.contains('NO_CREDENTIAL') ||
        message.contains('No credentials')) {
      return const AppException(
        'Không tìm thấy passkey phù hợp trên thiết bị. Hãy đăng ký passkey '
        'trước hoặc chọn đúng tài khoản Google/thiết bị lưu passkey.',
      );
    }
    if (message.contains('cancel') ||
        message.contains('CANCEL') ||
        message.contains('interrupted')) {
      return const AppException(
        'Bạn đã hủy thao tác passkey. Vui lòng thử lại nếu muốn tiếp tục.',
      );
    }
    if (message.contains('network') ||
        message.contains('NETWORK') ||
        message.contains('connection') ||
        message.contains('CONNECTION')) {
      return const AppException(
        'Android/Google Password Manager không kết nối được để tạo passkey. '
        'Hãy kiểm tra Internet, Google Play services và tài khoản Google.',
      );
    }
    if (message.contains('Get Key Material failed') ||
        message.contains('TYPE_NOT_ALLOWED_ERROR')) {
      return const AppException(
        'Android/Google Password Manager chưa tạo được passkey sau khi bạn xác nhận. '
        'Hãy kiểm tra khóa màn hình, tài khoản Google, Google Play services, '
        'rồi thử lại hoặc chọn cách lưu passkey khác.',
      );
    }
    if (message.contains('Flow has timed out') ||
        message.contains('android-unhandledGoogle Password Manager')) {
      return const AppException(
        'Google Password Manager bị quá thời gian khi tạo passkey. '
        'Hãy mở khóa điện thoại, kiểm tra tài khoản Google, rồi thử lại. '
        'Nếu vẫn lỗi, cần dọn cache Google Play services/Credential Manager.',
      );
    }
    return AppException(message);
  }
}
