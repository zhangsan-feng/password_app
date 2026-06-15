import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'repositories/password_repository.dart';
import 'services/app_layout.dart';
import 'services/password_crypto_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      center: true,
      minimumSize: Size(
        AppLayout.desktopMinWidth,
        AppLayout.desktopMinHeight,
      ),
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final cryptoService = PasswordCryptoService();
  final repository = PasswordRepository(cryptoService: cryptoService);

  runApp(
    PasswordVaultApp(repository: repository, cryptoService: cryptoService),
  );

}
