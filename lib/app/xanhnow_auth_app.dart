import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/app_config.dart';
import '../core/device/device_context_service.dart';
import '../core/network/api_client.dart';
import '../core/session/auth_session_cubit.dart';
import '../core/storage/auth_identity_store.dart';
import '../core/storage/secure_token_store.dart';
import '../features/auth/data/passkey_ceremony_service.dart';
import '../features/auth/data/security_auth_api.dart';
import '../features/auth/data/smart_otp_device_crypto_service.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/bloc/login_bloc.dart';
import '../features/auth/presentation/bloc/registration_bloc.dart';
import '../features/auth/presentation/pages/auth_shell_page.dart';
import 'home_page.dart';

class XanhNowAuthApp extends StatelessWidget {
  const XanhNowAuthApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: config),
        RepositoryProvider(create: (_) => const SecureTokenStore()),
        RepositoryProvider(create: (_) => const AuthIdentityStore()),
        RepositoryProvider(create: (_) => DeviceContextService()),
        RepositoryProvider(
          create: (context) => ApiClient(
            baseUrl: config.securityBaseUrl,
            tokenStore: context.read<SecureTokenStore>(),
          ),
        ),
        RepositoryProvider(create: (_) => PasskeyCeremonyService()),
        RepositoryProvider(create: (_) => SmartOtpDeviceCryptoService()),
        RepositoryProvider(
          create: (context) => SecurityAuthApi(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (context) => AuthRepository(
            api: context.read<SecurityAuthApi>(),
            passkeys: context.read<PasskeyCeremonyService>(),
            smartOtpCrypto: context.read<SmartOtpDeviceCryptoService>(),
            deviceContext: context.read<DeviceContextService>(),
            tokenStore: context.read<SecureTokenStore>(),
            identityStore: context.read<AuthIdentityStore>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthSessionCubit(
              tokenStore: context.read<SecureTokenStore>(),
              identityStore: context.read<AuthIdentityStore>(),
            )..restore(),
          ),
          BlocProvider(
            create: (context) => RegistrationBloc(
              repository: context.read<AuthRepository>(),
              sessionCubit: context.read<AuthSessionCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) => LoginBloc(
              repository: context.read<AuthRepository>(),
              sessionCubit: context.read<AuthSessionCubit>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'XanhNow Auth',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
              brightness: Brightness.light,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
          home: BlocBuilder<AuthSessionCubit, AuthSessionState>(
            builder: (context, state) {
              return switch (state.status) {
                AuthSessionStatus.authenticated => const HomePage(),
                AuthSessionStatus.unknown => const _AppLoadingPage(),
                _ => AuthShellPage(initialIndex: state.preferLogin ? 1 : 0),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _AppLoadingPage extends StatelessWidget {
  const _AppLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
