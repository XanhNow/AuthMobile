import 'package:flutter/material.dart';

import 'app/xanhnow_auth_app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(XanhNowAuthApp(config: AppConfig.fromEnvironment()));
}
