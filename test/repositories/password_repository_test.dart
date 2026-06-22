import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:password_app/models/app_models.dart';
import 'package:password_app/repositories/password_repository.dart';
import 'package:password_app/services/database_service.dart';
import 'package:password_app/services/password_crypto_service.dart';

class _FakePasswordCryptoService extends PasswordCryptoService {
  @override
  Future<PasswordCryptoPayload> encrypt(String plainText) async {
    return PasswordCryptoPayload(
      cipherText: 'enc:$plainText',
      hash: 'hash:$plainText',
    );
  }

  @override
  Future<PasswordDecryptResult> decryptWithMigrationSupport(
    String encodedPayload,
  ) async {
    final plainText = encodedPayload.startsWith('enc:')
        ? encodedPayload.substring(4)
        : encodedPayload;
    return PasswordDecryptResult(plainText: plainText, needsMigration: false);
  }

  @override
  Future<String> decrypt(String encodedPayload) async {
    return encodedPayload.startsWith('enc:')
        ? encodedPayload.substring(4)
        : encodedPayload;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PasswordRepository sync merge', () {
    late PasswordRepository repository;
    late DatabaseService databaseService;
    late String databasePath;

    setUp(() {
      databasePath = path.join(
        Directory.systemTemp.path,
        'password_repository_test_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      databaseService = DatabaseService(databasePath: databasePath);
      repository = PasswordRepository(
        databaseService: databaseService,
        cryptoService: _FakePasswordCryptoService(),
      );
    });

    tearDown(() async {
      await databaseService.close();

      final databaseFile = File(databasePath);
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }

      for (final suffix in ['-wal', '-shm']) {
        final sidecarFile = File('$databasePath$suffix');
        if (await sidecarFile.exists()) {
          await sidecarFile.delete();
        }
      }
    });

    test('merges missing records and keeps newer incoming records', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Local Site',
        'domain': 'local.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await db.insert('accounts', {
        'id': 'account-1',
        'site_id': 'site-1',
        'label': 'Old Label',
        'username': 'old-user',
        'password': 'enc:old-password',
        'password_hash': 'hash:old-password',
        'password_changed_at': '2026-06-12T09:00:00.000Z',
        'updated_at': '2026-06-12T09:00:00.000Z',
      });

