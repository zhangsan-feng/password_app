import 'package:flutter_test/flutter_test.dart';
import 'package:password_app/models/app_models.dart';
import 'package:password_app/repositories/password_repository.dart';
import 'package:password_app/services/database_service.dart';
import 'package:password_app/services/password_crypto_service.dart';
import 'package:sqflite/sqflite.dart';

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

    setUp(() {
      databaseService = DatabaseService(databasePath: inMemoryDatabasePath);
      repository = PasswordRepository(
        databaseService: databaseService,
        cryptoService: _FakePasswordCryptoService(),
      );
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
      final accountHistory = history
          .where((item) => item['accountId'] == accountId)
          .toList();

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
    });

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
    });

    test('restores deleted account back to active list', () async {
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
    });
  });
}
