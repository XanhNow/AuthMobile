import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/auth_session_cubit.dart';
import '../../data/models/security_models.dart';
import '../../domain/auth_repository.dart';

enum LoginStep {
  idle,
  submittingPassword,
  creatingPasskeyAssertion,
  passkeyRequired,
  smartOtpRequired,
  revealingSmartOtp,
  verifyingSmartOtp,
  authenticated,
  failure,
}

class LoginState extends Equatable {
  const LoginState({
    required this.step,
    this.userId,
    this.identity,
    this.message,
    this.smartOtpChallenge,
  });

  const LoginState.initial() : this(step: LoginStep.idle);

  final LoginStep step;
  final String? userId;
  final AuthIdentity? identity;
  final String? message;
  final SmartOtpCodeChallenge? smartOtpChallenge;

  LoginState copyWith({
    LoginStep? step,
    String? userId,
    AuthIdentity? identity,
    String? message,
    SmartOtpCodeChallenge? smartOtpChallenge,
    bool clearSmartOtpChallenge = false,
  }) {
    return LoginState(
      step: step ?? this.step,
      userId: userId ?? this.userId,
      identity: identity ?? this.identity,
      message: message,
      smartOtpChallenge: clearSmartOtpChallenge
          ? null
          : smartOtpChallenge ?? this.smartOtpChallenge,
    );
  }

  @override
  List<Object?> get props => [
    step,
    userId,
    identity,
    message,
    smartOtpChallenge,
  ];
}

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class PasswordLoginSubmitted extends LoginEvent {
  const PasswordLoginSubmitted({
    required this.phoneNumber,
    required this.password,
  });

  final String phoneNumber;
  final String password;

  @override
  List<Object?> get props => [phoneNumber, password];
}

class PasskeyLoginSubmitted extends LoginEvent {
  const PasskeyLoginSubmitted({this.loginIdentifier});

  final String? loginIdentifier;

  @override
  List<Object?> get props => [loginIdentifier];
}

class RequiredRegistrationPasskeySubmitted extends LoginEvent {
  const RequiredRegistrationPasskeySubmitted({required this.displayName});

  final String displayName;

  @override
  List<Object?> get props => [displayName];
}

class LoginSmartOtpCodeRequested extends LoginEvent {
  const LoginSmartOtpCodeRequested();
}

class LoginSmartOtpCodeSubmitted extends LoginEvent {
  const LoginSmartOtpCodeSubmitted({required this.otp});

  final String otp;

  @override
  List<Object?> get props => [otp];
}

class LoginCancelled extends LoginEvent {
  const LoginCancelled();
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({
    required AuthRepository repository,
    required AuthSessionCubit sessionCubit,
  }) : _repository = repository,
       _sessionCubit = sessionCubit,
       super(const LoginState.initial()) {
    on<PasswordLoginSubmitted>(_onPasswordLogin);
    on<PasskeyLoginSubmitted>(_onPasskeyLogin);
    on<RequiredRegistrationPasskeySubmitted>(_onRequiredRegistrationPasskey);
    on<LoginSmartOtpCodeRequested>(_onLoginSmartOtpCodeRequested);
    on<LoginSmartOtpCodeSubmitted>(_onLoginSmartOtpCodeSubmitted);
    on<LoginCancelled>(_onLoginCancelled);
  }

  final AuthRepository _repository;
  final AuthSessionCubit _sessionCubit;

  void _onLoginCancelled(LoginCancelled event, Emitter<LoginState> emit) {
    emit(const LoginState.initial());
  }

