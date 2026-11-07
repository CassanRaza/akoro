import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PresenceScreen extends StatefulWidget {
  const PresenceScreen({super.key});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  Map<String, dynamic>? _presence;
  bool _loading = true;
  bool _pointing = false;
  String? _error;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/presences/aujourdhui');
      final p = data is Map ? data['presence'] : null;
      _presence = p is Map ? Map<String, dynamic>.from(p) : null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pointer() async {
    setState(() => _pointing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await _api.post('/presences/pointer');
      final p = data['presence'];
      setState(() => _presence = p is Map ? Map<String, dynamic>.from(p) : _presence);
      messenger.showSnackBar(SnackBar(
        content: Text(data['action'] == 'depart' ? 'Départ enregistré.' : 'Arrivée enregistrée.'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _pointing = false);
  }

  String _heure(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    final complete = _presence?['heure_depart'] != null;
    final label = _presence == null ? "Pointer mon arrivée" : 'Pointer mon départ';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Bonjour ${auth.userName}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(_error!),
                trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Présence d'aujourd'hui", style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: 'Arrivée', value: _heure(_presence?['heure_arrivee'])),
                      _Stat(label: 'Départ', value: _heure(_presence?['heure_depart'])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (complete || _pointing || _error != null) ? null : _pointer,
            icon: _pointing
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fingerprint),
            label: Text(complete ? 'Journée complète' : label),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label, style: t.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: t.headlineSmall),
      ],
    );
  }
}
