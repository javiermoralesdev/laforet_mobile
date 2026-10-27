// lib/entries_route.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laforet_mobile/screens/list_entries.dart';
import 'package:laforet_mobile/screens/login_screen.dart';
import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';

/// Shows the entries when the user is signed in AND the vault key is in memory,
/// otherwise the login screen. After an app restart the saved token is still valid
/// but the key is gone, so the user sees the login screen once to "unlock".
class EntriesRoute extends ConsumerWidget {
  const EntriesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final key = ref.watch(vaultKeyProvider);

    if (!signedIn || key == null) return const LoginScreen();
    return const ListEntries();
  }
}


