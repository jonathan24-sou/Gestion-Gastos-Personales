import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalCipher {
  LocalCipher(this._storage);

  static const _storageKey = 'local_data_encryption_key_v1';
  static final _algorithm = AesGcm.with256bits();
  final FlutterSecureStorage _storage;
  List<int>? _key;

  Future<List<int>> _encryptionKey() async {
    if (_key != null) return _key!;
    final storedKey = await _storage.read(key: _storageKey);
    if (storedKey != null) {
      _key = base64Decode(storedKey);
      if (_key!.length != 32) {
        throw StateError('La clave local almacenada no es válida.');
      }
      return _key!;
    }

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: _storageKey, value: base64Encode(key));
    _key = key;
    return key;
  }

  Future<String> encrypt(String value) async {
    return encryptBytes(utf8.encode(value));
  }

  Future<String> encryptBytes(List<int> value) async {
    final secretBox = await _algorithm.encrypt(
      value,
      secretKey: SecretKey(await _encryptionKey()),
    );
    return base64Encode([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  Future<String> decrypt(String value) async {
    return utf8.decode(await decryptBytes(value));
  }

  Future<List<int>> decryptBytes(String value) async {
    final bytes = base64Decode(value);
    if (bytes.length < 28) {
      throw const FormatException('El dato cifrado está incompleto.');
    }
    final secretBox = SecretBox(
      bytes.sublist(12, bytes.length - 16),
      nonce: bytes.sublist(0, 12),
      mac: Mac(bytes.sublist(bytes.length - 16)),
    );
    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(await _encryptionKey()),
    );
    return clearBytes;
  }
}
