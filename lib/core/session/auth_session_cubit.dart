import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/models/security_models.dart';
import '../storage/secure_token_store.dart';

enum AuthSessionStatus {
  unknown,
  unauthenticated,
  pendingRegistration,
  authenticated,
  expired,
  revoked,
}

class AuthSessionState extends Equatable {
  const AuthSessionState({
    required this.status,
    this.tokens,
    this.userId,
    this.preferLogin = false,
  });

  const AuthSessionState.unknown() : this(status: AuthSessionStatus.unknown);
  const AuthSessionState.unauthenticated({bool preferLogin = false})
    : this(status: AuthSessionStatus.unauthenticated, preferLogin: preferLogin);
  const AuthSessionState.pendingRegistration(String userId)
    : this(status: AuthSessionStatus.pendingRegistration, userId: userId);
  const AuthSessionState.authenticated(TokenPair tokens)
    : this(status: AuthSessionStatus.authenticated, tokens: tokens);

  final AuthSessionStatus status;
  final TokenPair? tokens;
  final String? userId;
  final bool preferLogin;

  @override
  List<Object?> get props => [status, tokens, userId, preferLogin];
}

class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit({required SecureTokenStore tokenStore})
    : _tokenStore = tokenStore,
      super(const AuthSessionState.unknown());

  final SecureTokenStore _tokenStore;

  Future<void> restore() async {
    final tokens = await _tokenStore.read();
    emit(
      tokens == null
          ? const AuthSessionState.unauthenticated()
          : AuthSessionState.authenticated(tokens),
    );
  }

  Future<void> authenticate(TokenPair tokens) async {
    await _tokenStore.save(tokens);
    emit(AuthSessionState.authenticated(tokens));
  }

  void markPendingRegistration(String userId) {
    emit(AuthSessionState.pendingRegistration(userId));
  }

  Future<void> clear() async {
    await _tokenStore.clear();
    emit(const AuthSessionState.unauthenticated(preferLogin: true));
  }
}
