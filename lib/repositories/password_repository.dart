import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/password_crypto_service.dart';
part 'password_repository_helpers.dart';
part 'password_repository_memos.dart';
part 'password_repository_mutations.dart';
part 'password_repository_sync.dart';
part 'password_repository_user_transfer.dart';

class PasswordRepository {
  PasswordRepository({
    DatabaseService? databaseService,
    PasswordCryptoService? cryptoService,
  }) : _databaseService = databaseService ?? DatabaseService.instance,
       _cryptoService = cryptoService ?? PasswordCryptoService();

  final DatabaseService _databaseService;
  final PasswordCryptoService _cryptoService;
  final Random _random = Random.secure();
  static const int _defaultSiteColorValue = 0xFF6C8A7A;

  Future<void> initialize() async {
    await _databaseService.database;
  }

  Future<List<WebsiteEntry>> fetchSites({String query = ''}) async {
    final db = await _databaseService.database;
    final normalizedQuery = query.trim().toLowerCase();

    final siteRows = await db.query(
      'sites',
      where: 'is_delete = 0',
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
}
