import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PasswordCryptoPayload {
  const PasswordCryptoPayload({required this.cipherText, required this.hash});

  final String cipherText;
  final String hash;
}

class PasswordDecryptResult {
  const PasswordDecryptResult({
    required this.plainText,
    required this.needsMigration,
  });

  final String plainText;
  final bool needsMigration;
}

class PasswordCryptoService {
  PasswordCryptoService() : _algorithm = AesGcm.with256bits();

  static const _legacySecretKeyBytes = <int>[
    0x54,
    0x68,
    0x69,
    0x73,
    0x49,
    0x73,
    0x41,
    0x44,
    0x65,
    0x6d,
    0x6f,
    0x4b,
    0x65,
    0x79,
    0x46,
    0x6f,
    0x72,
    0x50,
    0x61,
    0x73,
    0x73,
    0x56,
    0x61,
    0x75,
    0x6c,
    0x74,
    0x32,
    0x30,
    0x32,
    0x36,
    0x21,
    0x3f,
  ];

  final AesGcm _algorithm;
  SecretKey? _secretKey;
  String? _unlockPassword;

  Future<SecretKey> get _resolvedSecretKey async {
    if (_secretKey != null) {
      return _secretKey!;
    }

    final keyRecord = await _loadOrCreateKeyRecord();
    if (keyRecord.isPasswordProtected) {
      throw StateError('Vault is locked.');
    }

    _secretKey = SecretKey(base64Decode(keyRecord.plainKey!));
    return _secretKey!;
  }

  Future<PasswordCryptoPayload> encrypt(String plainText) async {
    return _encryptWithKey(plainText, await _resolvedSecretKey);
  }

  Future<PasswordCryptoPayload> encryptWithSecretKey(
    String plainText,
    SecretKey secretKey,
  ) async {
    return _encryptWithKey(plainText, secretKey);
  }

  Future<String> decrypt(String encodedPayload) async {
    final result = await decryptWithMigrationSupport(encodedPayload);
    return result.plainText;
  }

  Future<PasswordDecryptResult> decryptWithMigrationSupport(
    String encodedPayload,
  ) async {
    try {
      final plainText = await _decryptWithKey(
        encodedPayload,
        await _resolvedSecretKey,
      );
      return PasswordDecryptResult(plainText: plainText, needsMigration: false);
    } catch (_) {
      final legacyPlainText = await _tryDecryptWithLegacyKey(encodedPayload);
      if (legacyPlainText != null) {
        return PasswordDecryptResult(
          plainText: legacyPlainText,
          needsMigration: true,
        );
      }

      final plainText = _tryDecodePlainText(encodedPayload);
      if (plainText != null) {
        return PasswordDecryptResult(
          plainText: plainText,
          needsMigration: true,
        );
      }

      rethrow;
    }
  }

  String hash(String plainText) {
    return sha256.convert(utf8.encode(plainText)).toString();
  }

  Future<bool> requiresUnlock() async {
    final keyRecord = await _loadOrCreateKeyRecord();
    return keyRecord.isPasswordProtected && _secretKey == null;
  }

