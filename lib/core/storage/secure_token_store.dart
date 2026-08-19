import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/security_models.dart';

class SecureTokenStore {
  const SecureTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _key = 'xanhnow.auth.tokens';

  final FlutterSecureStorage _storage;

  Future<void> save(TokenPair tokens) {
    return _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  Future<TokenPair?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return TokenPair.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
