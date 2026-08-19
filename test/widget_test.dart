import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xanhnow_auth_module/app/xanhnow_auth_app.dart';
import 'package:xanhnow_auth_module/core/config/app_config.dart';

void main() {
  testWidgets('XanhNow Auth app starts while restoring session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const XanhNowAuthApp(
        config: AppConfig(
          securityBaseUrl: 'https://api.ioxy.site/security',
          contractVersion: 'v1',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
