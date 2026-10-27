import 'package:laforet_mobile/routes/entries_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laforet_mobile/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HomeRoute extends ConsumerStatefulWidget {
  const HomeRoute({super.key});

  @override
  ConsumerState<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends ConsumerState<HomeRoute> {
  bool _isCheckingUrl = false;
  final TextEditingController _urlController = TextEditingController();

  Future<void> _saveUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    final cleanUrl = rawUrl.endsWith('/') ? rawUrl.substring(0, rawUrl.length - 1) : rawUrl;

    setState(() => _isCheckingUrl = true);

    try {
      final response = await http
          .get(Uri.parse('$cleanUrl/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laforet_url', cleanUrl);

        // UPDATE THE GLOBAL PROVIDER!
        // This instantly triggers the pbProvider to recreate the PocketBase client
        // with the new URL, and rebuilds this widget to show the success screen.
        ref.read(backendUrlProvider.notifier).state = cleanUrl;
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid URL or server is unreachable.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUrl = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global Riverpod URL state
    final backendUrl = ref.watch(backendUrlProvider);

    // If it's null, show the setup screen
    if (backendUrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connect to Laforet')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Enter your server URL to get started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                enabled: !_isCheckingUrl,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isCheckingUrl ? null : _saveUrl,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _isCheckingUrl
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save & Connect'),
              ),
            ],
          ),
        ),
      );
    }

    // If it exists, they are ready to log in or view the diary!
    return EntriesRoute();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}