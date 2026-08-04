import 'package:flutter/material.dart';

import 'api/api_client.dart';

void main() => runApp(const FinanceTrackerApp());

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Tracker',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const ConnectionScreen(),
    );
  }
}

/// A minimal screen that proves the client reaches the backend: sign in, then
/// classify a transaction description via the Rust AI service.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _api = ApiClient();
  final _email = TextEditingController(text: 'demo@example.com');
  final _password = TextEditingController(text: 'supersecret');
  final _description = TextEditingController(text: 'UBER TRIP 4821');

  String _status = 'Not signed in';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Registers first so a fresh backend works, then logs in. A 409 means the
  /// account already exists, which is fine here.
  Future<void> _signIn() async {
    await _run(() async {
      try {
        await _api.register(_email.text, _password.text);
      } on ApiException catch (e) {
        if (e.statusCode != 409) rethrow;
      }
      await _api.login(_email.text, _password.text);
      return 'Signed in as ${_email.text}';
    });
  }

  Future<void> _classify() async {
    await _run(() async {
      final result = await _api.classify(_description.text);
      return 'Category: ${result['category']} '
          '(confidence ${result['confidence']})';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      setState(() => _status = message);
    } on ApiException catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Backend: ${_api.baseUrl}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: const Text('Sign in'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Transaction description',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _classify,
              child: const Text('Classify'),
            ),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Text(_status, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
