import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/models/security_models.dart';

class DeviceContextService {
  DeviceContextService({
    FlutterSecureStorage? storage,
    Uuid? uuid,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  static const _deviceIdKey = 'xanhnow.device_context.device_id';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  Future<DeviceContext> current() async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return DeviceContext(
      deviceId: deviceId,
      deviceName: _deviceName(),
      platform: _platformName(),
    );
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  String _deviceName() {
    if (kIsWeb) {
      return 'flutter-web';
    }
    return 'xanhnow-mobile';
  }
}
