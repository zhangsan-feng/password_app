import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_storage_paths.dart';
import 'password_crypto_service.dart';

class DatabaseService {
  DatabaseService({this._databasePath, this._appStorageDirectoryResolver})
    : _cryptoService = PasswordCryptoService();

  static final DatabaseService instance = DatabaseService();

  Database? _database;
  final String? _databasePath;
  final Future<String> Function()? _appStorageDirectoryResolver;
  final PasswordCryptoService _cryptoService;
  final Random _random = Random.secure();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    if (!kIsWeb &&
        (_databasePath != null ||
            {
              TargetPlatform.windows,
              TargetPlatform.linux,
              TargetPlatform.macOS,
            }.contains(defaultTargetPlatform))) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasePath = _databasePath ?? await _resolveDatabasePath();

    _database = await openDatabase(
      databasePath,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE accounts ADD COLUMN password_hash TEXT NOT NULL DEFAULT ''",
          );

          final rows = await db.query('accounts');

          for (final row in rows) {
            final accountId = row['id'] as int;
            final currentPassword = row['password'] as String;
            final currentHash = row['password_hash'] as String;

            if (currentHash.isNotEmpty) {
              continue;
            }

            final payload = await _cryptoService.encrypt(currentPassword);
            await db.update(
              'accounts',
              {'password': payload.cipherText, 'password_hash': payload.hash},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          }
        }

        if (oldVersion < 3) {
          await _migrateToUuidSchema(db);
        }

        if (oldVersion >= 3 && oldVersion < 4) {
          await _migrateToSoftDeleteSchema(db);
        }

        if (oldVersion < 5) {
          await _migrateToSiteSoftDeleteSchema(db);
        }

        if (oldVersion < 6) {
          await _migrateToMemoSchema(db);
        }
      },
    );

    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    _database = null;
    await db.close();
  }

  Future<String> _resolveDatabasePath() async {
    return AppStoragePaths.resolveDatabasePath(
      createIfMissing: true,
      appStorageDirectoryResolver: _appStorageDirectoryResolver,
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE sites(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        domain TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        is_delete INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts(
        id TEXT PRIMARY KEY,
        site_id TEXT NOT NULL,
        label TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_changed_at TEXT NOT NULL,
        is_delete INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(site_id) REFERENCES sites(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE password_history(
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        password TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE account_recycle_bin(
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        site_id TEXT NOT NULL,
        site_name TEXT NOT NULL,
        account_name TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_changed_at TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY(site_id) REFERENCES sites(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE memos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateToUuidSchema(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE sites RENAME TO sites_legacy');
      await txn.execute('ALTER TABLE accounts RENAME TO accounts_legacy');
      await _createSchema(txn);

      final siteRows = await txn.query('sites_legacy', orderBy: 'id ASC');
      final siteIdMap = <int, String>{};
      for (final row in siteRows) {
        final legacyId = row['id'] as int;
        final uuid = _generateUuid();
        siteIdMap[legacyId] = uuid;
        await txn.insert('sites', {
          'id': uuid,
          'name': row['name'] as String,
          'domain': row['domain'] as String,
          'color_value': row['color_value'] as int,
          'is_delete': 0,
          'updated_at': now,
        });
      }

      final accountRows = await txn.query('accounts_legacy', orderBy: 'id ASC');
      for (final row in accountRows) {
        final siteId = siteIdMap[row['site_id'] as int];
        if (siteId == null) {
          continue;
        }

        final accountUuid = _generateUuid();
        await txn.insert('accounts', {
          'id': accountUuid,
          'site_id': siteId,
          'label': row['label'] as String,
          'username': row['username'] as String,
          'password': row['password'] as String,
          'password_hash': row['password_hash'] as String,
          'password_changed_at': now,
          'is_delete': 0,
          'updated_at': now,
        });

        await txn.insert('password_history', {
          'id': _generateUuid(),
          'account_id': accountUuid,
          'account_name': row['label'] as String,
          'password': row['password'] as String,
          'password_hash': row['password_hash'] as String,
          'created_at': now,
          'updated_at': now,
        });
      }

      await txn.execute('DROP TABLE accounts_legacy');
      await txn.execute('DROP TABLE sites_legacy');
    });
  }

  Future<void> _migrateToSoftDeleteSchema(Database db) async {
    await db.execute(
      'ALTER TABLE accounts ADD COLUMN is_delete INTEGER NOT NULL DEFAULT 0',
    );

    await db.execute('''
      CREATE TABLE account_recycle_bin(
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        site_id TEXT NOT NULL,
        site_name TEXT NOT NULL,
        account_name TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_changed_at TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY(site_id) REFERENCES sites(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateToSiteSoftDeleteSchema(Database db) async {
    final hasSiteIsDelete = await _tableHasColumn(db, 'sites', 'is_delete');
    if (!hasSiteIsDelete) {
      await db.execute(
        'ALTER TABLE sites ADD COLUMN is_delete INTEGER NOT NULL DEFAULT 0',
      );
    }

    final hasRecycleSiteName = await _tableHasColumn(
      db,
      'account_recycle_bin',
      'site_name',
    );
    if (!hasRecycleSiteName) {
      await db.execute(
        "ALTER TABLE account_recycle_bin ADD COLUMN site_name TEXT NOT NULL DEFAULT ''",
      );
    }

    await db.execute('''
      UPDATE account_recycle_bin
      SET site_name = COALESCE(
        NULLIF(site_name, ''),
        (SELECT sites.name FROM sites WHERE sites.id = account_recycle_bin.site_id),
        ''
      )
    ''');
  }

  Future<void> _migrateToMemoSchema(Database db) async {
    await db.execute('''
      CREATE TABLE memos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<bool> _tableHasColumn(
    DatabaseExecutor db,
    String tableName,
    String columnName,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    return columns.any((column) => column['name'] == columnName);
  }

  String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
