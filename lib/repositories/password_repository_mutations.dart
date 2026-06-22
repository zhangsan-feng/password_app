part of 'password_repository.dart';

extension PasswordRepositoryMutations on PasswordRepository {
  Future<void> addSite(WebsiteDraft draft) async {
    final db = await _databaseService.database;
    await db.insert('sites', {
      'id': _generateUuid(),
      'name': draft.name.trim(),
      'domain': draft.domain.trim(),
      'color_value': draft.colorValue,
      'is_delete': 0,
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
        'is_delete': 0,
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
    final siteRows = await db.query(
      'sites',
      where: 'id = ?',
      whereArgs: [siteId],
      limit: 1,
    );
    if (siteRows.isEmpty) {
      return;
    }

    final site = siteRows.first;
    final siteName = site['name'] as String? ?? '';
    final now = _nowIso();

    await db.transaction((txn) async {
      await txn.update(
        'sites',
        {'is_delete': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [siteId],
      );

      final accountRows = await txn.query(
        'accounts',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );

      for (final row in accountRows) {
        final accountId = row['id'] as String;
        await txn.update(
          'accounts',
          {'is_delete': 1, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [accountId],
        );
        await _upsertRecycleEntry(
          txn,
          recycleId:
              await _findRecycleEntryId(txn, accountId) ?? _generateUuid(),
          accountId: accountId,
          siteId: siteId,
          siteName: siteName,
          accountName: row['label'] as String,
          username: row['username'] as String,
          encryptedPassword: row['password'] as String,
          passwordHash: row['password_hash'] as String,
          passwordChangedAt: row['password_changed_at'] as String,
          deletedAt: now,
          updatedAt: now,
        );
      }
    });
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
    final siteName = await _findSiteNameById(db, row['site_id'] as String);

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
        siteName: siteName,
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

    final recycleRows = await db.query(
      'account_recycle_bin',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    final accountRow = rows.first;
    final recycleRow = recycleRows.isEmpty ? null : recycleRows.first;
    final siteId =
        recycleRow?['site_id'] as String? ?? accountRow['site_id'] as String;
    final siteName = recycleRow?['site_name'] as String? ?? '';
    final now = _nowIso();

    await db.transaction((txn) async {
      final siteRows = await txn.query(
        'sites',
        where: 'id = ?',
        whereArgs: [siteId],
        limit: 1,
      );

      if (siteRows.isEmpty) {
        await txn.insert('sites', {
          'id': siteId,
          'name': siteName.isEmpty ? 'Restored Site' : siteName,
          'domain': '',
          'color_value': PasswordRepository._defaultSiteColorValue,
          'is_delete': 0,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'sites',
          {
            'name': siteName.isEmpty
                ? siteRows.first['name'] as String
                : siteName,
            'is_delete': 0,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [siteId],
        );
      }

      await txn.update(
        'accounts',
        {'site_id': siteId, 'is_delete': 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });
  }
}
