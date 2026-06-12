import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/password_crypto_service.dart';

class PasswordRepository {
  PasswordRepository({
    DatabaseService? databaseService,
    PasswordCryptoService? cryptoService,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _cryptoService = cryptoService ?? PasswordCryptoService();

  final DatabaseService _databaseService;
  final PasswordCryptoService _cryptoService;
  final Random _random = Random.secure();

  Future<void> initialize() async {
    await _databaseService.database;
  }

  Future<List<WebsiteEntry>> fetchSites({String query = ''}) async {
    final db = await _databaseService.database;
    final normalizedQuery = query.trim().toLowerCase();

    final siteRows = await db.query(
      'sites',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final accountRows = await db.query(
      'accounts',
      where: 'is_delete = 0',
      orderBy: 'updated_at DESC, label COLLATE NOCASE ASC',
    );

    final accountsBySiteId = <String, List<AccountEntry>>{};
    for (final row in accountRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );

      if (decryptResult.needsMigration) {
        final migratedPayload = await _cryptoService.encrypt(
          decryptResult.plainText,
        );
        await db.update(
          'accounts',
          {
            'password': migratedPayload.cipherText,
            'password_hash': migratedPayload.hash,
          },
          where: 'id = ?',
          whereArgs: [row['id'] as String],
        );
      }

      final account = AccountEntry(
        id: row['id'] as String,
        siteId: row['site_id'] as String,
        label: row['label'] as String,
        username: row['username'] as String,
        password: decryptResult.plainText,
      );
      accountsBySiteId.putIfAbsent(account.siteId, () => []).add(account);
    }

    return siteRows
        .map((row) {
          final siteId = row['id'] as String;
          return WebsiteEntry(
            id: siteId,
            name: row['name'] as String,
            domain: row['domain'] as String,
            colorValue: row['color_value'] as int,
            accounts: accountsBySiteId[siteId] ?? const [],
          );
        })
        .where((site) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final siteMatch =
              site.name.toLowerCase().contains(normalizedQuery) ||
              site.domain.toLowerCase().contains(normalizedQuery);

          final accountMatch = site.accounts.any(
            (account) =>
                account.label.toLowerCase().contains(normalizedQuery) ||
                account.username.toLowerCase().contains(normalizedQuery) ||
                account.password.toLowerCase().contains(normalizedQuery),
          );

          return siteMatch || accountMatch;
        })
        .toList();
  }

  Future<List<RecycledAccountEntry>> fetchDeletedAccounts() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT
        recycle.id,
        recycle.account_id,
        recycle.site_id,
        recycle.account_name,
        recycle.username,
        recycle.password,
        recycle.deleted_at
      FROM account_recycle_bin AS recycle
      INNER JOIN accounts AS accounts
        ON accounts.id = recycle.account_id
      WHERE accounts.is_delete = 1
      ORDER BY recycle.deleted_at DESC, recycle.updated_at DESC
    ''');

    final deletedAccounts = <RecycledAccountEntry>[];
    for (final row in rows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      deletedAccounts.add(
        RecycledAccountEntry(
          id: row['id'] as String,
          accountId: row['account_id'] as String,
          siteId: row['site_id'] as String,
          accountName: row['account_name'] as String,
          username: row['username'] as String,
          password: decryptResult.plainText,
          deletedAt:
              DateTime.tryParse(row['deleted_at'] as String)?.toLocal() ??
              DateTime.now(),
        ),
      );
    }
    return deletedAccounts;
  }

  Future<Map<String, Object>> exportPlainSyncData() async {
    final db = await _databaseService.database;
    final siteRows = await db.query('sites', orderBy: 'updated_at DESC');
    final accountRows = await db.query('accounts', orderBy: 'updated_at DESC');
    final historyRows = await db.query(
      'password_history',
      orderBy: 'updated_at DESC',
    );
    final recycleRows = await db.query(
      'account_recycle_bin',
      orderBy: 'updated_at DESC',
    );

    final accounts = <Map<String, Object>>[];
    for (final row in accountRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      accounts.add({
        'id': row['id'] as String,
        'siteId': row['site_id'] as String,
        'label': row['label'] as String,
        'username': row['username'] as String,
        'password': decryptResult.plainText,
        'passwordChangedAt': row['password_changed_at'] as String,
        'isDelete': (row['is_delete'] as int? ?? 0) == 1,
        'updatedAt': row['updated_at'] as String,
      });
    }

    final passwordHistory = <Map<String, Object>>[];
    for (final row in historyRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      passwordHistory.add({
        'id': row['id'] as String,
        'accountId': row['account_id'] as String,
        'accountName': row['account_name'] as String,
        'password': decryptResult.plainText,
        'createdAt': row['created_at'] as String,
        'updatedAt': row['updated_at'] as String,
      });
    }

    final accountRecycleBin = <Map<String, Object>>[];
    for (final row in recycleRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      accountRecycleBin.add({
        'id': row['id'] as String,
        'accountId': row['account_id'] as String,
        'siteId': row['site_id'] as String,
        'accountName': row['account_name'] as String,
        'username': row['username'] as String,
        'password': decryptResult.plainText,
        'passwordChangedAt': row['password_changed_at'] as String,
        'deletedAt': row['deleted_at'] as String,
        'updatedAt': row['updated_at'] as String,
      });
    }

    return {
      'version': 3,
      'sites': siteRows
          .map(
            (row) => <String, Object>{
              'id': row['id'] as String,
              'name': row['name'] as String,
              'domain': row['domain'] as String,
              'colorValue': row['color_value'] as int,
              'updatedAt': row['updated_at'] as String,
            },
          )
          .toList(),
      'accounts': accounts,
      'passwordHistory': passwordHistory,
      'accountRecycleBin': accountRecycleBin,
    };
  }

  Future<void> importPlainSyncData(Map<String, dynamic> payload) async {
    await mergePlainSyncData(payload);
  }

  Future<void> mergePlainSyncData(Map<String, dynamic> payload) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await _mergeSites(txn, payload['sites']);
      await _mergeAccounts(txn, payload['accounts']);
      await _mergePasswordHistory(txn, payload['passwordHistory']);
      await _mergeAccountRecycleBin(txn, payload['accountRecycleBin']);
    });
  }

  Future<void> addSite(WebsiteDraft draft) async {
    final db = await _databaseService.database;
    await db.insert('sites', {
      'id': _generateUuid(),
      'name': draft.name.trim(),
      'domain': draft.domain.trim(),
      'color_value': draft.colorValue,
      'updated_at': _nowIso(),
    });
  }

  Future<void> updateSite(String siteId, WebsiteDraft draft) async {
    final db = await _databaseService.database;
    await db.update(
      'sites',
      {
        'name': draft.name.trim(),
        'domain': draft.domain.trim(),
        'color_value': draft.colorValue,
        'updated_at': _nowIso(),
      },
      where: 'id = ?',
      whereArgs: [siteId],
    );
  }

  Future<void> addAccount(AccountDraft draft) async {
    final db = await _databaseService.database;
    final now = _nowIso();
    final accountId = _generateUuid();
    final payload = await _cryptoService.encrypt(draft.password.trim());

    await db.transaction((txn) async {
      await txn.insert('accounts', {
        'id': accountId,
        'site_id': draft.siteId,
        'label': draft.label.trim(),
        'username': draft.username.trim(),
        'password': payload.cipherText,
        'password_hash': payload.hash,
        'password_changed_at': now,
        'is_delete': 0,
        'updated_at': now,
      });
      await _insertPasswordHistory(
        txn,
        accountId: accountId,
        accountName: draft.label.trim(),
        encryptedPassword: payload.cipherText,
        passwordHash: payload.hash,
        createdAt: now,
      );
    });
  }

  Future<void> updateAccount(String accountId, AccountDraft draft) async {
    final db = await _databaseService.database;
    final now = _nowIso();
    final currentRows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (currentRows.isEmpty) {
      return;
    }

    final current = currentRows.first;
    final nextPassword = draft.password.trim();
    final currentPassword = await _cryptoService.decryptWithMigrationSupport(
      current['password'] as String,
    );
    final payload = await _cryptoService.encrypt(nextPassword);
    final passwordChanged = currentPassword.plainText != nextPassword;

    await db.transaction((txn) async {
      await txn.update(
        'accounts',
        {
          'site_id': draft.siteId,
          'label': draft.label.trim(),
          'username': draft.username.trim(),
          'password': payload.cipherText,
          'password_hash': payload.hash,
          'password_changed_at': passwordChanged
              ? now
              : current['password_changed_at'] as String,
          'is_delete': 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (passwordChanged) {
        await _insertPasswordHistory(
          txn,
          accountId: accountId,
          accountName: draft.label.trim(),
          encryptedPassword: payload.cipherText,
          passwordHash: payload.hash,
          createdAt: now,
        );
      }
    });
  }

  Future<void> rotateSecretKey({
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await _databaseService.database;
    final accountRows = await db.query(
      'accounts',
      columns: ['id', 'password'],
      orderBy: 'id ASC',
    );
    final historyRows = await db.query(
      'password_history',
      columns: ['id', 'password'],
      orderBy: 'id ASC',
    );
    final recycleRows = await db.query(
      'account_recycle_bin',
      columns: ['id', 'password'],
      orderBy: 'id ASC',
    );

    final total = accountRows.length + historyRows.length + recycleRows.length;
    onProgress?.call(0, total);

    final nextSecretKey = await _cryptoService.generateSecretKey();
    final pendingAccountUpdates =
        <({String id, PasswordCryptoPayload payload})>[];
    final pendingHistoryUpdates =
        <({String id, PasswordCryptoPayload payload})>[];
    final pendingRecycleUpdates =
        <({String id, PasswordCryptoPayload payload})>[];

    for (final row in accountRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      final nextPayload = await _cryptoService.encryptWithSecretKey(
        decryptResult.plainText,
        nextSecretKey,
      );
      pendingAccountUpdates.add((
        id: row['id'] as String,
        payload: nextPayload,
      ));
    }

    for (final row in historyRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      final nextPayload = await _cryptoService.encryptWithSecretKey(
        decryptResult.plainText,
        nextSecretKey,
      );
      pendingHistoryUpdates.add((
        id: row['id'] as String,
        payload: nextPayload,
      ));
    }

    for (final row in recycleRows) {
      final decryptResult = await _cryptoService.decryptWithMigrationSupport(
        row['password'] as String,
      );
      final nextPayload = await _cryptoService.encryptWithSecretKey(
        decryptResult.plainText,
        nextSecretKey,
      );
      pendingRecycleUpdates.add((
        id: row['id'] as String,
        payload: nextPayload,
      ));
    }

    await db.transaction((txn) async {
      var processed = 0;

      for (final update in pendingAccountUpdates) {
        await txn.update(
          'accounts',
          {
            'password': update.payload.cipherText,
            'password_hash': update.payload.hash,
          },
          where: 'id = ?',
          whereArgs: [update.id],
        );
        processed++;
        onProgress?.call(processed, total);
      }

      for (final update in pendingHistoryUpdates) {
        await txn.update(
          'password_history',
          {
            'password': update.payload.cipherText,
            'password_hash': update.payload.hash,
          },
          where: 'id = ?',
          whereArgs: [update.id],
        );
        processed++;
        onProgress?.call(processed, total);
      }

      for (final update in pendingRecycleUpdates) {
        await txn.update(
          'account_recycle_bin',
          {
            'password': update.payload.cipherText,
            'password_hash': update.payload.hash,
          },
          where: 'id = ?',
          whereArgs: [update.id],
        );
        processed++;
        onProgress?.call(processed, total);
      }
    });

    await _cryptoService.persistSecretKey(nextSecretKey);
    await _cryptoService.activateSecretKey(nextSecretKey);
  }

  Future<void> deleteSite(String siteId) async {
    final db = await _databaseService.database;
    await db.delete('sites', where: 'id = ?', whereArgs: [siteId]);
  }

  Future<void> deleteAccount(String accountId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final row = rows.first;
    final now = _nowIso();

    await db.transaction((txn) async {
      await txn.update(
        'accounts',
        {'is_delete': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [accountId],
      );
      await _upsertRecycleEntry(
        txn,
        recycleId: await _findRecycleEntryId(txn, accountId) ?? _generateUuid(),
        accountId: accountId,
        siteId: row['site_id'] as String,
        accountName: row['label'] as String,
        username: row['username'] as String,
        encryptedPassword: row['password'] as String,
        passwordHash: row['password_hash'] as String,
        passwordChangedAt: row['password_changed_at'] as String,
        deletedAt: now,
        updatedAt: now,
      );
    });
  }

  Future<void> restoreAccount(String accountId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    await db.update(
      'accounts',
      {'is_delete': 0, 'updated_at': _nowIso()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> _mergeSites(Transaction txn, Object? rawSites) async {
    if (rawSites is! List) {
      return;
    }

    for (final rawSite in rawSites) {
      if (rawSite is! Map) {
        continue;
      }

      final site = rawSite.map((key, value) => MapEntry(key.toString(), value));
      final id = '${site['id'] ?? ''}'.trim();
      final name = '${site['name'] ?? ''}'.trim();
      final domain = '${site['domain'] ?? ''}'.trim();
      final updatedAt = _normalizedTimestamp(site['updatedAt']);
      final colorValue = (site['colorValue'] as num?)?.toInt() ?? 0xFF6C8A7A;
      if (id.isEmpty || name.isEmpty || domain.isEmpty) {
        continue;
      }

      final existing = await txn.query(
        'sites',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('sites', {
          'id': id,
          'name': name,
          'domain': domain,
          'color_value': colorValue,
          'updated_at': updatedAt,
        });
        continue;
      }

      final currentUpdatedAt = _normalizedTimestamp(
        existing.first['updated_at'] as String,
      );
      if (_isIncomingNewer(updatedAt, currentUpdatedAt)) {
        await txn.update(
          'sites',
          {
            'name': name,
            'domain': domain,
            'color_value': colorValue,
            'updated_at': updatedAt,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _mergeAccounts(Transaction txn, Object? rawAccounts) async {
    if (rawAccounts is! List) {
      return;
    }

    for (final rawAccount in rawAccounts) {
      if (rawAccount is! Map) {
        continue;
      }

      final account = rawAccount.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final id = '${account['id'] ?? ''}'.trim();
      final siteId = '${account['siteId'] ?? ''}'.trim();
      final label = '${account['label'] ?? ''}'.trim();
      final username = '${account['username'] ?? ''}'.trim();
      final password = '${account['password'] ?? ''}';
      final passwordChangedAt = _normalizedTimestamp(
        account['passwordChangedAt'],
      );
      final isDelete = account['isDelete'] == true ? 1 : 0;
      final updatedAt = _normalizedTimestamp(account['updatedAt']);

      if (id.isEmpty ||
          siteId.isEmpty ||
          label.isEmpty ||
          username.isEmpty ||
          password.isEmpty) {
        continue;
      }

      final siteExists = await txn.query(
        'sites',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [siteId],
        limit: 1,
      );
      if (siteExists.isEmpty) {
        continue;
      }

      final encryptedPassword = await _cryptoService.encrypt(password);
      final existing = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('accounts', {
          'id': id,
          'site_id': siteId,
          'label': label,
          'username': username,
          'password': encryptedPassword.cipherText,
          'password_hash': encryptedPassword.hash,
          'password_changed_at': passwordChangedAt,
          'is_delete': isDelete,
          'updated_at': updatedAt,
        });
        continue;
      }

      final currentUpdatedAt = _normalizedTimestamp(
        existing.first['updated_at'] as String,
      );
      if (_isIncomingNewer(updatedAt, currentUpdatedAt)) {
        await txn.update(
          'accounts',
          {
            'site_id': siteId,
            'label': label,
            'username': username,
            'password': encryptedPassword.cipherText,
            'password_hash': encryptedPassword.hash,
            'password_changed_at': passwordChangedAt,
            'is_delete': isDelete,
            'updated_at': updatedAt,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _mergePasswordHistory(
    Transaction txn,
    Object? rawHistory,
  ) async {
    if (rawHistory is! List) {
      return;
    }

    for (final rawItem in rawHistory) {
      if (rawItem is! Map) {
        continue;
      }

      final item = rawItem.map((key, value) => MapEntry(key.toString(), value));
      final id = '${item['id'] ?? ''}'.trim();
      final accountId = '${item['accountId'] ?? ''}'.trim();
      final accountName = '${item['accountName'] ?? ''}'.trim();
      final password = '${item['password'] ?? ''}';
      final createdAt = _normalizedTimestamp(item['createdAt']);
      final updatedAt = _normalizedTimestamp(item['updatedAt']);

      if (id.isEmpty ||
          accountId.isEmpty ||
          accountName.isEmpty ||
          password.isEmpty) {
        continue;
      }

      final accountExists = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (accountExists.isEmpty) {
        continue;
      }

      final encryptedPassword = await _cryptoService.encrypt(password);
      final existing = await txn.query(
        'password_history',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('password_history', {
          'id': id,
          'account_id': accountId,
          'account_name': accountName,
          'password': encryptedPassword.cipherText,
          'password_hash': encryptedPassword.hash,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });
        continue;
      }

      final currentUpdatedAt = _normalizedTimestamp(
        existing.first['updated_at'] as String,
      );
      if (_isIncomingNewer(updatedAt, currentUpdatedAt)) {
        await txn.update(
          'password_history',
          {
            'account_id': accountId,
            'account_name': accountName,
            'password': encryptedPassword.cipherText,
            'password_hash': encryptedPassword.hash,
            'created_at': createdAt,
            'updated_at': updatedAt,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> _mergeAccountRecycleBin(
    Transaction txn,
    Object? rawRecycle,
  ) async {
    if (rawRecycle is! List) {
      return;
    }

    for (final rawItem in rawRecycle) {
      if (rawItem is! Map) {
        continue;
      }

      final item = rawItem.map((key, value) => MapEntry(key.toString(), value));
      final id = '${item['id'] ?? ''}'.trim();
      final accountId = '${item['accountId'] ?? ''}'.trim();
      final siteId = '${item['siteId'] ?? ''}'.trim();
      final accountName = '${item['accountName'] ?? ''}'.trim();
      final username = '${item['username'] ?? ''}'.trim();
      final password = '${item['password'] ?? ''}';
      final passwordChangedAt = _normalizedTimestamp(item['passwordChangedAt']);
      final deletedAt = _normalizedTimestamp(item['deletedAt']);
      final updatedAt = _normalizedTimestamp(item['updatedAt']);

      if (id.isEmpty ||
          accountId.isEmpty ||
          siteId.isEmpty ||
          accountName.isEmpty ||
          username.isEmpty ||
          password.isEmpty) {
        continue;
      }

      final siteExists = await txn.query(
        'sites',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [siteId],
        limit: 1,
      );
      if (siteExists.isEmpty) {
        continue;
      }

      final encryptedPassword = await _cryptoService.encrypt(password);
      final existing = await txn.query(
        'account_recycle_bin',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await _upsertRecycleEntry(
          txn,
          recycleId: id,
          accountId: accountId,
          siteId: siteId,
          accountName: accountName,
          username: username,
          encryptedPassword: encryptedPassword.cipherText,
          passwordHash: encryptedPassword.hash,
          passwordChangedAt: passwordChangedAt,
          deletedAt: deletedAt,
          updatedAt: updatedAt,
        );
        continue;
      }

      final currentUpdatedAt = _normalizedTimestamp(
        existing.first['updated_at'] as String,
      );
      if (_isIncomingNewer(updatedAt, currentUpdatedAt)) {
        await _upsertRecycleEntry(
          txn,
          recycleId: id,
          accountId: accountId,
          siteId: siteId,
          accountName: accountName,
          username: username,
          encryptedPassword: encryptedPassword.cipherText,
          passwordHash: encryptedPassword.hash,
          passwordChangedAt: passwordChangedAt,
          deletedAt: deletedAt,
          updatedAt: updatedAt,
        );
      }
    }
  }

  Future<void> _insertPasswordHistory(
    Transaction txn, {
    required String accountId,
    required String accountName,
    required String encryptedPassword,
    required String passwordHash,
    required String createdAt,
  }) async {
    await txn.insert('password_history', {
      'id': _generateUuid(),
      'account_id': accountId,
      'account_name': accountName,
      'password': encryptedPassword,
      'password_hash': passwordHash,
      'created_at': createdAt,
      'updated_at': createdAt,
    });
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

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  Future<String?> _findRecycleEntryId(Transaction txn, String accountId) async {
    final rows = await txn.query(
      'account_recycle_bin',
      columns: ['id'],
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as String;
  }

  Future<void> _upsertRecycleEntry(
    Transaction txn, {
    required String recycleId,
    required String accountId,
    required String siteId,
    required String accountName,
    required String username,
    required String encryptedPassword,
    required String passwordHash,
    required String passwordChangedAt,
    required String deletedAt,
    required String updatedAt,
  }) async {
    await txn.insert('account_recycle_bin', {
      'id': recycleId,
      'account_id': accountId,
      'site_id': siteId,
      'account_name': accountName,
      'username': username,
      'password': encryptedPassword,
      'password_hash': passwordHash,
      'password_changed_at': passwordChangedAt,
      'deleted_at': deletedAt,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _normalizedTimestamp(Object? value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) {
      return _nowIso();
    }
    return DateTime.tryParse(raw)?.toUtc().toIso8601String() ?? _nowIso();
  }

  bool _isIncomingNewer(String incoming, String current) {
    final incomingAt = DateTime.tryParse(incoming);
    final currentAt = DateTime.tryParse(current);
    if (incomingAt == null || currentAt == null) {
      return false;
    }
    return incomingAt.isAfter(currentAt);
  }
}
