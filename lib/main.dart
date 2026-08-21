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

    const windowSize = Size(
      AppLayout.desktopWindowWidth,
      AppLayout.desktopWindowHeight,
    );
    const windowOptions = WindowOptions(
      size: windowSize,
      center: true,
      minimumSize: windowSize,
      maximumSize: windowSize,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
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
