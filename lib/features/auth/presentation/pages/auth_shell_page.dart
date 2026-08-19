import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/home_page.dart';
import '../../../../core/session/auth_session_cubit.dart';
import '../../../../core/validation/phone_number_normalizer.dart';
import '../../domain/auth_repository.dart';
import '../bloc/login_bloc.dart';
import '../bloc/registration_bloc.dart';

class AuthShellPage extends StatefulWidget {
  const AuthShellPage({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  State<AuthShellPage> createState() => _AuthShellPageState();
}

class _AuthShellPageState extends State<AuthShellPage> {
  late int _index;
  _AuthLanguage _language = _AuthLanguage.vi;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final text = _AuthText(_language);
    return Scaffold(
      appBar: AppBar(
        title: const Text('XanhNow Auth'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<_AuthLanguage>(
              segments: const [
                ButtonSegment(value: _AuthLanguage.vi, label: Text('VI')),
                ButtonSegment(value: _AuthLanguage.en, label: Text('EN')),
              ],
              selected: {_language},
              onSelectionChanged: (selected) {
                setState(() => _language = selected.single);
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          _RegisterView(text: text),
          _LoginView(text: text),
          _AccountView(text: text),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            selectedIcon: const Icon(Icons.person_add_alt_1),
            label: text.registerTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.login_outlined),
            selectedIcon: const Icon(Icons.login),
            label: text.loginTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.verified_user_outlined),
            selectedIcon: const Icon(Icons.verified_user),
            label: text.accountTab,
          ),
        ],
      ),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView({required this.text});

  final _AuthText text;

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _displayName = TextEditingController(text: 'XanhNow Mobile User');
  final _registrationSmartOtpCode = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _showSmartOtpEnrollment = false;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _displayNameError;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_refreshRegistrationForm);
    _password.addListener(_refreshRegistrationForm);
    _confirmPassword.addListener(_refreshRegistrationForm);
    _displayName.addListener(_refreshRegistrationForm);
    _registrationSmartOtpCode.addListener(_refreshRegistrationForm);
  }

  void _refreshRegistrationForm() {
    if (!mounted) {
      return;
    }
    setState(() {
      _phoneError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _displayNameError = null;
    });
  }

  bool get _canSubmitPasswordRegistration =>
      _registrationValidationErrors(updateFields: false).isEmpty;

