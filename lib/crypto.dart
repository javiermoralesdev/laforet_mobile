import 'dart:convert';
import 'dart:isolate';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';

// Keep these in sync with crypto.ts.
const kdfIterations = 600000;
const _saltPrefix = 'laforet:v1:';
const _infoAuth = 'laforet-auth-v1';
const _infoEnc = 'laforet-enc-v1';
const _format = 'v1';
const _ivLength = 12; // AES-GCM nonce, bytes
const _tagLength = 16; // AES-GCM tag, bytes

final _pbkdf2 = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: kdfIterations,
  bits: 256,
);
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
final _aes = AesGcm.with256bits(); // 12-byte nonce, 16-byte tag

/// The salt must match on every device, so normalize the email identically.
String normalizeEmail(String email) => email.trim().toLowerCase();

class DerivedKeys {
  /// 64-char hex string: sent to PocketBase as the account "password".
  final String authSecret;

  /// AES-GCM key for the diary. Never sent anywhere.
  final SecretKey encKey;

  const DerivedKeys(this.authSecret, this.encKey);
}

/// 1. Derive the login secret and the encryption key from the password.
Future<DerivedKeys> deriveKeys(String password, String email) async {
  final master = await _pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: utf8.encode('$_saltPrefix${normalizeEmail(email)}'),
  );

  final hkdfSalt = List<int>.filled(32, 0);
  final authKey = await _hkdf.deriveKey(
    secretKey: master,
    nonce: hkdfSalt,
    info: utf8.encode(_infoAuth),
  );
  final encKey = await _hkdf.deriveKey(
    secretKey: master,
    nonce: hkdfSalt,
    info: utf8.encode(_infoEnc),
  );

  return DerivedKeys(hex.encode(await authKey.extractBytes()), encKey);
}

Future<DerivedKeys> deriveKeysInBackground(String password, String email) async {
  final (authSecret, encBytes) = await Isolate.run(() async {
    final keys = await deriveKeys(password, email);
    return (keys.authSecret, await keys.encKey.extractBytes());
  });
  return DerivedKeys(authSecret, SecretKey(encBytes));
}

/// 2. Encrypt text -> "v1:ivHex:cipherHex" (cipherHex = ciphertext followed by the tag).
/// [iv] exists only so tests can reproduce a known vector.
Future<String> encryptText(String text, SecretKey key, {List<int>? iv}) async {
  final box = await _aes.encrypt(
    utf8.encode(text),
    secretKey: key,
    nonce: iv ?? _aes.newNonce(),
  );
  final combined = [...box.cipherText, ...box.mac.bytes];
  return '$_format:${hex.encode(box.nonce)}:${hex.encode(combined)}';
}

/// 3. Decrypt "v1:ivHex:cipherHex". Throws FormatException on bad input and
/// SecretBoxAuthenticationError on a wrong key or tampered data.
Future<String> decryptText(String encryptedStr, SecretKey key) async {
  final parts = encryptedStr.split(':');
  if (parts.length != 3 || parts[0] != _format) {
    throw const FormatException('Invalid encrypted format');
  }

  final List<int> iv;
  final List<int> data;
  try {
    iv = hex.decode(parts[1]);
    data = hex.decode(parts[2]);
  } on FormatException {
    throw const FormatException('Invalid encrypted format');
  }
  if (iv.length != _ivLength || data.length < _tagLength) {
    throw const FormatException('Invalid encrypted format');
  }

  final box = SecretBox(
    data.sublist(0, data.length - _tagLength),
    nonce: iv,
    mac: Mac(data.sublist(data.length - _tagLength)),
  );
  return utf8.decode(await _aes.decrypt(box, secretKey: key));
}
