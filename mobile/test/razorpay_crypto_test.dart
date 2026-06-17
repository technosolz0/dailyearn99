import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  test(
    'Verify backend AES-CBC-PKCS7 ciphertext decryption symmetry in Flutter',
    () {
      const String ciphertext =
          "edz4yhJIB8FexuiKA6xxFEMmIJ3O0Fm8cyWfKIbwYazKt2WL8oTW0X/jnt6lxN7om4sIKhcemLUQoXrXu+dg+yOE6p37eaFiIO4vkDHc+K+qV4CeaSFenxIB+BAS6hOr";
      const String ivB64 = "eajtW13FSwD/QSgdQkb0Kg==";

      // Key is derived from first 32 characters of default settings.SECRET_KEY
      final key = encrypt.Key.fromUtf8("dailyearn99_super_secret_signing");
      final iv = encrypt.IV.fromBase64(ivB64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final decrypted = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(ciphertext),
        iv: iv,
      );

      final Map<String, dynamic> payload =
          json.decode(decrypted) as Map<String, dynamic>;

      expect(payload['order_id'], equals('order_test12345'));
      expect(payload['key_id'], equals('rzp_test_mockkey12345'));
      expect(payload['amount'], equals(250.0));
      print('Decrypted payload matches successfully: $payload');
    },
  );
}
