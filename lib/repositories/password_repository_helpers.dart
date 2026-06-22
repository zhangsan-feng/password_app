part of 'password_repository.dart';

extension PasswordRepositoryHelpers on PasswordRepository {
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
    required String siteName,
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
      'site_name': siteName,
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

  bool _readBoolFlag(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }

  Future<String> _findSiteNameById(DatabaseExecutor db, String siteId) async {
    final rows = await db.query(
      'sites',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [siteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return '';
    }
    return rows.first['name'] as String? ?? '';
  }
}
