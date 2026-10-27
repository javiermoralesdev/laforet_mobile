import 'package:go_router/go_router.dart';
import 'package:laforet_mobile/crypto.dart';
import 'package:laforet_mobile/pocketbase.dart';
import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EntryWrite extends ConsumerWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  EntryWrite({super.key});

  void saveEntry(BuildContext context, WidgetRef ref) async {
    final key = ref.read(vaultKeyProvider);
    final titleEncrypted = await encryptText(titleController.text, key!);
    final bodyEncrypted = await encryptText(bodyController.text, key);
    final pb = ref.read(pbProvider);
    final author = pb.authStore.record!.id;
    await pb
        .collection("entries")
        .create(
          body: {
            'title': titleEncrypted,
            'body': bodyEncrypted,
            'author': author,
          },
        );
    if (!context.mounted) return;
    ref.invalidate(entriesProvider);
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text("Laforet")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyController,
              keyboardType: TextInputType.multiline,
              maxLength: null,
              decoration: InputDecoration(
                labelText: "Body",
                border: OutlineInputBorder(),
              ),
            ),
            ElevatedButton(
              onPressed: () => saveEntry(context, ref),
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
