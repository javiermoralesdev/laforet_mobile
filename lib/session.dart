// lib/session.dart
//
// Login state + vault key + the decrypted entries list.
// Assumes pbProvider / backendUrlProvider live in pocketbase.dart (as in your project).

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laforet_mobile/crypto.dart';
import 'package:laforet_mobile/pocketbase.dart';

Future<T> timed<T>(String label, Future<T> Function() f) async {
  final sw = Stopwatch()..start();
  final r = await f();
  debugPrint('$label: ${sw.elapsedMilliseconds} ms');
  return r;
}

/// The AES key derived from the password. Lives in memory only (like the web app).
class VaultKey extends Notifier<SecretKey?> {
  @override
  SecretKey? build() => null;

  void set(SecretKey? key) => state = key;
}

final vaultKeyProvider = NotifierProvider<VaultKey, SecretKey?>(VaultKey.new);

/// true while PocketBase holds a valid (non-expired) login.
/// authStore.isValid on its own is not reactive, so re-emit whenever the store changes.
final signedInProvider = StreamProvider<bool>((ref) async* {
  final store = ref.watch(pbProvider).authStore;
  yield store.isValid;
  await for (final _ in store.onChange) {
    yield store.isValid;
  }
});

/// Clears the saved login AND forgets the key.
void logout(WidgetRef ref) {
  ref.read(pbProvider).authStore.clear();
  ref.read(vaultKeyProvider.notifier).set(null);
}

class EntrySummary {
  final String id;
  final String title;
  final DateTime created;
  final bool undecryptable;

  const EntrySummary(this.id, this.title, this.created) : undecryptable = false;
  const EntrySummary.undecryptable(this.id, this.created)
    : title = '',
      undecryptable = true;
}

class EntryDetails {
  final String id;
  final String title;
  final DateTime created;
  final String body;
  final bool undecryptable;

  const EntryDetails(this.id, this.title, this.created, this.body)
    : undecryptable = false;
  const EntryDetails.undecryptable(this.id, this.created)
    : title = '',
      body = '',
      undecryptable = true;
}

/// Fetches the entries and decrypts them. One broken entry doesn't break the list.
/// ADJUST the collection and field names ('entries', 'title', 'content') to your schema.
final entriesProvider = FutureProvider<List<EntrySummary>>((ref) async {
  final pb = ref.watch(pbProvider);
  final key = ref.watch(vaultKeyProvider);
  if (key == null) return [];

  final records = await timed(
    "fetch",
    () => pb
        .collection('entries')
        .getFullList(sort: '-created', fields: 'id,title,created'),
  );

  final entries = <EntrySummary>[];
  final sw = Stopwatch()..start();
  for (final r in records) {
    final created = DateTime.parse(r.getStringValue('created')).toLocal();
    try {
      entries.add(
        EntrySummary(
          r.id,
          await timed(
            "Decrypting ${r.id}",
            () => decryptText(r.getStringValue('title'), key),
          ),
          created,
        ),
      );
    } catch (_) {
      entries.add(EntrySummary.undecryptable(r.id, created));
    }
  }
  debugPrint(
    'decrypt: ${sw.elapsedMicroseconds} µs for ${entries.length} entries '
    '(${entries.where((e) => e.undecryptable).length} failed)',
  );
  return entries;
});

final entryProvider = FutureProvider.family<EntryDetails?, String>((
  ref,
  id,
) async {
  final pb = ref.watch(pbProvider);
  final key = ref.watch(vaultKeyProvider);

  final record = await pb.collection("entries").getOne(id);

  if (key == null) return null;

  final created = DateTime.parse(record.getStringValue("created")).toLocal();

  try {
    final results = await Future.wait([
      decryptText(record.getStringValue("title"), key),
      decryptText(record.getStringValue("body"), key),
    ]);

    return EntryDetails(id, results[0], created, results[1]);
  } catch (_) {
    return EntryDetails.undecryptable(id, created);
  }
});