      await repository.mergePlainSyncData({
        'sites': [
          {
            'id': 'site-1',
            'name': 'Remote Site',
            'domain': 'remote.dev',
            'colorValue': 2,
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
          {
            'id': 'site-2',
            'name': 'Second Site',
            'domain': 'second.dev',
            'colorValue': 3,
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
        ],
        'accounts': [
          {
            'id': 'account-1',
            'siteId': 'site-1',
            'label': 'New Label',
            'username': 'new-user',
            'password': 'new-password',
            'passwordChangedAt': '2026-06-12T10:00:00.000Z',
            'isDelete': false,
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
          {
            'id': 'account-2',
            'siteId': 'site-2',
            'label': 'Second Account',
            'username': 'second-user',
            'password': 'second-password',
            'passwordChangedAt': '2026-06-12T10:00:00.000Z',
            'isDelete': false,
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
        ],
        'passwordHistory': [
          {
            'id': 'history-1',
            'accountId': 'account-1',
            'accountName': 'New Label',
            'password': 'new-password',
            'createdAt': '2026-06-12T10:00:00.000Z',
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
        ],
        'accountRecycleBin': const [],
      });

      final exported = await repository.exportPlainSyncData();
      final sites = (exported['sites'] as List).cast<Map<String, Object>>();
      final accounts = (exported['accounts'] as List)
          .cast<Map<String, Object>>();
      final history = (exported['passwordHistory'] as List)
          .cast<Map<String, Object>>();

      expect(sites, hasLength(2));
      expect(
        sites.firstWhere((site) => site['id'] == 'site-1')['name'],
        'Remote Site',
      );
      expect(
        accounts.firstWhere((account) => account['id'] == 'account-1')['label'],
        'New Label',
      );
      expect(
        accounts.firstWhere(
          (account) => account['id'] == 'account-2',
        )['siteId'],
        'site-2',
      );
      expect(history.single['accountId'], 'account-1');
    });

    test('merges site records even when name and domain are empty', () async {
      await repository.mergePlainSyncData({
        'sites': [
          {
            'id': 'site-empty',
            'name': '',
            'domain': '',
            'colorValue': 2,
            'updatedAt': '2026-06-12T10:00:00.000Z',
          },
        ],
        'accounts': const [],
        'passwordHistory': const [],
        'accountRecycleBin': const [],
      });

      final exported = await repository.exportPlainSyncData();
      final sites = (exported['sites'] as List).cast<Map<String, Object>>();
      final emptySite = sites.singleWhere((site) => site['id'] == 'site-empty');

      expect(emptySite['name'], '');
      expect(emptySite['domain'], '');
    });

    test(
      'exports visible accounts in simplified user transfer format',
      () async {
        final db = await databaseService.database;
        await db.insert('sites', {
          'id': 'site-1',
          'name': 'GitHub',
          'domain': 'github.com',
          'color_value': 1,
          'is_delete': 0,
          'updated_at': '2026-06-12T09:00:00.000Z',
        });
        await repository.addAccount(
          const AccountDraft(
            siteId: 'site-1',
            label: '主账号',
            username: 'alice',
            password: 'secret',
          ),
        );

        final exported = await repository.exportUserAccountData();
        final sites = (exported['sites'] as List).cast<Map<String, Object>>();
        final site = sites.single;
        final accounts = (site['accounts'] as List).cast<Map<String, Object>>();

        expect(exported['version'], 1);
        expect(site['name'], 'GitHub');
        expect(site['domain'], 'github.com');
        expect(accounts.single['label'], '主账号');
        expect(accounts.single['username'], 'alice');
        expect(accounts.single['password'], 'secret');
      },
    );

    test('imports user transfer data and merges matching accounts', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'GitHub',
        'domain': 'github.com',
        'color_value': 1,
        'is_delete': 0,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await repository.addAccount(
        const AccountDraft(
          siteId: 'site-1',
          label: '主账号',
          username: 'alice',
          password: 'old-secret',
        ),
      );

      final result = await repository.importUserAccountData({
        'version': 1,
        'sites': [
          {
            'name': 'GitHub',
            'domain': 'github.com',
            'accounts': [
              {'label': '主账号', 'username': 'alice', 'password': 'new-secret'},
              {
                'label': '工作账号',
                'username': 'alice.work',
                'password': 'work-secret',
              },
            ],
          },
          {
            'name': 'GitLab',
            'domain': 'gitlab.com',
            'accounts': [
              {'label': '默认账号', 'username': 'bob', 'password': 'bob-secret'},
            ],
          },
        ],
      });

      expect(result.addedSiteCount, 1);
      expect(result.addedAccountCount, 2);
      expect(result.updatedAccountCount, 1);

      final visibleSites = await repository.fetchSites();
      expect(visibleSites, hasLength(2));

      final githubSite = visibleSites.firstWhere(
        (site) => site.name == 'GitHub',
      );
      expect(githubSite.accounts, hasLength(2));
      expect(
        githubSite.accounts
            .firstWhere((account) => account.username == 'alice')
            .password,
        'new-secret',
      );
      expect(
        githubSite.accounts
            .firstWhere((account) => account.username == 'alice.work')
            .password,
        'work-secret',
      );

      final gitlabSite = visibleSites.firstWhere(
        (site) => site.name == 'GitLab',
      );
      expect(gitlabSite.accounts.single.username, 'bob');

      final historyRows = await db.query(
        'password_history',
        where: 'account_name = ?',
        whereArgs: ['主账号'],
      );
      expect(historyRows.length, greaterThanOrEqualTo(2));
    });

    test('writes password history when password changes', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Main Site',
        'domain': 'main.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await repository.addAccount(
        const AccountDraft(
          siteId: 'site-1',
          label: 'Main',
          username: 'user@example.com',
          password: 'first-password',
        ),
      );

      final firstAccount =
          (await repository.exportPlainSyncData())['accounts'] as List;
      final accountId = firstAccount.single['id'] as String;

      await repository.updateAccount(
        accountId,
        const AccountDraft(
          siteId: 'site-1',
          label: 'Main',
          username: 'user@example.com',
          password: 'second-password',
        ),
      );

      final historyRows = await db.query(
        'password_history',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'created_at ASC',
      );

      expect(historyRows, hasLength(2));

      final exported = await repository.exportPlainSyncData();
      final history = (exported['passwordHistory'] as List)
          .cast<Map<String, Object>>();
      final accountHistory =
          history.where((item) => item['accountId'] == accountId).toList()
            ..sort(
              (left, right) => (left['createdAt'] as String).compareTo(
                right['createdAt'] as String,
              ),
            );

      expect(accountHistory, hasLength(2));
      expect(accountHistory.first['password'], 'first-password');
      expect(accountHistory.last['password'], 'second-password');
    });

