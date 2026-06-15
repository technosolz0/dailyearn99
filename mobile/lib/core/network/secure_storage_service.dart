import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dailyearn99/core/models/user_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:device_info_plus/device_info_plus.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  enc.Key? _cachedKey;
  enc.IV? _cachedIv;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  Future<_WebCipher> _getWebCipher() async {
    if (_cachedKey != null && _cachedIv != null) {
      return _WebCipher(_cachedKey!, _cachedIv!);
    }

    String fingerprint = 'DailyEarn99SecureWebKeyHashSecretPepperSalt';
    if (kIsWeb) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final webInfo = await deviceInfo.webBrowserInfo;
        fingerprint += '${webInfo.userAgent ?? ''}${webInfo.vendor ?? ''}${webInfo.language ?? ''}';
      } catch (e) {
        fingerprint += 'FallbackFingerprint';
      }
    }

    final keyBytes = sha256.convert(utf8.encode(fingerprint)).bytes;
    final ivBytes = md5.convert(utf8.encode(fingerprint)).bytes;

    _cachedKey = enc.Key(Uint8List.fromList(keyBytes));
    _cachedIv = enc.IV(Uint8List.fromList(ivBytes));

    return _WebCipher(_cachedKey!, _cachedIv!);
  }

  Future<String?> _encryptWebValue(String? value) async {
    if (value == null) return null;
    if (!kIsWeb) return value;
    final cipher = await _getWebCipher();
    final encrypter = enc.Encrypter(enc.AES(cipher.key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(value, iv: cipher.iv);
    return encrypted.base64;
  }

  Future<String?> _decryptWebValue(String? base64Value) async {
    if (base64Value == null) return null;
    if (!kIsWeb) return base64Value;
    try {
      final cipher = await _getWebCipher();
      final encrypter = enc.Encrypter(enc.AES(cipher.key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(base64Value, iv: cipher.iv);
    } catch (e) {
      print("Error decrypting secure web storage value: $e");
      return null;
    }
  }

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'cached_user';
  static const String _lastFcmUpdateKey = 'last_fcm_update';

  Future<void> saveLastFcmUpdateDate(String date) async {
    final encVal = await _encryptWebValue(date);
    await _storage.write(key: _lastFcmUpdateKey, value: encVal);
  }

  Future<String?> getLastFcmUpdateDate() async {
    final encVal = await _storage.read(key: _lastFcmUpdateKey);
    return await _decryptWebValue(encVal);
  }

  Future<void> saveAccessToken(String token) async {
    final encVal = await _encryptWebValue(token);
    await _storage.write(key: _accessTokenKey, value: encVal);
  }

  Future<String?> getAccessToken() async {
    final encVal = await _storage.read(key: _accessTokenKey);
    return await _decryptWebValue(encVal);
  }

  Future<void> saveRefreshToken(String token) async {
    final encVal = await _encryptWebValue(token);
    await _storage.write(key: _refreshTokenKey, value: encVal);
  }

  Future<String?> getRefreshToken() async {
    final encVal = await _storage.read(key: _refreshTokenKey);
    return await _decryptWebValue(encVal);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _lastFcmUpdateKey);
  }

  Future<void> saveUser(UserModel user) async {
    final val = jsonEncode(user.toJson());
    final encVal = await _encryptWebValue(val);
    await _storage.write(key: _userKey, value: encVal);
  }

  Future<UserModel?> getUser() async {
    final encVal = await _storage.read(key: _userKey);
    final userStr = await _decryptWebValue(encVal);
    if (userStr != null) {
      try {
        return UserModel.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await _storage.delete(key: _userKey);
  }
}

class _WebCipher {
  final enc.Key key;
  final enc.IV iv;
  _WebCipher(this.key, this.iv);
}
