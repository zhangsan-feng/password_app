import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:password_app/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores desktop database in an app-local data directory', () async {
    final rootDir = await Directory.systemTemp.createTemp(
      'database_service_test_',
    );
    final expectedDatabasePath = path.join(
      rootDir.path,
      'data',
      'password_vault.db',
    );
    final databaseService = DatabaseService(
      appStorageDirectoryResolver: () async => rootDir.path,
    );

    try {
      await databaseService.database;

      expect(File(expectedDatabasePath).existsSync(), isTrue);
    } finally {
      await databaseService.close();
      if (rootDir.existsSync()) {
        rootDir.deleteSync(recursive: true);
      }
    }
  });
}
