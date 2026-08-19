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
  failure,
}

class RegistrationState extends Equatable {
  const RegistrationState({
    required this.step,
    this.phoneNumber,
    this.userId,
    this.displayName,
    this.tokens,
    this.message,
  });

  const RegistrationState.initial() : this(step: RegistrationStep.idle);

  final RegistrationStep step;
  final String? phoneNumber;
  final String? userId;
  final String? displayName;
  final TokenPair? tokens;
  final String? message;

  RegistrationState copyWith({
    RegistrationStep? step,
    String? phoneNumber,
    String? userId,
    String? displayName,
    TokenPair? tokens,
    String? message,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      tokens: tokens ?? this.tokens,
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

class RegistrationSmartOtpEnrollmentStarted extends RegistrationEvent {
  const RegistrationSmartOtpEnrollmentStarted();
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
    on<RegistrationSmartOtpSkipped>(_onSmartOtpSkipped);
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
      if (phoneNumber != null && password != null) {
        final login = await _repository.loginWithPassword(
          phoneNumber: phoneNumber,
          password: password,
        );
        tokens = login.tokens;
      }
      emit(
        state.copyWith(
          step: RegistrationStep.completed,
          tokens: tokens,
          message: tokens == null
              ? 'Registration ${result.registrationStatus}. Please log in.'
              : 'Registration ${result.registrationStatus}.',
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

    await _sessionCubit.authenticate(tokens);
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
      final result = await _repository.enrollSmartOtpDevice(userId: userId);
      if (result.isEnabled) {
        await _sessionCubit.authenticate(tokens);
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
}
