import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/auth_session_cubit.dart';
import '../../data/models/security_models.dart';
import '../../domain/auth_repository.dart';

enum RegistrationStep {
  idle,
  submittingPassword,
  pendingPasskey,
  creatingPasskey,
  completed,
  enrollingSmartOtp,
  smartOtpVerificationRequired,
  revealingSmartOtp,
  verifyingSmartOtp,
  failure,
}

class RegistrationState extends Equatable {
  const RegistrationState({
    required this.step,
    this.phoneNumber,
    this.userId,
    this.displayName,
    this.tokens,
    this.identity,
    this.smartOtpChallenge,
    this.message,
  });

  const RegistrationState.initial() : this(step: RegistrationStep.idle);

  final RegistrationStep step;
  final String? phoneNumber;
  final String? userId;
  final String? displayName;
  final TokenPair? tokens;
  final AuthIdentity? identity;
  final SmartOtpCodeChallenge? smartOtpChallenge;
  final String? message;

  RegistrationState copyWith({
    RegistrationStep? step,
    String? phoneNumber,
    String? userId,
    String? displayName,
    TokenPair? tokens,
    AuthIdentity? identity,
    SmartOtpCodeChallenge? smartOtpChallenge,
    bool clearSmartOtpChallenge = false,
    String? message,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      tokens: tokens ?? this.tokens,
      identity: identity ?? this.identity,
      smartOtpChallenge: clearSmartOtpChallenge
          ? null
          : smartOtpChallenge ?? this.smartOtpChallenge,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    step,
    phoneNumber,
    userId,
    displayName,
    tokens,
    identity,
    smartOtpChallenge,
    message,
  ];
}

sealed class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object?> get props => [];
}

class RegistrationPasswordSubmitted extends RegistrationEvent {
  const RegistrationPasswordSubmitted({
    required this.phoneNumber,
    required this.password,
    required this.displayName,
  });

  final String phoneNumber;
  final String password;
  final String displayName;

  @override
  List<Object?> get props => [phoneNumber, password, displayName];
}

class RegistrationPasskeyStarted extends RegistrationEvent {
  const RegistrationPasskeyStarted();
}

class RegistrationSmartOtpSkipped extends RegistrationEvent {
  const RegistrationSmartOtpSkipped();
}

class RegistrationSmartOtpCancelled extends RegistrationEvent {
  const RegistrationSmartOtpCancelled();
}

class RegistrationSmartOtpEnrollmentStarted extends RegistrationEvent {
  const RegistrationSmartOtpEnrollmentStarted();
}

class RegistrationSmartOtpCodeRequested extends RegistrationEvent {
  const RegistrationSmartOtpCodeRequested();
}

class RegistrationSmartOtpCodeSubmitted extends RegistrationEvent {
  const RegistrationSmartOtpCodeSubmitted({required this.otp});

  final String otp;

  @override
  List<Object?> get props => [otp];
}