    test('soft deletes account and writes recycle bin entry', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Main Site',
        'domain': 'main.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await repository.addAccount(
        const AccountDraft(
          siteId: 'site-1',
          label: 'Trash Me',
          username: 'trash@example.com',
          password: 'trash-password',
        ),
      );

      final exportBeforeDelete = await repository.exportPlainSyncData();
      final accountId =
          ((exportBeforeDelete['accounts'] as List).single)['id'] as String;

      await repository.deleteAccount(accountId);

      final visibleSites = await repository.fetchSites();
      expect(visibleSites.single.accounts, isEmpty);

      final deletedRow = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      expect(deletedRow.single['is_delete'], 1);

      final recycleRows = await db.query(
        'account_recycle_bin',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      expect(recycleRows, hasLength(1));

      final exportAfterDelete = await repository.exportPlainSyncData();
      final accounts = (exportAfterDelete['accounts'] as List)
          .cast<Map<String, Object>>();
      final recycleBin = (exportAfterDelete['accountRecycleBin'] as List)
          .cast<Map<String, Object>>();

      expect(
        accounts.firstWhere(
          (account) => account['id'] == accountId,
        )['isDelete'],
        true,
      );
      expect(recycleBin.single['accountId'], accountId);
      expect(recycleBin.single['siteName'], 'Main Site');
    });

    test(
      'soft deletes site with child accounts and exports deleted site state',
      () async {
        final db = await databaseService.database;
        await db.insert('sites', {
          'id': 'site-1',
          'name': 'Main Site',
          'domain': 'main.dev',
          'color_value': 1,
          'updated_at': '2026-06-12T09:00:00.000Z',
        });
        await repository.addAccount(
          const AccountDraft(
            siteId: 'site-1',
            label: 'Trash Me Too',
            username: 'trash2@example.com',
            password: 'trash-password-2',
          ),
        );

        await repository.deleteSite('site-1');

        expect(await repository.fetchSites(), isEmpty);

        final deletedSite = await db.query(
          'sites',
          where: 'id = ?',
          whereArgs: ['site-1'],
          limit: 1,
        );
        expect(deletedSite.single['is_delete'], 1);

        final deletedAccount = await db.query('accounts');
        expect(deletedAccount.single['is_delete'], 1);

        final recycleRows = await db.query('account_recycle_bin');
        expect(recycleRows.single['site_name'], 'Main Site');

        final exported = await repository.exportPlainSyncData();
        final sites = (exported['sites'] as List).cast<Map<String, Object>>();
        final accounts = (exported['accounts'] as List)
            .cast<Map<String, Object>>();
        final recycleBin = (exported['accountRecycleBin'] as List)
            .cast<Map<String, Object>>();

        expect(sites.single['isDelete'], true);
        expect(accounts.single['isDelete'], true);
        expect(recycleBin.single['siteName'], 'Main Site');
      },
    );

    test('merges newer deleted account state from peer', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Main Site',
        'domain': 'main.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await db.insert('accounts', {
        'id': 'account-1',
        'site_id': 'site-1',
        'label': 'Keep?',
        'username': 'user@example.com',
        'password': 'enc:password',
        'password_hash': 'hash:password',
        'password_changed_at': '2026-06-12T09:00:00.000Z',
        'is_delete': 0,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });

      await repository.mergePlainSyncData({
        'sites': const [],
        'accounts': [
          {
            'id': 'account-1',
            'siteId': 'site-1',
            'label': 'Keep?',
            'username': 'user@example.com',
            'password': 'password',
            'passwordChangedAt': '2026-06-12T09:00:00.000Z',
            'isDelete': true,
            'updatedAt': '2026-06-12T11:00:00.000Z',
          },
        ],
        'passwordHistory': const [],
        'accountRecycleBin': [
          {
            'id': 'recycle-1',
            'accountId': 'account-1',
            'siteId': 'site-1',
            'siteName': 'Main Site',
            'accountName': 'Keep?',
            'username': 'user@example.com',
            'password': 'password',
            'passwordChangedAt': '2026-06-12T09:00:00.000Z',
            'deletedAt': '2026-06-12T11:00:00.000Z',
            'updatedAt': '2026-06-12T11:00:00.000Z',
          },
        ],
      });

      final visibleSites = await repository.fetchSites();
      expect(visibleSites.single.accounts, isEmpty);

      final deletedRow = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['account-1'],
        limit: 1,
      );
      expect(deletedRow.single['is_delete'], 1);

      final recycleRows = await db.query(
        'account_recycle_bin',
        where: 'account_id = ?',
        whereArgs: ['account-1'],
      );
      expect(recycleRows, hasLength(1));
      expect(recycleRows.single['site_name'], 'Main Site');
    });

    test('restores deleted account and reactivates deleted site', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Main Site',
        'domain': 'main.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });
      await repository.addAccount(
        const AccountDraft(
          siteId: 'site-1',
          label: 'Restore Me',
          username: 'restore@example.com',
          password: 'restore-password',
        ),
      );

      final exportBeforeDelete = await repository.exportPlainSyncData();
      final accountId =
          ((exportBeforeDelete['accounts'] as List).single)['id'] as String;

      await repository.deleteSite('site-1');
      await repository.deleteAccount(accountId);
      expect(await repository.fetchDeletedAccounts(), hasLength(1));

      await repository.restoreAccount(accountId);

      final visibleSites = await repository.fetchSites();
      expect(visibleSites.single.accounts, hasLength(1));
      expect(visibleSites.single.accounts.single.id, accountId);
      expect(await repository.fetchDeletedAccounts(), isEmpty);

      final restoredRow = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      expect(restoredRow.single['is_delete'], 0);

      final restoredSite = await db.query(
        'sites',
        where: 'id = ?',
        whereArgs: ['site-1'],
        limit: 1,
      );
      expect(restoredSite.single['is_delete'], 0);
    });

    test('merges newer deleted site state from peer', () async {
      final db = await databaseService.database;
      await db.insert('sites', {
        'id': 'site-1',
        'name': 'Main Site',
        'domain': 'main.dev',
        'color_value': 1,
        'updated_at': '2026-06-12T09:00:00.000Z',
      });

      await repository.mergePlainSyncData({
        'sites': [
          {
            'id': 'site-1',
            'name': 'Main Site',
            'domain': 'main.dev',
            'colorValue': 1,
            'isDelete': true,
            'updatedAt': '2026-06-12T11:00:00.000Z',
          },
        ],
        'accounts': const [],
        'passwordHistory': const [],
        'accountRecycleBin': const [],
      });

      expect(await repository.fetchSites(), isEmpty);

      final deletedSite = await db.query(
        'sites',
        where: 'id = ?',
        whereArgs: ['site-1'],
        limit: 1,
      );
      expect(deletedSite.single['is_delete'], 1);
    });
  });
}
