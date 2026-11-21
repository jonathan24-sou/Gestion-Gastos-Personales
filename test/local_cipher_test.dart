import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_personales/services/local_cipher.dart';

void main() {
  late _MemoryStorage storage;
  late LocalCipher cipher;

  setUp(() {
    storage = _MemoryStorage();
    cipher = LocalCipher(storage);
  });

  test(
    'encrypts values and decrypts them with the stored device key',
    () async {
      const clearText = 'Compra de supermercado';
      final encrypted = await cipher.encrypt(clearText);

      expect(encrypted, isNot(contains(clearText)));
      expect(await cipher.decrypt(encrypted), clearText);
      expect(await LocalCipher(storage).decrypt(encrypted), clearText);
    },
  );

  test(
    'rejects altered ciphertext instead of returning corrupted data',
    () async {
      final encrypted = await cipher.encrypt('125.50');
      final bytes = base64Decode(encrypted);
      bytes[bytes.length - 1] ^= 1;

      expect(() => cipher.decrypt(base64Encode(bytes)), throwsA(anything));
    },
  );

  test('encrypts receipt bytes for storage', () async {
    final encrypted = await cipher.encryptBytes([0, 1, 2, 255]);

    expect(await cipher.decryptBytes(encrypted), [0, 1, 2, 255]);
  });
}

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}
