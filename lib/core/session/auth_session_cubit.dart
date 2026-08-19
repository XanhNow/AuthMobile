import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/models/security_models.dart';
import '../storage/auth_identity_store.dart';
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
    this.identity,
    this.userId,
    this.preferLogin = false,
  });

  const AuthSessionState.unknown() : this(status: AuthSessionStatus.unknown);
  const AuthSessionState.unauthenticated({bool preferLogin = false})
    : this(status: AuthSessionStatus.unauthenticated, preferLogin: preferLogin);
  const AuthSessionState.pendingRegistration(String userId)
    : this(status: AuthSessionStatus.pendingRegistration, userId: userId);
  factory AuthSessionState.authenticated(
    TokenPair tokens,
    AuthIdentity? identity,
  ) {
    return AuthSessionState(
      status: AuthSessionStatus.authenticated,
      tokens: tokens,
      identity: identity,
      userId: identity?.userId,
    );
  }

  final AuthSessionStatus status;
  final TokenPair? tokens;
  final AuthIdentity? identity;
  final String? userId;
  final bool preferLogin;

  @override
  List<Object?> get props => [status, tokens, identity, userId, preferLogin];
}

class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit({
    required SecureTokenStore tokenStore,
    required AuthIdentityStore identityStore,
  }) : _tokenStore = tokenStore,
       _identityStore = identityStore,
       super(const AuthSessionState.unknown());

  final SecureTokenStore _tokenStore;
  final AuthIdentityStore _identityStore;

  Future<void> restore() async {
    final tokens = await _tokenStore.read();
    final identity = await _identityStore.read();
    emit(
      tokens == null
          ? const AuthSessionState.unauthenticated()
          : AuthSessionState.authenticated(tokens, identity),
    );
  }

  Future<void> authenticate(TokenPair tokens, {AuthIdentity? identity}) async {
    await _tokenStore.save(tokens);
    if (identity != null) {
      await _identityStore.save(identity);
    }

    emit(
      AuthSessionState.authenticated(
        tokens,
        identity ?? await _identityStore.read(),
      ),
    );
  }

  void markPendingRegistration(String userId) {
    emit(AuthSessionState.pendingRegistration(userId));
  }

  Future<void> clear() async {
    await _tokenStore.clear();
    await _identityStore.clear();
    emit(const AuthSessionState.unauthenticated(preferLogin: true));
  }
}