  Future<void> unlockWithPassword(String password) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw StateError('Password is empty.');
    }

    final keyRecord = await _loadOrCreateKeyRecord();
    if (!keyRecord.isPasswordProtected) {
      _secretKey = SecretKey(base64Decode(keyRecord.plainKey!));
      return;
    }

    final wrappingKey = _deriveKeyFromPassword(
      normalizedPassword,
      base64Decode(keyRecord.salt!),
    );
    final plainKey = await _decryptWithKey(
      keyRecord.encryptedKey!,
      wrappingKey,
    );
    _secretKey = SecretKey(base64Decode(plainKey));
    _unlockPassword = normalizedPassword;
  }

  Future<SecretKey> generateSecretKey() async {
    final random = Random.secure();
    return SecretKey(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<void> storePasswordProtectedKey({
    required SecretKey secretKey,
    required String password,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.isEmpty) {
      throw StateError('Password is empty.');
    }

    final secretKeyBytes = await secretKey.extractBytes();
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final wrappingKey = _deriveKeyFromPassword(normalizedPassword, salt);
    final protectedPayload = await _encryptWithKey(
      base64Encode(secretKeyBytes),
      wrappingKey,
    );

    await _writeKeyRecord(
      _KeyRecord.protected(
        salt: base64Encode(salt),
        encryptedKey: protectedPayload.cipherText,
      ),
    );

    _unlockPassword = normalizedPassword;
  }

  Future<void> activateSecretKey(SecretKey secretKey) async {
    _secretKey = secretKey;
  }

  Future<void> persistSecretKey(SecretKey secretKey) async {
    final keyRecord = await _loadOrCreateKeyRecord();

    if (keyRecord.isPasswordProtected) {
      final password = _unlockPassword;
      if (password == null || password.isEmpty) {
        throw StateError('Vault password is unavailable.');
      }

      await storePasswordProtectedKey(secretKey: secretKey, password: password);
      return;
    }

    final keyBytes = await secretKey.extractBytes();
    await _writeKeyRecord(_KeyRecord.plain(base64Encode(keyBytes)));
  }

  Future<PasswordCryptoPayload> _encryptWithKey(
    String plainText,
    SecretKey secretKey,
  ) async {
    final plainBytes = utf8.encode(plainText);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final payloadBytes = <int>[
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];

    return PasswordCryptoPayload(
      cipherText: base64Encode(payloadBytes),
      hash: sha256.convert(plainBytes).toString(),
    );
  }

  Future<String> _decryptWithKey(
    String encodedPayload,
    SecretKey secretKey,
  ) async {
    final payloadBytes = base64Decode(encodedPayload);
    final nonce = payloadBytes.sublist(0, 12);
    final macBytes = payloadBytes.sublist(12, 28);
    final cipherBytes = payloadBytes.sublist(28);

    final clearBytes = await _algorithm.decrypt(
      SecretBox(cipherBytes, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );

    return utf8.decode(clearBytes);
  }

  Future<String?> _tryDecryptWithLegacyKey(String encodedPayload) async {
    try {
      final legacyKey = SecretKey(_legacySecretKeyBytes);
      return await _decryptWithKey(encodedPayload, legacyKey);
    } catch (_) {
      return null;
    }
  }

  String? _tryDecodePlainText(String value) {
    try {
      final decoded = base64Decode(value);
      if (decoded.length < 28) {
        return value;
      }
    } on FormatException {
      return value;
    }

    return null;
  }

  SecretKey _deriveKeyFromPassword(String password, List<int> salt) {
    var bytes = <int>[...utf8.encode(password), ...salt];
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return SecretKey(bytes);
  }

  Future<_KeyRecord> _loadOrCreateKeyRecord() async {
    final directory = await getApplicationDocumentsDirectory();
    final keyRecordFile = File(
      path.join(directory.path, '.vault_keyring.json'),
    );
    final legacyKeyFile = File(path.join(directory.path, '.vault_aes_key'));

    if (await keyRecordFile.exists()) {
      final stored = await keyRecordFile.readAsString();
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return _KeyRecord.fromJson(decoded);
    }

    if (await legacyKeyFile.exists()) {
      final stored = await legacyKeyFile.readAsString();
      final record = _KeyRecord.plain(stored.trim());
      await _writeKeyRecord(record);
      return record;
    }

    final secretKey = await generateSecretKey();
    final keyBytes = await secretKey.extractBytes();
    final record = _KeyRecord.plain(base64Encode(keyBytes));
    await _writeKeyRecord(record);
    return record;
  }

  Future<void> _writeKeyRecord(_KeyRecord keyRecord) async {
    final directory = await getApplicationDocumentsDirectory();
    final keyRecordFile = File(
      path.join(directory.path, '.vault_keyring.json'),
    );
    await keyRecordFile.writeAsString(
      jsonEncode(keyRecord.toJson()),
      flush: true,
    );
  }
}

class _KeyRecord {
  const _KeyRecord._({
    required this.mode,
    this.plainKey,
    this.salt,
    this.encryptedKey,
  });

  factory _KeyRecord.plain(String key) =>
      _KeyRecord._(mode: 'plain', plainKey: key);

  factory _KeyRecord.protected({
    required String salt,
    required String encryptedKey,
  }) => _KeyRecord._(mode: 'protected', salt: salt, encryptedKey: encryptedKey);

  factory _KeyRecord.fromJson(Map<String, dynamic> json) {
    final mode = '${json['mode'] ?? 'plain'}';
    if (mode == 'protected') {
      return _KeyRecord.protected(
        salt: '${json['salt'] ?? ''}',
        encryptedKey: '${json['encryptedKey'] ?? ''}',
      );
    }

    return _KeyRecord.plain('${json['key'] ?? ''}');
  }

  final String mode;
  final String? plainKey;
  final String? salt;
  final String? encryptedKey;

  bool get isPasswordProtected => mode == 'protected';

  Map<String, Object> toJson() {
    if (isPasswordProtected) {
      return {
        'version': 1,
        'mode': mode,
        'salt': salt!,
        'encryptedKey': encryptedKey!,
      };
    }

    return {'version': 1, 'mode': mode, 'key': plainKey!};
  }
}
