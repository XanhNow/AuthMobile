import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/security_models.dart';

class AuthIdentityStore {
  const AuthIdentityStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const key = 'xanhnow.auth.identity';

  final FlutterSecureStorage _storage;

  Future<void> save(AuthIdentity identity) {
    return _storage.write(key: key, value: jsonEncode(identity.toJson()));
  }

  Future<AuthIdentity?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AuthIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.delete(key: key);
}
