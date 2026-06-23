part of 'password_repository.dart';

extension PasswordRepositorySync on PasswordRepository {
  Future<List<RecycledAccountEntry>> fetchDeletedAccounts() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT
        recycle.id,
        recycle.account_id,
        recycle.site_id,
        recycle.site_name,
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
          siteName: row['site_name'] as String? ?? '',
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
    final memoRows = await db.query('memos', orderBy: 'updated_at DESC');

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
        'siteName': row['site_name'] as String,
        'accountName': row['account_name'] as String,
        'username': row['username'] as String,
        'password': decryptResult.plainText,
        'passwordChangedAt': row['password_changed_at'] as String,
        'deletedAt': row['deleted_at'] as String,
        'updatedAt': row['updated_at'] as String,
      });
    }

    return {
      'version': 5,
      'sites': siteRows
          .map(
            (row) => <String, Object>{
              'id': row['id'] as String,
              'name': row['name'] as String,
              'domain': row['domain'] as String,
              'colorValue': row['color_value'] as int,
              'isDelete': (row['is_delete'] as int? ?? 0) == 1,
              'updatedAt': row['updated_at'] as String,
            },
          )
          .toList(),
      'accounts': accounts,
      'passwordHistory': passwordHistory,
      'accountRecycleBin': accountRecycleBin,
      'memos': memoRows
          .map(
            (row) => <String, Object>{
              'id': row['id'] as String,
              'content': row['content'] as String,
              'updatedAt': row['updated_at'] as String,
            },
          )
          .toList(),
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
      await _mergeMemos(txn, payload['memos']);
    });
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
      final colorValue =
          (site['colorValue'] as num?)?.toInt() ??
          PasswordRepository._defaultSiteColorValue;
      final isDelete = _readBoolFlag(site['isDelete']) ? 1 : 0;
      if (id.isEmpty) {
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
          'sites',
          {
            'name': name,
            'domain': domain,
            'color_value': colorValue,
            'is_delete': isDelete,
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
      final siteName = '${item['siteName'] ?? ''}'.trim();
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
          siteName: siteName,
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
          siteName: siteName,
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

  Future<void> _mergeMemos(Transaction txn, Object? rawMemos) async {
    if (rawMemos is! List) {
      return;
    }

    for (final rawMemo in rawMemos) {
      if (rawMemo is! Map) {
        continue;
      }

      final memo = rawMemo.map((key, value) => MapEntry(key.toString(), value));
      final id = '${memo['id'] ?? ''}'.trim();
      final content = '${memo['content'] ?? ''}';
      final updatedAt = _normalizedTimestamp(memo['updatedAt']);

      if (id.isEmpty || content.trim().isEmpty) {
        continue;
      }

      final existing = await txn.query(
        'memos',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('memos', {
          'id': id,
          'content': content,
          'updated_at': updatedAt,
        });
        continue;
      }

      final currentUpdatedAt = _normalizedTimestamp(
        existing.first['updated_at'] as String,
      );
      if (_isIncomingNewer(updatedAt, currentUpdatedAt)) {
        await txn.update(
          'memos',
          {'content': content, 'updated_at': updatedAt},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }
}
