import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class EntryView extends ConsumerWidget {
  final String entryId;
  const EntryView({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryProvider(entryId));

    return Scaffold(
      appBar: AppBar(title: const Text('Read Entry')),
      body: entryAsync.when(
        data: (entry) {
          if (entry == null) return const Text("Vault locked.");

          // 1. Wrap the entire scrollable area in a native SelectionArea
          return SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.created.toString(),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const Divider(height: 32),

                  MarkdownBody(
                    data: entry.body,
                    selectable: false,
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.6),
                      h2: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
