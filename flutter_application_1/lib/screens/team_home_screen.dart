import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/roles.dart';
import '../widgets/auth_widgets.dart';

/// Accueil des membres de l'équipe (formateur, gérant, manager, super admin) sur mobile.
/// Les écrans métier seront ajoutés aux prochaines étapes.
class TeamHomeScreen extends StatelessWidget {
  const TeamHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final prenom = auth.userName.trim().split(RegExp(r'\s+')).last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace équipe'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(4), child: BrandStripe()),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmerDeconnexion(context),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Bonjour $prenom 👋', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Chip(
            avatar: Icon(Icons.verified_user_outlined, size: 18, color: scheme.primary),
            label: Text(Roles.label(auth.role)),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.construction_outlined, color: scheme.primary, size: 28),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Vous êtes connecté. Les outils de l’équipe (séances, présences, discussion, FAB’IA) '
                      'arrivent sur mobile dans les prochaines versions. En attendant, utilisez l’interface web d’administration.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Déconnexion avec confirmation (action qui fait perdre la session).
Future<void> confirmerDeconnexion(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.logout),
      title: const Text('Se déconnecter ?'),
      content: const Text('Vous devrez saisir à nouveau votre email et votre mot de passe.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Se déconnecter')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final auth = context.read<AuthProvider>();
  // Ferme les écrans ouverts (paramètres, conversation…) : l'écran de connexion reprend la main
  Navigator.of(context).popUntil((route) => route.isFirst);
  await auth.logout();
}
