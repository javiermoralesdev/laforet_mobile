import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laforet_mobile/crypto.dart';

const password = 'my-secure-password';
const emailTyped = '  Javi@Example.COM ';
const plain = 'Dear Diary, hoy escribí mi primer test 🌲';
const expectedAuthSecret =
    '4fc5ef78e98123573a347af2f905a0f83c1bb96befd0a04567a7868de5f9b989';
const referenceEncrypted = 'v1:000102030405060708090a0b:'
    '863fe536625558ae3da4ac275c96742ba2d9a9e6cfd176a55b9c0e9599791240'
    '643deef628b629da9eb6e7ccc7d1b4c5fe6f38c091694991d4cdcebd';

void main() {
  // 600k PBKDF2 iterations: allow plenty of time if native crypto isn't enabled in tests.
  const slow = Timeout(Duration(minutes: 2));

  test('derives the same authSecret as the web app', () async {
    final keys = await deriveKeys(password, emailTyped);
    expect(keys.authSecret, expectedAuthSecret);
  }, timeout: slow);

  test('decrypts a string produced by the reference implementation', () async {
    final keys = await deriveKeys(password, emailTyped);
    expect(await decryptText(referenceEncrypted, keys.encKey), plain);
  }, timeout: slow);

  test('reproduces the reference ciphertext exactly with the same IV', () async {
    final keys = await deriveKeys(password, emailTyped);
    final out = await encryptText(plain, keys.encKey,
        iv: List<int>.generate(12, (i) => i));
    expect(out, referenceEncrypted);
  }, timeout: slow);

  test('email normalization gives identical keys', () async {
    final a = await deriveKeys(password, 'javi@example.com');
    final b = await deriveKeys(password, '  JAVI@example.com');
    expect(a.authSecret, b.authSecret);
  }, timeout: slow);

  test('round trip with a fresh IV each time', () async {
    final keys = await deriveKeys('password', 'x@example.com');
    final a = await encryptText('Identical message', keys.encKey);
    final b = await encryptText('Identical message', keys.encKey);
    expect(a, isNot(b));
    expect(await decryptText(a, keys.encKey), 'Identical message');
  }, timeout: slow);

  test('wrong password fails authentication', () async {
    final good = await deriveKeys('correct-password', 'x@example.com');
    final bad = await deriveKeys('wrong-password', 'x@example.com');
    final enc = await encryptText('hidden', good.encKey);
    await expectLater(decryptText(enc, bad.encKey),
        throwsA(isA<SecretBoxAuthenticationError>()));
  }, timeout: slow);

  test('malformed input is rejected', () async {
    final keys = await deriveKeys('password', 'x@example.com');
    await expectLater(decryptText('nope', keys.encKey), throwsFormatException);
    await expectLater(
        decryptText('000102:abcd', keys.encKey), throwsFormatException); // old format
    await expectLater(
        decryptText('v1:zz:zz', keys.encKey), throwsFormatException);
  }, timeout: slow);
}
