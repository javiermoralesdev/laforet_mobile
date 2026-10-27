import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';


final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

final backendUrlProvider = StateProvider<String?>(
      (ref) => ref.read(prefsProvider).getString('laforet_url'),
);

final pbProvider = Provider<PocketBase>((ref) {
  final url = ref.watch(backendUrlProvider);
  final prefs = ref.read(prefsProvider);
  return PocketBase(
    url ?? 'http://localhost',
    authStore: AsyncAuthStore(
      save: (data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    ),
  );
});

// Call this when the user submits a server address
Future<void> changeBackend(WidgetRef ref, String url) async {
  final prefs = ref.read(prefsProvider);
  await prefs.remove('pb_auth'); // the old server's login is useless
  await prefs.setString('laforet_url', url.trim());
  ref.read(backendUrlProvider.notifier).state = url.trim(); // rebuilds pbProvider
}