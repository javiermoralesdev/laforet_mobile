import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:laforet_mobile/components/entry_card.dart';
import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';

class ListEntries extends ConsumerWidget {
  const ListEntries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => logout(ref),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load entries:\n$e')),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(entriesProvider.future),
          child: list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No entries yet')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => EntryCard(
                    key: ValueKey(list[i].id),
                    entry: list[i],
                    onEdit: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Editor coming soon'),
                      ), // TODO: open the editor
                    ),
                    onDelete: () =>
                        confirmAndDeleteEntry(context, ref, list[i]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push("/write"),
        child: Icon(Icons.add),
      ),
    );
  }
}
