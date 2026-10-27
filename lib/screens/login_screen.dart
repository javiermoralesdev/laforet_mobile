import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laforet_mobile/crypto.dart';
import 'package:laforet_mobile/pocketbase.dart';
import 'package:laforet_mobile/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pocketbase/pocketbase.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Restored session: prefill the email, the user only has to type the password.
    final saved = ref.read(pbProvider).authStore.record?.getStringValue('email');
    if (saved != null) _email.text = saved;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      final sw = Stopwatch()..start();
      final keys = await deriveKeysInBackground(password, email);
      debugPrint('derive: ${sw.elapsedMilliseconds} ms');

      sw.reset();
      await ref.read(pbProvider).collection('users').authWithPassword(email, keys.authSecret);
      debugPrint('auth request: ${sw.elapsedMilliseconds} ms');

      // Set the key last. The gate needs login + key, so there is no flash of an empty list.
      ref.read(vaultKeyProvider.notifier).set(keys.encKey);
    } on ClientException catch (e) {
      debugPrint('Login failed: status=${e.statusCode} url=${e.url}\n'
          'response=${e.response}\noriginal=${e.originalError}');
      _snack(e.statusCode == 400
          ? 'Wrong email or password.'
          : 'Could not reach the server (status ${e.statusCode}).');
    }catch (e, st) {
      debugPrint('Unlock failed: $e\n$st');
      _snack('Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laforet')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
              enabled: !_busy,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: _busy
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
