import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppStoragePaths {
  static const databaseFileName = 'password_vault.db';
  static const keyringFileName = '.vault_keyring.json';
  static const legacyKeyFileName = '.vault_aes_key';

  static Future<String> resolveDataDirectoryPath({
    bool createIfMissing = false,
    Future<String> Function()? appStorageDirectoryResolver,
  }) async {
    final baseDirectoryPath = await _resolveBaseDirectoryPath(
      appStorageDirectoryResolver: appStorageDirectoryResolver,
    );
    final dataDirectoryPath = _isDesktopPlatform
        ? path.join(baseDirectoryPath, 'data')
        : baseDirectoryPath;

    if (createIfMissing) {
      final dataDirectory = Directory(dataDirectoryPath);
      if (!await dataDirectory.exists()) {
        await dataDirectory.create(recursive: true);
      }
    }

    return dataDirectoryPath;
  }

  static Future<String> resolveDatabasePath({
    bool createIfMissing = false,
    Future<String> Function()? appStorageDirectoryResolver,
  }) async {
    final dataDirectoryPath = await resolveDataDirectoryPath(
      createIfMissing: createIfMissing,
      appStorageDirectoryResolver: appStorageDirectoryResolver,
    );
    return path.join(dataDirectoryPath, databaseFileName);
  }

  static Future<String> resolveKeyringPath({
    bool createIfMissing = false,
    Future<String> Function()? appStorageDirectoryResolver,
  }) async {
    final dataDirectoryPath = await resolveDataDirectoryPath(
      createIfMissing: createIfMissing,
      appStorageDirectoryResolver: appStorageDirectoryResolver,
    );
    return path.join(dataDirectoryPath, keyringFileName);
  }

  static Future<String> resolveLegacyKeyPath({
    bool createIfMissing = false,
    Future<String> Function()? appStorageDirectoryResolver,
  }) async {
    final dataDirectoryPath = await resolveDataDirectoryPath(
      createIfMissing: createIfMissing,
      appStorageDirectoryResolver: appStorageDirectoryResolver,
    );
    return path.join(dataDirectoryPath, legacyKeyFileName);
  }

  static Future<String> _resolveBaseDirectoryPath({
    Future<String> Function()? appStorageDirectoryResolver,
  }) async {
    if (_isDesktopPlatform) {
      return await (appStorageDirectoryResolver?.call() ??
          Future.value(File(Platform.resolvedExecutable).parent.path));
    }

    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static bool get _isDesktopPlatform =>
      !kIsWeb &&
      {
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);
}
