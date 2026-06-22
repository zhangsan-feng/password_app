part of 'password_repository.dart';

extension PasswordRepositoryMemos on PasswordRepository {
  Future<List<MemoEntry>> fetchMemos() async {
    final db = await _databaseService.database;
    final rows = await db.query('memos', orderBy: 'updated_at DESC, id DESC');

    return rows
        .map(
          (row) => MemoEntry(
            id: row['id'] as int,
            content: row['content'] as String,
            updatedAt:
                DateTime.tryParse(row['updated_at'] as String)?.toLocal() ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> addMemo(MemoDraft draft) async {
    final db = await _databaseService.database;
    await db.insert('memos', {
      'content': draft.content.trim(),
      'updated_at': _nowIso(),
    });
  }

  Future<void> updateMemo(int memoId, MemoDraft draft) async {
    final db = await _databaseService.database;
    await db.update(
      'memos',
      {'content': draft.content.trim(), 'updated_at': _nowIso()},
      where: 'id = ?',
      whereArgs: [memoId],
    );
  }

  Future<void> deleteMemo(int memoId) async {
    final db = await _databaseService.database;
    await db.delete('memos', where: 'id = ?', whereArgs: [memoId]);
  }
}
