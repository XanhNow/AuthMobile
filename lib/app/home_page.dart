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
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notice = context.read<AuthSessionCubit>().state.notice;
      if (notice != null && notice.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(_homeSnackBar(notice));
      }
    });
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
          title: const Text('XanhNow Auth'),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'Module',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user),
              label: 'Tài khoản',
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
            ],
          ),
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
