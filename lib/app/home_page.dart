import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/session/auth_session_cubit.dart';
import '../features/auth/domain/auth_repository.dart';

const _homeTextColor = Color(0xFF0B2F4A);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _smartOtpCodeController = TextEditingController();

  bool _isLoggingOut = false;
  bool _isSmartOtpBusy = false;
  SmartOtpCodeChallenge? _smartOtpChallenge;
  DateTime? _smartOtpUsableUntilUtc;
  String? _smartOtpInputError;
  String? _smartOtpPanelMessage;
  Timer? _smartOtpTimer;

  @override
  void dispose() {
    _smartOtpTimer?.cancel();
    _smartOtpCodeController.dispose();
    super.dispose();
  }

  int get _smartOtpRemainingSeconds {
    final usableUntil = _smartOtpUsableUntilUtc;
    if (usableUntil == null) {
      return 0;
    }

    final remaining = usableUntil.difference(DateTime.now().toUtc()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _isSmartOtpExpired {
    return _smartOtpChallenge != null && _smartOtpRemainingSeconds <= 0;
  }

  void _startSmartOtpTimer() {
    _smartOtpTimer?.cancel();
    _smartOtpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _smartOtpChallenge == null) {
        _smartOtpTimer?.cancel();
        return;
      }

      if (_isSmartOtpExpired) {
        _smartOtpCodeController.clear();
        setState(() {
          _smartOtpInputError = null;
          _smartOtpPanelMessage =
              'Mã Smart OTP đã hết hạn. Vui lòng lấy mã mới.';
        });
        _smartOtpTimer?.cancel();
        return;
      }

      setState(() {});
    });
  }

  void _clearSmartOtpChallenge() {
    _smartOtpTimer?.cancel();
    _smartOtpCodeController.clear();
    _smartOtpChallenge = null;
    _smartOtpUsableUntilUtc = null;
    _smartOtpInputError = null;
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() => _isLoggingOut = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<AuthRepository>().logoutAll();
      if (!mounted) {
        return;
      }

      await context.read<AuthSessionCubit>().clear();
      messenger.showSnackBar(_homeSnackBar('Đăng xuất thành công.'));
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(_homeSnackBar('Đăng xuất thất bại: $error'));
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _revealSmartOtp() async {
    if (_isSmartOtpBusy) {
      return;
    }

    setState(() => _isSmartOtpBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final challenge = await context
          .read<AuthRepository>()
          .revealSmartOtpCode();
      if (!mounted) {
        return;
      }
      _smartOtpCodeController.clear();
      final now = DateTime.now().toUtc();
      final localExpiresAt = now.add(const Duration(seconds: 60));
      final providerExpiresAt = challenge.reveal.expiresAtUtc.toUtc();
      setState(() {
        _smartOtpChallenge = challenge;
        _smartOtpUsableUntilUtc = providerExpiresAt.isBefore(localExpiresAt)
            ? providerExpiresAt
            : localExpiresAt;
        _smartOtpInputError = null;
        _smartOtpPanelMessage = null;
      });
      _startSmartOtpTimer();
      messenger.showSnackBar(
        _homeSnackBar('Đã lấy mã Smart OTP. Nhập mã để xác thực.'),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _smartOtpTimer?.cancel();
      _smartOtpCodeController.clear();
      setState(() {
        _smartOtpChallenge = null;
        _smartOtpUsableUntilUtc = null;
        _smartOtpInputError = null;
        _smartOtpPanelMessage = 'Không lấy được Smart OTP. Vui lòng thử lại.';
      });
      messenger.showSnackBar(_homeSnackBar('Không lấy được Smart OTP: $error'));
    } finally {
      if (mounted) {
        setState(() => _isSmartOtpBusy = false);
      }
    }
  }

  Future<void> _verifySmartOtp() async {
    final challenge = _smartOtpChallenge;
    if (_isSmartOtpBusy || challenge == null) {
      return;
    }

    if (_isSmartOtpExpired) {
      _smartOtpCodeController.clear();
      setState(() {
        _smartOtpInputError = null;
        _smartOtpPanelMessage = 'Mã Smart OTP đã hết hạn. Vui lòng lấy mã mới.';
      });
      return;
    }

    final otp = _smartOtpCodeController.text.trim();
    if (otp.isEmpty) {
      setState(() => _smartOtpInputError = 'Vui lòng nhập mã Smart OTP.');
      return;
    }

    setState(() => _isSmartOtpBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthRepository>().verifySmartOtpCode(
        challenge: challenge.challenge,
        otp: otp,
      );
      if (!mounted) {
        return;
      }
      _smartOtpTimer?.cancel();
      setState(() {
        _clearSmartOtpChallenge();
        _smartOtpPanelMessage = null;
      });
      messenger.showSnackBar(_homeSnackBar('Xác thực Smart OTP thành công.'));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        _homeSnackBar('Xác thực Smart OTP thất bại: $error'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSmartOtpBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSessionCubit>().state;
    final sessionId = session.tokens?.sessionId;
    final identity = session.identity;
    final userId = identity?.userId ?? session.userId;
    final phoneNumber =
        identity?.maskedPhoneNumber ?? identity?.phoneNumber ?? 'Chưa có';

    return DefaultTextStyle.merge(
      style: const TextStyle(color: _homeTextColor),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: _homeTextColor,
          title: const Text('XanhNow'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _homeTextColor,
                  side: const BorderSide(color: _homeTextColor),
                ),
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(_isLoggingOut ? 'Đang đăng xuất' : 'Đăng xuất'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Trang chủ XanhNow',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: _homeTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Không thuộc riêng module nào. Đây là màn hình chung sau khi người dùng đăng nhập thành công.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: _homeTextColor),
              ),
              const SizedBox(height: 24),
              _HomeInfoTile(
                icon: Icons.verified_user_outlined,
                title: 'Phiên đăng nhập',
                value: sessionId == null || sessionId.isEmpty
                    ? 'Đang hoạt động'
                    : sessionId,
              ),
              const SizedBox(height: 12),
              _HomeInfoTile(
                icon: Icons.badge_outlined,
                title: 'User ID',
                value: userId == null || userId.isEmpty ? 'Chưa có' : userId,
              ),
              const SizedBox(height: 12),
              _HomeInfoTile(
                icon: Icons.phone_android_outlined,
                title: 'Số điện thoại',
                value: phoneNumber,
              ),
              const SizedBox(height: 12),
              const _HomeInfoTile(
                icon: Icons.apps_outlined,
                title: 'Module tiếp theo',
                value: 'Sẵn sàng nối các module nghiệp vụ của hệ thống.',
              ),
              const SizedBox(height: 24),
              Text(
                'Smart OTP',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _homeTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _SmartOtpPanel(
                challenge: _smartOtpChallenge,
                codeController: _smartOtpCodeController,
                busy: _isSmartOtpBusy,
                expired: _isSmartOtpExpired,
                remainingSeconds: _smartOtpRemainingSeconds,
                inputError: _smartOtpInputError,
                panelMessage: _smartOtpPanelMessage,
                onReveal: _revealSmartOtp,
                onVerify: _verifySmartOtp,
                onCodeChanged: (_) {
                  if (_smartOtpInputError != null) {
                    setState(() => _smartOtpInputError = null);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartOtpPanel extends StatelessWidget {
  const _SmartOtpPanel({
    required this.challenge,
    required this.codeController,
    required this.busy,
    required this.expired,
    required this.remainingSeconds,
    required this.inputError,
    required this.panelMessage,
    required this.onReveal,
    required this.onVerify,
    required this.onCodeChanged,
  });

  final SmartOtpCodeChallenge? challenge;
  final TextEditingController codeController;
  final bool busy;
  final bool expired;
  final int remainingSeconds;
  final String? inputError;
  final String? panelMessage;
  final VoidCallback onReveal;
  final VoidCallback onVerify;
  final ValueChanged<String> onCodeChanged;

  @override
  Widget build(BuildContext context) {
    final otp = challenge?.reveal.otpCode;
    final hasChallenge = otp != null && otp.isNotEmpty;
    final canUseChallenge = hasChallenge && !expired;
    final canVerify = canUseChallenge && codeController.text.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasChallenge
                  ? expired
                        ? 'Mã Smart OTP đã hết hạn. Lấy mã mới để tiếp tục.'
                        : 'Mã Smart OTP đã được cấp. Nhập mã bên dưới để xác thực với Security API.'
                  : 'Lấy mã Smart OTP từ thiết bị đã đăng ký, sau đó xác thực mã với Security API.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _homeTextColor),
            ),
            if (panelMessage != null && panelMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                panelMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _homeTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (canUseChallenge) ...[
              const SizedBox(height: 16),
              Text(
                otp,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _homeTextColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Còn $remainingSeconds giây',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _homeTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: onCodeChanged,
                onSubmitted: (_) {
                  if (canVerify && !busy) {
                    onVerify();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nhập mã Smart OTP',
                  errorText: inputError,
                  prefixIcon: const Icon(Icons.password_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onReveal,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.password_outlined),
              label: Text(canUseChallenge ? 'Lấy mã mới' : 'Lấy mã Smart OTP'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || !canVerify ? null : onVerify,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Xác thực mã Smart OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

SnackBar _homeSnackBar(String message) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFFE6F4F1),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    content: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _homeTextColor,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _HomeInfoTile extends StatelessWidget {
  const _HomeInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        iconColor: _homeTextColor,
        textColor: _homeTextColor,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
