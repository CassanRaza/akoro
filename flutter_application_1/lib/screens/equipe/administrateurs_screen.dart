import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/roles.dart';
import '../../widgets/ui.dart';
import '../beneficiaire/discussion/discussion_screen.dart' show AvatarPersonne;
import 'commun.dart';

/// Administrateurs (Super Admin uniquement, comme sur le web) :
/// valider un compte en attente avec son rôle, changer de rôle, désactiver un accès.
class AdministrateursScreen extends StatefulWidget {
  const AdministrateursScreen({super.key});

  @override
  State<AdministrateursScreen> createState() => _AdministrateursScreenState();
}

class _AdministrateursScreenState extends State<AdministrateursScreen> {
  List<Map<String, dynamic>>? _admins;
  String? _erreur;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final j = await _api.get('/administrateurs');
      if (mounted) setState(() => _admins = enListe(j));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _choisirRole(Map<String, dynamic> a, {required bool valider}) async {
    var role = Roles.choisissables.contains(a['role']) ? '${a['role']}' : 'fabmanager';
    final choisi = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(valider ? 'Valider l’administrateur' : 'Modifier le rôle', style: Theme.of(ctx).textTheme.titleLarge),
                Text('${a['name']} — rôle demandé : ${Roles.label('${a['role']}')}'),
                const SizedBox(height: 8),
                for (final r in Roles.choisissables)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(role == r ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: Theme.of(ctx).colorScheme.primary),
                    title: Text(Roles.label(r)),
                    subtitle: Text(Roles.descriptions[r] ?? ''),
                    onTap: () => maj(() => role = r),
                  ),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, role), child: Text(valider ? 'Valider le compte' : 'Enregistrer')),
              ],
            ),
          ),
        ),
      ),
    );
    if (choisi == null || !mounted) return;
    if (!await confirmer(context,
        titre: valider ? 'Valider le compte ?' : 'Modifier le rôle ?',
        message: valider
            ? 'Le compte de ${a['name']} sera activé avec le rôle ${Roles.label(choisi)}.'
            : 'Le rôle de ${a['name']} sera remplacé par ${Roles.label(choisi)}.',
        action: valider ? 'Valider' : 'Modifier')) {
      return;
    }
    try {
      await _api.put('/administrateurs/${a['id']}', {'role': choisi, if (valider) 'actif': true});
      if (!mounted) return;
      afficherMessage(context, valider ? 'Compte validé : l’administrateur peut se connecter.' : 'Rôle modifié avec succès.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.fieldErrors['role'] ?? e.message, erreur: true);
    }
  }

  Future<void> _desactiver(Map<String, dynamic> a) async {
    if (!await confirmer(context,
        titre: 'Désactiver cet accès ?',
        message: 'L’accès de ${a['name']} à l’administration sera désactivé.',
        action: 'Désactiver',
        danger: true)) {
      return;
    }
    try {
      await _api.put('/administrateurs/${a['id']}', {'actif': false});
      if (!mounted) return;
      afficherMessage(context, 'Accès désactivé.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moi = ((context.watch<AuthProvider>().user?['id']) as num?)?.toInt();
    final liste = _admins;
    final scheme = Theme.of(context).colorScheme;

    return PagePoussee(
      titre: 'Administrateurs',
      corps: liste == null
          ? (_erreur != null ? EtatErreur(message: _erreur!, onRetry: _charger) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text('Valider les nouveaux membres de l’équipe, changer leur rôle ou désactiver leur accès.',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  for (final a in liste)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AvatarPersonne(nom: '${a['name']}', photo: a['photo_url']?.toString(), rayon: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${a['name']}${a['id'] == moi ? ' (vous)' : ''}',
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('${a['email']}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, children: [
                              Pastille(Roles.label('${a['role']}'), ton: 'info'),
                              Pastille(a['actif'] == true ? 'Actif' : 'En attente', ton: a['actif'] == true ? 'succes' : 'alerte'),
                            ]),
                            if (a['id'] != moi)
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (a['actif'] == true) ...[
                                    if (a['role'] != 'admin_global')
                                      TextButton.icon(
                                        onPressed: () => _choisirRole(a, valider: false),
                                        icon: const Icon(Icons.badge_outlined),
                                        label: const Text('Modifier le rôle'),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _desactiver(a),
                                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                                      icon: const Icon(Icons.block),
                                      label: const Text('Désactiver'),
                                    ),
                                  ] else
                                    TextButton.icon(
                                      onPressed: () => _choisirRole(a, valider: true),
                                      icon: const Icon(Icons.how_to_reg_outlined),
                                      label: const Text('Valider'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
