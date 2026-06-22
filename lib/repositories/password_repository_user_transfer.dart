part of 'password_repository.dart';

class _UserImportSite {
  const _UserImportSite({
    required this.name,
    required this.domain,
    required this.accounts,
  });

  final String name;
  final String domain;
  final List<_UserImportAccount> accounts;
}

class _UserImportAccount {
  const _UserImportAccount({
    required this.label,
    required this.username,
    required this.password,
  });

  final String label;
  final String username;
  final String password;
}

extension PasswordRepositoryUserTransfer on PasswordRepository {
  Future<Map<String, Object>> exportUserAccountData() async {
    final sites = await fetchSites();

    return {
      'version': 1,
      'sites': sites
          .map(
            (site) => <String, Object>{
              'name': site.name,
              'domain': site.domain,
              'accounts': site.accounts
                  .map(
                    (account) => <String, Object>{
                      'label': account.label,
                      'username': account.username,
                      'password': account.password,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  Future<UserAccountImportResult> importUserAccountData(
    Map<String, dynamic> payload,
  ) async {
    final sites = _parseUserImportPayload(payload);
    final db = await _databaseService.database;

    return db.transaction((txn) async {
      final now = _nowIso();
      final siteRows = await txn.query(
        'sites',
        orderBy: 'is_delete ASC, updated_at DESC',
      );
      final accountRows = await txn.query(
        'accounts',
        orderBy: 'is_delete ASC, updated_at DESC',
      );

      final siteIdsByKey = <String, String>{};
      for (final row in siteRows) {
        final key = _userSiteKey(
          row['name'] as String? ?? '',
          row['domain'] as String? ?? '',
        );
        siteIdsByKey.putIfAbsent(key, () => row['id'] as String);
      }

      final accountRowsById = <String, Map<String, Object?>>{};
      final accountIdsByKey = <String, String>{};
      for (final row in accountRows) {
        final accountId = row['id'] as String;
        accountRowsById[accountId] = row;
        final key = _userAccountKey(
          row['site_id'] as String? ?? '',
          row['label'] as String? ?? '',
          row['username'] as String? ?? '',
        );
        accountIdsByKey.putIfAbsent(key, () => accountId);
      }

      var addedSiteCount = 0;
      var addedAccountCount = 0;
      var updatedAccountCount = 0;

      for (final site in sites) {
        final siteKey = _userSiteKey(site.name, site.domain);
        var siteId = siteIdsByKey[siteKey];

        if (siteId == null) {
          siteId = _generateUuid();
          await txn.insert('sites', {
            'id': siteId,
            'name': site.name,
            'domain': site.domain,
            'color_value': _pickImportedSiteColor(site.name, site.domain),
            'is_delete': 0,
            'updated_at': now,
          });
          siteIdsByKey[siteKey] = siteId;
          addedSiteCount++;
        } else {
          await txn.update(
            'sites',
            {
              'name': site.name,
              'domain': site.domain,
              'is_delete': 0,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [siteId],
          );
        }

        for (final account in site.accounts) {
          final accountKey = _userAccountKey(
            siteId,
            account.label,
            account.username,
          );
          final existingAccountId = accountIdsByKey[accountKey];

          if (existingAccountId == null) {
            final payload = await _cryptoService.encrypt(account.password);
            final accountId = _generateUuid();

            await txn.insert('accounts', {
              'id': accountId,
              'site_id': siteId,
              'label': account.label,
              'username': account.username,
              'password': payload.cipherText,
              'password_hash': payload.hash,
              'password_changed_at': now,
              'is_delete': 0,
              'updated_at': now,
            });
            await _insertPasswordHistory(
              txn,
              accountId: accountId,
              accountName: account.label,
              encryptedPassword: payload.cipherText,
              passwordHash: payload.hash,
              createdAt: now,
            );

            accountIdsByKey[accountKey] = accountId;
            accountRowsById[accountId] = {
              'id': accountId,
              'site_id': siteId,
              'label': account.label,
              'username': account.username,
              'password': payload.cipherText,
              'password_changed_at': now,
            };
            addedAccountCount++;
            continue;
          }

          final existingRow = accountRowsById[existingAccountId];
          if (existingRow == null) {
            continue;
          }

          final currentPassword = await _cryptoService
              .decryptWithMigrationSupport(existingRow['password'] as String);
          final nextPayload = await _cryptoService.encrypt(account.password);
          final passwordChanged = currentPassword.plainText != account.password;
          final nextPasswordChangedAt = passwordChanged
              ? now
              : existingRow['password_changed_at'] as String? ?? now;

          await txn.update(
            'accounts',
            {
              'site_id': siteId,
              'label': account.label,
              'username': account.username,
              'password': nextPayload.cipherText,
              'password_hash': nextPayload.hash,
              'password_changed_at': nextPasswordChangedAt,
              'is_delete': 0,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existingAccountId],
          );

          if (passwordChanged) {
            await _insertPasswordHistory(
              txn,
              accountId: existingAccountId,
              accountName: account.label,
              encryptedPassword: nextPayload.cipherText,
              passwordHash: nextPayload.hash,
              createdAt: now,
            );
          }

          accountRowsById[existingAccountId] = {
            'id': existingAccountId,
            'site_id': siteId,
            'label': account.label,
            'username': account.username,
            'password': nextPayload.cipherText,
            'password_changed_at': nextPasswordChangedAt,
          };
          updatedAccountCount++;
        }
      }

      return UserAccountImportResult(
        addedSiteCount: addedSiteCount,
        addedAccountCount: addedAccountCount,
        updatedAccountCount: updatedAccountCount,
      );
    });
  }

  List<_UserImportSite> _parseUserImportPayload(Map<String, dynamic> payload) {
    final version = payload['version'];
    if (version is! num || version.toInt() != 1) {
      throw const FormatException('仅支持 version 为 1 的导入数据。');
    }

    final rawSites = payload['sites'];
    if (rawSites is! List) {
      throw const FormatException('导入内容缺少 sites 列表。');
    }

    final sites = <_UserImportSite>[];
    for (var siteIndex = 0; siteIndex < rawSites.length; siteIndex++) {
      final rawSite = rawSites[siteIndex];
      if (rawSite is! Map) {
        throw FormatException('第 ${siteIndex + 1} 个站点必须是对象。');
      }

      final site = rawSite.map((key, value) => MapEntry(key.toString(), value));
      final name = '${site['name'] ?? ''}'.trim();
      final domain = '${site['domain'] ?? ''}'.trim();
      if (name.isEmpty && domain.isEmpty) {
        throw FormatException('第 ${siteIndex + 1} 个站点至少需要填写 name 或 domain。');
      }

      final rawAccounts = site['accounts'];
      if (rawAccounts is! List) {
        throw FormatException('第 ${siteIndex + 1} 个站点缺少 accounts 列表。');
      }

      final accounts = <_UserImportAccount>[];
      for (
        var accountIndex = 0;
        accountIndex < rawAccounts.length;
        accountIndex++
      ) {
        final rawAccount = rawAccounts[accountIndex];
        if (rawAccount is! Map) {
          throw FormatException(
            '第 ${siteIndex + 1} 个站点的第 ${accountIndex + 1} 个账号必须是对象。',
          );
        }

        final account = rawAccount.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final label = '${account['label'] ?? ''}'.trim();
        final username = '${account['username'] ?? ''}'.trim();
        final password = '${account['password'] ?? ''}';

        if (label.isEmpty) {
          throw FormatException(
            '第 ${siteIndex + 1} 个站点的第 ${accountIndex + 1} 个账号缺少 label。',
          );
        }
        if (username.isEmpty) {
          throw FormatException(
            '第 ${siteIndex + 1} 个站点的第 ${accountIndex + 1} 个账号缺少 username。',
          );
        }
        if (password.isEmpty) {
          throw FormatException(
            '第 ${siteIndex + 1} 个站点的第 ${accountIndex + 1} 个账号缺少 password。',
          );
        }

        accounts.add(
          _UserImportAccount(
            label: label,
            username: username,
            password: password,
          ),
        );
      }

      sites.add(
        _UserImportSite(name: name, domain: domain, accounts: accounts),
      );
    }

    return sites;
  }

  String _userSiteKey(String name, String domain) {
    return '${name.trim().toLowerCase()}::${domain.trim().toLowerCase()}';
  }

  String _userAccountKey(String siteId, String label, String username) {
    return '${siteId.trim()}::${label.trim().toLowerCase()}::${username.trim().toLowerCase()}';
  }

  int _pickImportedSiteColor(String name, String domain) {
    const colors = [0xFF6C8A7A, 0xFF7F8FAF, 0xFFBE8E5D, 0xFF8A6E63, 0xFF5E7DA8];

    final seedSource = '$name|$domain';
    final seed = seedSource.isEmpty
        ? 0
        : seedSource.codeUnits.fold<int>(0, (total, value) => total + value);
    return colors[seed % colors.length];
  }
}