class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  RegistrationBloc({
    required AuthRepository repository,
    required AuthSessionCubit sessionCubit,
  }) : _repository = repository,
       _sessionCubit = sessionCubit,
       super(const RegistrationState.initial()) {
    on<RegistrationPasswordSubmitted>(_onPasswordSubmitted);
    on<RegistrationPasskeyStarted>(_onPasskeyStarted);
    on<RegistrationSmartOtpEnrollmentStarted>(_onSmartOtpEnrollmentStarted);
    on<RegistrationSmartOtpCodeRequested>(_onSmartOtpCodeRequested);
    on<RegistrationSmartOtpCodeSubmitted>(_onSmartOtpCodeSubmitted);
    on<RegistrationSmartOtpSkipped>(_onSmartOtpSkipped);
    on<RegistrationSmartOtpCancelled>(_onSmartOtpCancelled);
  }

  final AuthRepository _repository;
  final AuthSessionCubit _sessionCubit;
  String? _registrationPassword;

  Future<void> _onPasswordSubmitted(
    RegistrationPasswordSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    _registrationPassword = event.password;
    emit(
      state.copyWith(
        step: RegistrationStep.submittingPassword,
        phoneNumber: event.phoneNumber,
        displayName: event.displayName,
      ),
    );
    try {
      final result = await _repository.registerWithPassword(
        phoneNumber: event.phoneNumber,
        password: event.password,
        displayName: event.displayName,
      );
      _sessionCubit.markPendingRegistration(result.userId);
      emit(
        state.copyWith(
          step: RegistrationStep.pendingPasskey,
          userId: result.userId,
          identity: result.identity,
          message: 'Password accepted. Passkey registration is required.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: RegistrationStep.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onPasskeyStarted(
    RegistrationPasskeyStarted event,
    Emitter<RegistrationState> emit,
  ) async {
    final userId = state.userId;
    final displayName = state.displayName;
    final phoneNumber = state.phoneNumber;
    final password = _registrationPassword;
    if (userId == null || displayName == null) {
      emit(
        state.copyWith(
          step: RegistrationStep.failure,
          message: 'Missing pending registration.',
        ),
      );
      return;
    }

    emit(state.copyWith(step: RegistrationStep.creatingPasskey));
    try {
      final result = await _repository.completeMandatoryPasskey(
        userId: userId,
        displayName: displayName,
      );
      TokenPair? tokens;
      AuthIdentity? identity = state.identity;
      if (phoneNumber != null && password != null) {
        final login = await _repository.loginWithPassword(
          phoneNumber: phoneNumber,
          password: password,
        );
        tokens = login.tokens;
        identity = login.identity ?? identity;
      }
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          tokens: tokens,
          identity: identity,
          message: tokens == null
              ? 'Registration ${result.registrationStatus}. Please log in.'
              : 'Passkey đã hoàn tất. Chọn Xác Thực Smart hoặc Bỏ qua.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: RegistrationStep.failure,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSmartOtpSkipped(
    RegistrationSmartOtpSkipped event,
    Emitter<RegistrationState> emit,
  ) async {
    final tokens = state.tokens;
    if (tokens == null) {
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          message: 'Missing session. Please log in.',
        ),
      );
      return;
    }

    await _sessionCubit.authenticate(tokens, identity: state.identity);
  }

  Future<void> _onSmartOtpCancelled(
    RegistrationSmartOtpCancelled event,
    Emitter<RegistrationState> emit,
  ) async {
    final tokens = state.tokens;
    if (tokens == null) {
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          message: 'Missing session. Please log in.',
        ),
      );
      return;
    }

    await _sessionCubit.authenticate(
      tokens,
      identity: state.identity,
      notice: 'Đăng ký thành công.',
    );
  }

  Future<void> _onSmartOtpEnrollmentStarted(
    RegistrationSmartOtpEnrollmentStarted event,
    Emitter<RegistrationState> emit,
  ) async {
    final userId = state.userId;
    final tokens = state.tokens;
    if (userId == null || tokens == null) {
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          message: 'Missing session. Please log in.',
        ),
      );
      return;
    }

    emit(state.copyWith(step: RegistrationStep.enrollingSmartOtp));
    try {
      final result = await _repository.enrollSmartOtpDevice(
        userId: userId,
        authorizationTokens: tokens,
      );
      if (result.isEnabled) {
        emit(
          state.copyWith(
            step: RegistrationStep.smartOtpVerificationRequired,
            message:
                'Smart OTP đã được thiết lập. Vui lòng lấy mã và xác thực để hoàn tất đăng nhập.',
            clearSmartOtpChallenge: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          message: 'Smart OTP device status: ${result.status}.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSmartOtpCodeRequested(
    RegistrationSmartOtpCodeRequested event,
    Emitter<RegistrationState> emit,
  ) async {
    final userId = state.userId;
    if (userId == null || userId.isEmpty) {
      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          message: 'Missing user for Smart OTP verification.',
          clearSmartOtpChallenge: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        step: RegistrationStep.revealingSmartOtp,
        message: null,
        clearSmartOtpChallenge: true,
      ),
    );
    try {
      final challenge = await _repository.revealLoginSmartOtpCode(
        userId: userId,
      );
      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          smartOtpChallenge: challenge,
          message: 'Mã Smart OTP đã được tạo. Nhập mã để hoàn tất đăng nhập.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          message: error.toString(),
          clearSmartOtpChallenge: true,
        ),
      );
    }
  }

  Future<void> _onSmartOtpCodeSubmitted(
    RegistrationSmartOtpCodeSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    final userId = state.userId;
    final challenge = state.smartOtpChallenge;
    if (userId == null || userId.isEmpty || challenge == null) {
      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          message: 'Vui lòng lấy mã Smart OTP trước.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(step: RegistrationStep.verifyingSmartOtp, message: null),
    );
    try {
      final result = await _repository.verifyLoginSmartOtpCode(
        userId: userId,
        challenge: challenge.challenge,
        otp: event.otp,
      );
      final tokens = result.tokens;
      if (result.isCompleted && tokens != null) {
        final identity = result.identity ?? state.identity;
        await _sessionCubit.authenticate(
          tokens,
          identity: identity,
          notice: 'Xác thực Smart đã thành công.',
        );
        emit(
          state.copyWith(
            step: RegistrationStep.completed,
            tokens: tokens,
            identity: identity,
            clearSmartOtpChallenge: true,
            message: 'Xác thực Smart đã thành công.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          message: 'Smart OTP chưa hoàn tất đăng nhập.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          step: RegistrationStep.smartOtpVerificationRequired,
          message: error.toString(),
        ),
      );
    }
  }
}