  Future<void> _onPasswordLogin(
    PasswordLoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(step: LoginStep.submittingPassword));
    try {
      final result = await _repository.loginWithPassword(
        phoneNumber: event.phoneNumber,
        password: event.password,
      );
      if (result.isPasskeyRequired) {
        emit(
          state.copyWith(
            step: LoginStep.passkeyRequired,
            userId: result.userId,
            identity: result.identity,
            message: result.reasonCode ?? 'Passkey registration is required.',
          ),
        );
        return;
      }
      if (result.isMfaRequired) {
        emit(
          state.copyWith(
            step: LoginStep.smartOtpRequired,
            userId: result.userId,
            identity: result.identity,
            message: 'Vui lòng xác thực Smart OTP để hoàn tất đăng nhập.',
            clearSmartOtpChallenge: true,
          ),
        );
        return;
      }
      final tokens = result.tokens;
      if (result.isCompleted && tokens != null) {
        await _sessionCubit.authenticate(tokens, identity: result.identity);
        emit(
          state.copyWith(step: LoginStep.authenticated, userId: result.userId),
        );
        return;
      }
      emit(
        state.copyWith(
          step: LoginStep.failure,
          message: 'Unsupported login state: ${result.state}',
        ),
      );
    } catch (error) {
      emit(state.copyWith(step: LoginStep.failure, message: error.toString()));
    }
  }

  Future<void> _onPasskeyLogin(
    PasskeyLoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(step: LoginStep.creatingPasskeyAssertion));
    try {
      final result = await _repository.loginWithPasskey(
        loginIdentifier: event.loginIdentifier,
      );
      if (result.isMfaRequired) {
        emit(
          state.copyWith(
            step: LoginStep.smartOtpRequired,
            userId: result.userId,
            identity: result.identity,
            message: 'Vui lòng xác thực Smart OTP để hoàn tất đăng nhập.',
            clearSmartOtpChallenge: true,
          ),
        );
        return;
      }
      final tokens = result.tokens;
      if (result.isCompleted && tokens != null) {
        await _sessionCubit.authenticate(tokens, identity: result.identity);
        emit(
          state.copyWith(step: LoginStep.authenticated, userId: result.userId),
        );
        return;
      }
      emit(
        state.copyWith(
          step: LoginStep.failure,
          message: 'Unsupported passkey login state: ${result.state}',
        ),
      );
    } catch (error) {
      emit(state.copyWith(step: LoginStep.failure, message: error.toString()));
    }
  }

  Future<void> _onLoginSmartOtpCodeRequested(
    LoginSmartOtpCodeRequested event,
    Emitter<LoginState> emit,
  ) async {
    final userId = state.userId;
    if (userId == null || userId.isEmpty) {
      emit(
        state.copyWith(
          step: LoginStep.failure,
          message: 'Missing user for Smart OTP login.',
          clearSmartOtpChallenge: true,
        ),
      );
      return;
    }

    emit(state.copyWith(step: LoginStep.revealingSmartOtp, message: null));
    try {
      final challenge = await _repository.revealLoginSmartOtpCode(
        userId: userId,
      );
      emit(
        state.copyWith(
          step: LoginStep.smartOtpRequired,
          userId: userId,
          identity: state.identity,
          smartOtpChallenge: challenge,
          message: 'Mã Smart OTP đã được tạo. Nhập mã để hoàn tất đăng nhập.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: LoginStep.smartOtpRequired,
          userId: userId,
          message: error.toString(),
          clearSmartOtpChallenge: true,
        ),
      );
    }
  }

  Future<void> _onLoginSmartOtpCodeSubmitted(
    LoginSmartOtpCodeSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final userId = state.userId;
    final challenge = state.smartOtpChallenge;
    if (userId == null || userId.isEmpty || challenge == null) {
      emit(
        state.copyWith(
          step: LoginStep.smartOtpRequired,
          message: 'Vui lòng lấy mã Smart OTP trước.',
        ),
      );
      return;
    }

    emit(state.copyWith(step: LoginStep.verifyingSmartOtp, message: null));
    try {
      final result = await _repository.verifyLoginSmartOtpCode(
        userId: userId,
        challenge: challenge.challenge,
        otp: event.otp,
      );
      final tokens = result.tokens;
      if (result.isCompleted && tokens != null) {
        await _sessionCubit.authenticate(
          tokens,
          identity: result.identity ?? state.identity,
          notice: 'Xác thực Smart đã thành công.',
        );
        emit(
          state.copyWith(
            step: LoginStep.authenticated,
            userId: result.userId,
            clearSmartOtpChallenge: true,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          step: LoginStep.smartOtpRequired,
          userId: userId,
          message: 'Smart OTP chưa hoàn tất đăng nhập.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: LoginStep.smartOtpRequired,
          userId: userId,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onRequiredRegistrationPasskey(
    RequiredRegistrationPasskeySubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final userId = state.userId;
    if (userId == null || userId.isEmpty) {
      emit(
        state.copyWith(
          step: LoginStep.failure,
          message: 'Missing pending registration user.',
        ),
      );
      return;
    }

    emit(state.copyWith(step: LoginStep.creatingPasskeyAssertion));
    try {
      final result = await _repository.completeMandatoryPasskey(
        userId: userId,
        displayName: event.displayName,
      );
      emit(
        state.copyWith(
          step: LoginStep.passkeyRequired,
          userId: userId,
          message: 'Registration ${result.registrationStatus}. Please log in.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: LoginStep.passkeyRequired,
          userId: userId,
          message: error.toString(),
        ),
      );
    }
  }
}