  bool _hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);

  bool _hasDigit(String value) => RegExp(r'\d').hasMatch(value);

  bool _hasSpecialCharacter(String value) =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  void _resetRegistrationForm() {
    _phone.clear();
    _password.clear();
    _confirmPassword.clear();
    _displayName.clear();
    setState(() {
      _phoneError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _displayNameError = null;
      _showPassword = false;
      _showConfirmPassword = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  void dispose() {
    _phone.removeListener(_refreshRegistrationForm);
    _password.removeListener(_refreshRegistrationForm);
    _confirmPassword.removeListener(_refreshRegistrationForm);
    _displayName.removeListener(_refreshRegistrationForm);
    _registrationSmartOtpCode.removeListener(_refreshRegistrationForm);
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _displayName.dispose();
    _registrationSmartOtpCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegistrationBloc, RegistrationState>(
      listener: (context, state) {
        if (state.step == RegistrationStep.enrollingSmartOtp ||
            state.step == RegistrationStep.smartOtpVerificationRequired ||
            state.step == RegistrationStep.revealingSmartOtp ||
            state.step == RegistrationStep.verifyingSmartOtp) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        if (state.step == RegistrationStep.completed &&
            context.read<AuthSessionCubit>().state.status ==
                AuthSessionStatus.authenticated) {
          _goHome(context);
          return;
        }

        final message = state.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        final busy =
            state.step == RegistrationStep.submittingPassword ||
            state.step == RegistrationStep.creatingPasskey ||
            state.step == RegistrationStep.enrollingSmartOtp ||
            state.step == RegistrationStep.revealingSmartOtp ||
            state.step == RegistrationStep.verifyingSmartOtp;
        final showPasswordActions =
            state.step == RegistrationStep.idle ||
            state.step == RegistrationStep.submittingPassword ||
            (state.step == RegistrationStep.failure && state.userId == null);
        final canSubmitPassword =
            showPasswordActions && !busy && _canSubmitPasswordRegistration;
        final showPasskeyButton =
            state.step == RegistrationStep.pendingPasskey ||
            state.step == RegistrationStep.creatingPasskey ||
            (state.step == RegistrationStep.failure && state.userId != null);
        final showSmartOtpOptions = state.step == RegistrationStep.completed;
        if (_showSmartOtpEnrollment) {
          final smartOtpVerification =
              state.step == RegistrationStep.smartOtpVerificationRequired ||
              state.step == RegistrationStep.revealingSmartOtp ||
              state.step == RegistrationStep.verifyingSmartOtp;
          final registrationChallenge = state.smartOtpChallenge;
          final registrationOtp = registrationChallenge?.reveal.otpCode;
          final canVerifyRegistrationOtp =
              registrationChallenge != null &&
              _registrationSmartOtpCode.text.trim().isNotEmpty &&
              !busy;
          return _PagePadding(
            child: ListView(
              children: [
                _SectionTitle(widget.text.smartOtpTitle),
                Text(
                  widget.text.smartOtpDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (state.userId != null)
                  _StateChip(label: widget.text.userId, value: state.userId!),
                const SizedBox(height: 12),
                _SmartOtpSetupStep(
                  icon: Icons.key_outlined,
                  title: widget.text.smartOtpStepCreateKey,
                  description: widget.text.smartOtpStepCreateKeyDescription,
                ),
                _SmartOtpSetupStep(
                  icon: Icons.public_outlined,
                  title: widget.text.smartOtpStepRegisterPublicKey,
                  description:
                      widget.text.smartOtpStepRegisterPublicKeyDescription,
                ),
                _SmartOtpSetupStep(
                  icon: Icons.verified_user_outlined,
                  title: widget.text.smartOtpStepSignChallenge,
                  description: widget.text.smartOtpStepSignChallengeDescription,
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.text.smartOtpImplementationNote),
                  ),
                ),
                const SizedBox(height: 20),
                if (!smartOtpVerification) ...[
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => context.read<RegistrationBloc>().add(
                            const RegistrationSmartOtpEnrollmentStarted(),
                          ),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      busy
                          ? widget.text.enrollingSmartOtp
                          : widget.text.startSmartOtpSetup,
                    ),
                  ),
                ] else ...[
                  Text(
                    widget.text.registrationSmartOtpGateDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (registrationOtp != null &&
                      registrationOtp.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      registrationOtp,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _registrationSmartOtpCode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: widget.text.smartOtpCode,
                        helperText: widget.text.smartOtpCodeHint,
                        prefixIcon: const Icon(Icons.password_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            _registrationSmartOtpCode.clear();
                            context.read<RegistrationBloc>().add(
                              const RegistrationSmartOtpCodeRequested(),
                            );
                          },
                    icon: const Icon(Icons.password_outlined),
                    label: Text(
                      state.step == RegistrationStep.revealingSmartOtp
                          ? widget.text.gettingSmartOtpCode
                          : widget.text.getSmartOtpCode,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: canVerifyRegistrationOtp
                        ? () => context.read<RegistrationBloc>().add(
                            RegistrationSmartOtpCodeSubmitted(
                              otp: _registrationSmartOtpCode.text.trim(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(
                      state.step == RegistrationStep.verifyingSmartOtp
                          ? widget.text.verifyingSmartOtpCode
                          : widget.text.verifySmartOtpCode,
                    ),
                  ),
                ],
                if (state.message != null && state.message!.isNotEmpty)
                  _ErrorPanel(message: state.message!),
              ],
            ),
          );
        }
        return _PagePadding(
          child: ListView(
            children: [
              _SectionTitle(widget.text.registerTitle),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,

                decoration: InputDecoration(
                  labelText: widget.text.phoneNumber,
                  errorText: _phoneError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: !_showPassword,

                decoration: InputDecoration(
                  labelText: widget.text.password,
                  helperText: widget.text.passwordMinLengthHint,
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    tooltip: widget.text.togglePasswordVisibility,
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassword,
                obscureText: !_showConfirmPassword,

                decoration: InputDecoration(
                  labelText: widget.text.confirmPassword,
                  helperText: widget.text.passwordMinLengthHint,
                  errorText: _confirmPasswordError,
                  suffixIcon: IconButton(
                    tooltip: widget.text.togglePasswordVisibility,
                    onPressed: () {
                      setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      );
                    },
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayName,

                decoration: InputDecoration(
                  labelText: widget.text.displayName,
                  errorText: _displayNameError,
                ),
              ),
              const SizedBox(height: 20),
              if (showPasswordActions) ...[
                Opacity(
                  opacity: canSubmitPassword ? 1 : 0.45,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            final validation = _validateRegistration();
                            if (validation == null) {
                              return;
                            }
                            context.read<RegistrationBloc>().add(
                              RegistrationPasswordSubmitted(
                                phoneNumber: validation.normalizedPhone,
                                password: _password.text,
                                displayName: _displayName.text.trim(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      state.step == RegistrationStep.submittingPassword
                          ? widget.text.creatingAccount
                          : widget.text.createPasswordAccount,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : _resetRegistrationForm,
                  icon: const Icon(Icons.refresh),
                  label: Text(widget.text.resetForm),
                ),
              ],
              if (showPasskeyButton) ...[
                FilledButton.tonalIcon(
                  onPressed:
                      state.step == RegistrationStep.pendingPasskey ||
                          (state.step == RegistrationStep.failure &&
                              state.userId != null)
                      ? () => context.read<RegistrationBloc>().add(
                          const RegistrationPasskeyStarted(),
                        )
                      : null,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    state.step == RegistrationStep.creatingPasskey
                        ? widget.text.creatingPasskey
                        : widget.text.registerRequiredPasskey,
                  ),
                ),
              ],
              if (showSmartOtpOptions) ...[
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _showSmartOtpEnrollment = true;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(widget.text.smartOtpVerification),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.read<RegistrationBloc>().add(
                    const RegistrationSmartOtpSkipped(),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(widget.text.skipToHome),
                ),
              ],
              const SizedBox(height: 20),
              if (state.step != RegistrationStep.idle)
                _StateChip(label: widget.text.state, value: state.step.name),
              if (state.userId != null)
                _StateChip(label: widget.text.userId, value: state.userId!),
              if (state.step == RegistrationStep.failure &&
                  state.message != null &&
                  state.message!.isNotEmpty)
                _ErrorPanel(message: state.message!),
            ],
          ),
        );
      },
    );
  }

  _ValidatedPhone? _validateRegistration() {
    final errors = _registrationValidationErrors(updateFields: true);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.text.fixFormErrors}\n${errors.join('\n')}'),
          duration: const Duration(seconds: 5),
        ),
      );
      return null;
    }

    final normalizedPhone = PhoneNumberNormalizer.normalizeVietnamesePhone(
      _phone.text,
    );
    setState(() => _phone.text = normalizedPhone);
    return _ValidatedPhone(normalizedPhone);
  }

  List<String> _registrationValidationErrors({required bool updateFields}) {
    String? phoneError;
    String? passwordError;
    String? confirmPasswordError;
    String? displayNameError;
    final errors = <String>[];

    try {
      PhoneNumberNormalizer.normalizeVietnamesePhone(_phone.text);
    } catch (_) {
      phoneError = _phone.text.trim().isEmpty
          ? widget.text.phoneRequired
          : widget.text.phoneInvalid;
      errors.add(phoneError);
    }

    final password = _password.text;
    final passwordRules = <String>[];
    if (password.isEmpty) {
      passwordError = widget.text.passwordRequired;
      errors.add(passwordError);
    } else {
      if (password.length < 12) {
        passwordRules.add(widget.text.passwordRuleMinLength);
      }
      if (!_hasUppercase(password)) {
        passwordRules.add(widget.text.passwordRuleUppercase);
      }
      if (!_hasDigit(password)) {
        passwordRules.add(widget.text.passwordRuleDigit);
      }
      if (!_hasSpecialCharacter(password)) {
        passwordRules.add(widget.text.passwordRuleSpecial);
      }
      if (passwordRules.isNotEmpty) {
        passwordError = passwordRules.join('\n');
        errors.addAll(passwordRules);
      }
    }

    if (_confirmPassword.text.isEmpty) {
      confirmPasswordError = widget.text.confirmPasswordRequired;
      errors.add(confirmPasswordError);
    } else if (password != _confirmPassword.text) {
      confirmPasswordError = widget.text.passwordMismatch;
      errors.add(confirmPasswordError);
    }

    if (_displayName.text.trim().isEmpty) {
      displayNameError = widget.text.displayNameRequired;
      errors.add(displayNameError);
    }

    if (updateFields) {
      setState(() {
        _phoneError = phoneError;
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
        _displayNameError = displayNameError;
      });
    }

    return errors;
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.text});

  final _AuthText text;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _smartOtpCode = TextEditingController();
  bool _showPassword = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_refreshLoginForm);
    _password.addListener(_refreshLoginForm);
    _smartOtpCode.addListener(_refreshLoginForm);
  }

  void _refreshLoginForm() {
    if (!mounted) {
      return;
    }
    setState(() {
      _phoneError = null;
      _passwordError = null;
    });
  }

  bool get _canSubmitPasswordLogin =>
      _passwordLoginValidationErrors(updateFields: false).isEmpty;

  bool _hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);

  bool _hasDigit(String value) => RegExp(r'\d').hasMatch(value);

  bool _hasSpecialCharacter(String value) =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  void _resetLoginForm() {
    _phone.clear();
    _password.clear();
    setState(() {
      _phoneError = null;
      _passwordError = null;
      _showPassword = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  void dispose() {
    _phone.removeListener(_refreshLoginForm);
    _password.removeListener(_refreshLoginForm);
    _smartOtpCode.removeListener(_refreshLoginForm);
    _phone.dispose();
    _password.dispose();
    _smartOtpCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state.step == LoginStep.authenticated) {
          _goHome(context);
          return;
        }

        final message = state.message;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        final busy =
            state.step == LoginStep.submittingPassword ||
            state.step == LoginStep.creatingPasskeyAssertion ||
            state.step == LoginStep.revealingSmartOtp ||
            state.step == LoginStep.verifyingSmartOtp;
        final smartOtpLogin =
            state.step == LoginStep.smartOtpRequired ||
            state.step == LoginStep.revealingSmartOtp ||
            state.step == LoginStep.verifyingSmartOtp;
        final canSubmitPassword = !busy && _canSubmitPasswordLogin;
        if (smartOtpLogin) {
          return _PagePadding(
            child: ListView(
              children: [
                _SectionTitle(widget.text.loginSmartOtpTitle),
                Text(widget.text.loginSmartOtpDescription),
                const SizedBox(height: 16),
                if (state.userId != null)
                  _StateChip(label: widget.text.userId, value: state.userId!),
                const SizedBox(height: 12),
                if (state.smartOtpChallenge != null)
                  TextField(
                    controller: _smartOtpCode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.text.smartOtpCode,
                      helperText: widget.text.smartOtpCodeHint,
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          _smartOtpCode.clear();
                          context.read<LoginBloc>().add(
                            const LoginSmartOtpCodeRequested(),
                          );
                        },
                  icon: const Icon(Icons.password),
                  label: Text(
                    state.step == LoginStep.revealingSmartOtp
                        ? widget.text.gettingSmartOtpCode
                        : widget.text.getSmartOtpCode,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed:
                      busy ||
                          state.smartOtpChallenge == null ||
                          _smartOtpCode.text.trim().isEmpty
                      ? null
                      : () => context.read<LoginBloc>().add(
                          LoginSmartOtpCodeSubmitted(
                            otp: _smartOtpCode.text.trim(),
                          ),
                        ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    state.step == LoginStep.verifyingSmartOtp
                        ? widget.text.verifyingSmartOtpCode
                        : widget.text.verifySmartOtpCode,
                  ),
                ),
                const SizedBox(height: 20),
                if (state.message != null && state.message!.isNotEmpty)
                  _ErrorPanel(message: state.message!),
              ],
            ),
          );
        }
        return _PagePadding(
          child: ListView(
            children: [
              _SectionTitle(widget.text.loginTitle),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,

                decoration: InputDecoration(
                  labelText: widget.text.phoneNumber,
                  errorText: _phoneError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                onChanged: (_) => setState(() => _passwordError = null),
                decoration: InputDecoration(
                  labelText: widget.text.password,
                  helperText: widget.text.passwordMinLengthHint,
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    tooltip: widget.text.togglePasswordVisibility,
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: canSubmitPassword ? 1 : 0.45,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          final validation = _validatePasswordLogin();
                          if (validation == null) {
                            return;
                          }
                          context.read<LoginBloc>().add(
                            PasswordLoginSubmitted(
                              phoneNumber: validation.normalizedPhone,
                              password: _password.text,
                            ),
                          );
                        },
                  icon: const Icon(Icons.password),
                  label: Text(widget.text.loginWithPassword),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _resetLoginForm,
                icon: const Icon(Icons.refresh),
                label: Text(widget.text.resetForm),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () {
                        final input = _phone.text.trim();
                        String? normalizedPhone;
                        if (input.isNotEmpty) {
                          try {
                            normalizedPhone =
                                PhoneNumberNormalizer.normalizeVietnamesePhone(
                                  input,
                                );
                            setState(() {
                              _phone.text = normalizedPhone!;
                              _phoneError = null;
                            });
                          } catch (_) {
                            setState(
                              () => _phoneError = widget.text.phoneInvalid,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(widget.text.fixFormErrors),
                              ),
                            );
                            return;
                          }
                        }
                        context.read<LoginBloc>().add(
                          PasskeyLoginSubmitted(
                            loginIdentifier: normalizedPhone,
                          ),
                        );
                      },
                icon: const Icon(Icons.fingerprint),
                label: Text(widget.text.loginWithPasskey),
              ),
              if (state.step == LoginStep.passkeyRequired) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: busy
                      ? null
                      : () => context.read<LoginBloc>().add(
                          RequiredRegistrationPasskeySubmitted(
                            displayName: widget.text.defaultPasskeyDisplayName,
                          ),
                        ),
                  icon: const Icon(Icons.fingerprint),
                  label: Text(widget.text.completeRequiredPasskey),
                ),
              ],
              const SizedBox(height: 20),
              if (state.step != LoginStep.idle)
                _StateChip(label: widget.text.state, value: state.step.name),
              if (state.userId != null)
                _StateChip(label: widget.text.userId, value: state.userId!),
              if (state.message != null && state.message!.isNotEmpty)
                _ErrorPanel(message: state.message!),
            ],
          ),
        );
      },
    );
  }

  _ValidatedPhone? _validatePasswordLogin() {
    final errors = _passwordLoginValidationErrors(updateFields: true);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_authFormSnackBar(widget.text.invalidLoginInformation));
      return null;
    }

    final normalizedPhone = PhoneNumberNormalizer.normalizeVietnamesePhone(
      _phone.text,
    );
    setState(() => _phone.text = normalizedPhone);
    return _ValidatedPhone(normalizedPhone);
  }

  List<String> _passwordLoginValidationErrors({required bool updateFields}) {
    String? phoneError;
    String? passwordError;
    final errors = <String>[];

    try {
      PhoneNumberNormalizer.normalizeVietnamesePhone(_phone.text);
    } catch (_) {
      phoneError = _phone.text.trim().isEmpty
          ? widget.text.phoneRequired
          : widget.text.phoneInvalid;
      errors.add(phoneError);
    }

    final password = _password.text;
    final passwordRules = <String>[];
    if (password.isEmpty) {
      passwordError = widget.text.passwordRequired;
      errors.add(passwordError);
    } else {
      if (password.length < 12) {
        passwordRules.add(widget.text.passwordRuleMinLength);
      }
      if (!_hasUppercase(password)) {
        passwordRules.add(widget.text.passwordRuleUppercase);
      }
      if (!_hasDigit(password)) {
        passwordRules.add(widget.text.passwordRuleDigit);
      }
      if (!_hasSpecialCharacter(password)) {
        passwordRules.add(widget.text.passwordRuleSpecial);
      }
      if (passwordRules.isNotEmpty) {
        passwordError = passwordRules.join('\n');
        errors.addAll(passwordRules);
      }
    }

    if (updateFields) {
      setState(() {
        _phoneError = phoneError;
        _passwordError = passwordError;
      });
    }

    return errors;
  }
}

