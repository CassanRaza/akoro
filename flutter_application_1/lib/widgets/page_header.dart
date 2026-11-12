import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/compte_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/team_home_screen.dart' show confirmerDeconnexion;
import '../theme/app_theme.dart';
import '../utils/roles.dart';

/// En-tête des onglets (maquettes) : • NOM DU FABLAB, grand titre, sous-titre, avatar à droite.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? fablab;
  final String? photoUrl;

  const PageHeader({super.key, required this.title, this.subtitle, this.fablab, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (fablab ?? 'FabLab Hay Tao').toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // Cloche globale : nouveaux devoirs, corrections, justificatifs, messages non lus
              const BoutonNotifications(),
              // La photo de la session est prioritaire : elle change dès que l'utilisateur modifie la sienne
              UserAvatarButton(name: auth.userName, photoUrl: auth.user?['photo_url']?.toString() ?? photoUrl),
              // Même place sur toutes les pages : coin supérieur droit
              const ThemeToggleButton(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Initiales sur fond menthe (ou photo) ; ouvre le panneau « Mon compte ».
class UserAvatarButton extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const UserAvatarButton({super.key, required this.name, this.photoUrl});

  static String initiales(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first.characters.first + (parts.length > 1 ? parts.last.characters.first : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Mon compte',
      child: IconButton(
        tooltip: 'Mon compte',
        onPressed: () => _ouvrirCompte(context),
        icon: CircleAvatar(
          radius: 20,
          backgroundColor: scheme.primaryContainer,
          foregroundImage: photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
          onForegroundImageError: photoUrl != null && photoUrl!.isNotEmpty ? (_, _) {} : null,
          child: Text(
            initiales(name),
            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _ouvrirCompte(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Petits écrans : le panneau défile au lieu de couper « Se déconnecter »
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
                  onForegroundImageError: photoUrl != null && photoUrl!.isNotEmpty ? (_, _) {} : null,
                  child: Text(initiales(auth.userName),
                      style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
                ),
                title: Text(auth.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${Roles.label(auth.role)} · ${auth.user?['email'] ?? ''}'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: Icon(Icons.manage_accounts_outlined, color: scheme.primary),
                title: const Text('Paramètres du compte', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Photo, informations, mot de passe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompteScreen()));
                },
              ),
              const Divider(),
              Text('Apparence', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 10),
              const ThemeModeSelector(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                  backgroundColor: StatusColors.of(context).dangerBg,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  confirmerDeconnexion(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Intitulé de section en capitales grises (« MES STATISTIQUES »…).
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? action;
  const SectionTitle(this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  text.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            ?action,
          ],
        ),
      );
}
