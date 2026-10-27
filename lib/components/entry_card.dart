// lib/entry_card.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:laforet_mobile/pocketbase.dart';
import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String formatEntryDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year}  ${_two(d.hour)}:${_two(d.minute)}';

/// One row of the entries list: title + timestamp on the left, edit/delete on the right.
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final EntrySummary entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        context.push("/entry?id=${entry.id}");
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.undecryptable
                          ? '⚠ Could not decrypt this entry'
                          : entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatEntryDate(entry.created),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Can't edit what we can't decrypt, but deleting it is still allowed.
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: entry.undecryptable ? null : onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for confirmation, deletes the record on the server, then reloads the list.
Future<void> confirmAndDeleteEntry(
  BuildContext context,
  WidgetRef ref,
  EntrySummary entry,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this entry?'),
      content: const Text("This can't be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    await ref.read(pbProvider).collection('entries').delete(entry.id);
    if (!context.mounted) return;
    ref.invalidate(entriesProvider); // reload the list
  } catch (e) {
    debugPrint('Delete failed: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not delete the entry.')),
    );
  }
}