class _ValidatedPhone {
  const _ValidatedPhone(this.normalizedPhone);

  final String normalizedPhone;
}

void _goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const HomePage()),
    (_) => false,
  );
}

SnackBar _authFormSnackBar(String message) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFFE6F4F1),
    duration: const Duration(seconds: 5),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    content: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF0B2F4A),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AccountView extends StatelessWidget {
  const _AccountView({required this.text});

  final _AuthText text;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionCubit, AuthSessionState>(
      builder: (context, state) {
        return _PagePadding(
          child: ListView(
            children: [
              _SectionTitle(text.currentSession),
              _StateChip(label: text.session, value: state.status.name),
              if (state.tokens?.sessionId != null)
                _StateChip(
                  label: text.sessionId,
                  value: state.tokens!.sessionId!,
                ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: state.status == AuthSessionStatus.authenticated
                    ? () async {
                        final profile = await context
                            .read<AuthRepository>()
                            .securityProfile();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Profile ${profile.status}, passkey=${profile.hasPasskey}',
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(text.loadSecurityProfile),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.status == AuthSessionStatus.authenticated
                    ? () async {
                        await context.read<AuthRepository>().logoutAll();
                        if (!context.mounted) return;
                        await context.read<AuthSessionCubit>().clear();
                      }
                    : null,
                icon: const Icon(Icons.logout),
                label: Text(text.logoutAllSessions),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PagePadding extends StatelessWidget {
  const _PagePadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _SmartOtpSetupStep extends StatelessWidget {
  const _SmartOtpSetupStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(description),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputChip(
        avatar: const Icon(Icons.info_outline),
        label: Text('$label: $value'),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AuthLanguage { vi, en }

class _AuthText {
  const _AuthText(this.language);

  final _AuthLanguage language;

  bool get _vi => language == _AuthLanguage.vi;

  String get registerTab => _vi ? 'Đăng ký' : 'Register';
  String get loginTab => _vi ? 'Đăng nhập' : 'Login';
  String get accountTab => _vi ? 'Tài khoản' : 'Account';
  String get registerTitle =>
      _vi ? 'Đăng ký bằng mật khẩu trước' : 'Register with password first';
  String get loginTitle => _vi
      ? 'Đăng nhập sau khi hoàn tất đăng ký'
      : 'Login after registration is completed';
  String get phoneNumber => _vi ? 'Số điện thoại' : 'Phone number';
  String get password => _vi ? 'Mật khẩu' : 'Password';
  String get confirmPassword => _vi ? 'Nhập lại mật khẩu' : 'Confirm password';
  String get passwordMinLengthHint => _vi
      ? 'Tối thiểu 12 ký tự, có chữ in hoa, số và ký tự đặc biệt.'
      : 'Minimum 12 characters with uppercase, number, and special character.';
  String get displayName => _vi ? 'Tên hiển thị' : 'Display name';
  String get phoneRequired =>
      _vi ? 'Vui lòng nhập số điện thoại.' : 'Phone number is required.';
  String get phoneInvalid => _vi
      ? 'Số điện thoại phải là số di động Việt Nam hợp lệ.'
      : 'Phone number must be a valid Vietnamese mobile number.';
  String get passwordRequired =>
      _vi ? 'Vui lòng nhập mật khẩu.' : 'Password is required.';
  String get confirmPasswordRequired =>
      _vi ? 'Vui lòng nhập lại mật khẩu.' : 'Please confirm your password.';
  String get displayNameRequired =>
      _vi ? 'Vui lòng nhập tên hiển thị.' : 'Display name is required.';
  String get fixFormErrors => _vi
      ? 'Vui lòng kiểm tra lại các thông tin bị báo lỗi.'
      : 'Please fix the highlighted fields.';
  String get invalidLoginInformation =>
      _vi ? 'Thông tin đăng nhập không hợp lệ' : 'Login information is invalid';
  String get createPasswordAccount =>
      _vi ? 'Tạo tài khoản bằng mật khẩu' : 'Create password account';
  String get registerRequiredPasskey =>
      _vi ? 'Đăng ký passkey bắt buộc' : 'Register required passkey';
  String get completeRequiredPasskey =>
      _vi ? 'Hoàn tất đăng ký passkey' : 'Complete required passkey';
  String get smartOtpVerification =>
      _vi ? 'Xác Thực Smart' : 'Smart Verification';
  String get skipToHome => _vi ? 'Bỏ qua và vào Home' : 'Skip and go Home';
  String get smartOtpTitle => _vi ? 'Thiết lập Smart OTP' : 'Set up Smart OTP';
  String get smartOtpDescription => _vi
      ? 'Smart OTP sẽ gắn thiết bị này với tài khoản bằng khóa bảo mật riêng của máy. Khóa riêng không gửi lên server.'
      : 'Smart OTP binds this device to the account with a private device key. The private key is never sent to the server.';
  String get smartOtpStepCreateKey => _vi
      ? 'Tạo khóa Smart OTP trên thiết bị'
      : 'Create a Smart OTP device key';
  String get smartOtpStepCreateKeyDescription => _vi
      ? 'App tạo khóa ký riêng cho thiết bị và lưu trong vùng an toàn của máy.'
      : 'The app creates a signing key for this device and stores it securely on the device.';
  String get smartOtpStepRegisterPublicKey =>
      _vi ? 'Gửi public key đến Security API' : 'Register the public key';
  String get smartOtpStepRegisterPublicKeyDescription => _vi
      ? 'Flutter gọi /api/v1/smart-otp/devices/enroll/begin bằng JWT hiện tại.'
      : 'Flutter calls /api/v1/smart-otp/devices/enroll/begin with the current JWT.';
  String get smartOtpStepSignChallenge =>
      _vi ? 'Ký challenge để kích hoạt' : 'Sign the challenge to activate';
  String get smartOtpStepSignChallengeDescription => _vi
      ? 'Thiết bị ký server challenge rồi gọi /api/v1/smart-otp/devices/enroll/confirm.'
      : 'The device signs the server challenge and calls /api/v1/smart-otp/devices/enroll/confirm.';
  String get smartOtpImplementationNote => _vi
      ? 'Khi bắt đầu, app sẽ tạo khóa ECDSA P-256 trên thiết bị, gửi public key lên Security API, rồi ký challenge để kích hoạt Smart OTP.'
      : 'When started, the app creates an ECDSA P-256 key on the device, sends the public key to the Security API, then signs the challenge to activate Smart OTP.';
  String get startSmartOtpSetup =>
      _vi ? 'Bắt đầu thiết lập Smart OTP' : 'Start Smart OTP setup';
  String get enrollingSmartOtp =>
      _vi ? 'Đang thiết lập Smart OTP...' : 'Setting up Smart OTP...';
  String get defaultPasskeyDisplayName =>
      _vi ? 'Người dùng XanhNow' : 'XanhNow User';
  String get loginWithPassword =>
      _vi ? 'Đăng nhập bằng mật khẩu' : 'Login with password';
  String get loginWithPasskey =>
      _vi ? 'Đăng nhập bằng passkey' : 'Login with passkey';
  String get loginSmartOtpTitle =>
      _vi ? 'Xác thực Smart OTP' : 'Smart OTP verification';
  String get loginSmartOtpDescription => _vi
      ? 'Tài khoản này đã bật Smart OTP. Vui lòng lấy mã trên thiết bị đã đăng ký và xác thực để hoàn tất đăng nhập.'
      : 'This account has Smart OTP enabled. Get a code from the enrolled device and verify it to finish login.';
  String get registrationSmartOtpGateDescription => _vi
      ? 'Smart OTP đã được thiết lập cho thiết bị này. Bạn phải lấy mã và xác thực thành công trước khi vào Home.'
      : 'Smart OTP has been set up on this device. You must get and verify a code before entering Home.';
  String get smartOtpCode => _vi ? 'Mã Smart OTP' : 'Smart OTP code';
  String get smartOtpCodeHint => _vi
      ? 'Mã có hiệu lực tối đa 30 giây.'
      : 'The code is valid for up to 30 seconds.';
  String get getSmartOtpCode => _vi ? 'Lấy mã Smart OTP' : 'Get Smart OTP code';
  String get gettingSmartOtpCode =>
      _vi ? 'Đang lấy mã Smart OTP...' : 'Getting Smart OTP code...';
  String get verifySmartOtpCode =>
      _vi ? 'Xác thực mã Smart OTP' : 'Verify Smart OTP code';
  String get verifyingSmartOtpCode =>
      _vi ? 'Đang xác thực Smart OTP...' : 'Verifying Smart OTP...';
  String get currentSession => _vi ? 'Phiên hiện tại' : 'Current session';
  String get session => _vi ? 'Phiên' : 'Session';
  String get sessionId => _vi ? 'Mã phiên' : 'Session ID';
  String get loadSecurityProfile =>
      _vi ? 'Tải hồ sơ bảo mật' : 'Load security profile';
  String get logoutAllSessions =>
      _vi ? 'Đăng xuất tất cả phiên' : 'Logout all sessions';
  String get state => _vi ? 'Trạng thái' : 'State';
  String get userId => _vi ? 'Mã người dùng' : 'User ID';
  String get passwordMismatch =>
      _vi ? 'Hai mật khẩu không khớp.' : 'Passwords do not match.';
  String get passwordTooShort => _vi
      ? 'Mật khẩu chưa đạt yêu cầu.'
      : 'Password does not meet the requirements.';
  String get passwordRuleMinLength => _vi
      ? 'Mật khẩu phải có ít nhất 12 ký tự.'
      : 'Password must be at least 12 characters.';
  String get passwordRuleUppercase => _vi
      ? 'Mật khẩu phải có ít nhất 1 chữ in hoa.'
      : 'Password must include at least 1 uppercase letter.';
  String get passwordRuleDigit => _vi
      ? 'Mật khẩu phải có ít nhất 1 số.'
      : 'Password must include at least 1 number.';
  String get passwordRuleSpecial => _vi
      ? 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt.'
      : 'Password must include at least 1 special character.';
  String get resetForm => _vi ? 'Nhập lại' : 'Reset';
  String get requiredFields =>
      _vi ? 'Vui lòng nhập đủ thông tin.' : 'Please fill in all fields.';
  String get creatingAccount =>
      _vi ? 'Đang tạo tài khoản...' : 'Creating account...';
  String get creatingPasskey =>
      _vi ? 'Đang đăng ký passkey...' : 'Creating passkey...';
  String get togglePasswordVisibility =>
      _vi ? 'Hiện hoặc ẩn mật khẩu' : 'Show or hide password';
}
