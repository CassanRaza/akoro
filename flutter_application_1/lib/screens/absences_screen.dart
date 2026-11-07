import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen> {
  List<Map<String, dynamic>> _absences = [];
  bool _loading = true;
  String? _error;

  ApiService get _api => context.read<AuthProvider>().api;

  static const _statuts = {
    'non_justifiee': ('Non justifiée', Colors.red),
    'a_valider': ('En attente de validation', Colors.orange),
    'justifiee': ('Justifiée', Colors.green),
    'refusee': ('Justification refusée', Colors.red),
  };

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
      final data = await _api.get('/mes-absences');
      _absences = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? (v?.toString() ?? '') : DateFormat('dd/MM/yyyy').format(d);
  }

  Future<void> _justifier(Map<String, dynamic> absence) async {
    final controller = TextEditingController(text: absence['motif']?.toString() ?? '');
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Justifier mon absence'),
        content: TextField(
          controller: controller,
          maxLength: 255,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motif', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (motif == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (motif.length < 3) {
      messenger.showSnackBar(const SnackBar(content: Text('Le motif doit contenir au moins 3 caractères.')));
      return;
    }
    try {
      final updated = await _api.post('/absences/${absence['id']}/justifier', {'motif': motif});
      setState(() {
        final i = _absences.indexWhere((a) => a['id'] == absence['id']);
        if (i >= 0) _absences[i] = Map<String, dynamic>.from(updated as Map);
      });
      messenger.showSnackBar(const SnackBar(content: Text('Justification envoyée.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_error!)),
            )
          else if (_absences.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('Aucune absence enregistrée 🎉')),
            ),
          for (final a in _absences) _buildTile(a),
        ],
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> a) {
    final statut = a['statut']?.toString() ?? 'non_justifiee';
    final (label, color) = _statuts[statut] ?? (statut, Colors.grey);
    final lecon = a['lecon'] is Map ? a['lecon']['titre'] : null;
    final modifiable = statut == 'non_justifiee' || statut == 'refusee';

    return Card(
      child: ListTile(
        title: Text(_date(a['date'])),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lecon != null) Text(lecon.toString()),
            if (a['motif'] != null) Text('Motif : ${a['motif']}'),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: modifiable
            ? TextButton(onPressed: () => _justifier(a), child: const Text('Justifier'))
            : null,
      ),
    );
  }
}
