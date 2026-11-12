import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../utils/roles.dart';
import '../../widgets/page_header.dart';
import '../beneficiaire/discussion/discussion_screen.dart';
import '../beneficiaire/fabia/fabia_screen.dart';
import '../compte_screen.dart';
import '../team_home_screen.dart' show confirmerDeconnexion;
import 'absences_equipe_screen.dart';
import 'administrateurs_screen.dart';
import 'beneficiaires_screen.dart';
import 'devoir_detail_equipe_screen.dart';
import 'devoirs_equipe_screen.dart';
import 'parcours_detail_screen.dart';
import 'parcours_screen.dart';
import 'tableau_de_bord_screen.dart';

enum _Page { tableau, beneficiaires, parcours, devoirs, discussion, menu }

/// Espace équipe (Super Admin, Manager, formateur, gérant) : mêmes pages et mêmes droits que le web.
/// Barre du bas selon le rôle ; les autres pages du menu web sont dans l'onglet « Menu ».
class EquipeShell extends StatefulWidget {
  const EquipeShell({super.key});

  @override
  State<EquipeShell> createState() => _EquipeShellState();
}

class _EquipeShellState extends State<EquipeShell> {
  late final List<_Page> _onglets;
  int _index = 0;
  late final NotificationsProvider _notifications;
  final _tableauKey = GlobalKey<TableauDeBordScreenState>();
  final _beneficiairesKey = GlobalKey<BeneficiairesScreenState>();
  final _parcoursKey = GlobalKey<ParcoursScreenState>();
  final _devoirsKey = GlobalKey<DevoirsEquipeScreenState>();

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().role;
    // Page d'accueil du web : tableau de bord pour le Manager et le Super Admin, sinon les parcours
    _onglets = Roles.peutGererParcours(role)
        ? const [_Page.tableau, _Page.beneficiaires, _Page.parcours, _Page.devoirs, _Page.menu]
        : const [_Page.parcours, _Page.beneficiaires, _Page.devoirs, _Page.discussion, _Page.menu];
    _notifications = context.read<NotificationsProvider>()
      ..ouvrirLien = _ouvrirLien
      ..demarrer();
  }

  @override
  void dispose() {
    _notifications
      ..arreter()
      ..ouvrirLien = null;
    super.dispose();
  }

  void _allerA(_Page p) {
    final i = _onglets.indexOf(p);
    if (i < 0) return;
    setState(() => _index = i);
    switch (p) {
      case _Page.tableau:
        _tableauKey.currentState?.recharger();
      case _Page.beneficiaires:
        _beneficiairesKey.currentState?.recharger();
      case _Page.parcours:
        _parcoursKey.currentState?.recharger();
      case _Page.devoirs:
        _devoirsKey.currentState?.recharger();
      default:
        break;
    }
  }

  void _pousser(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// Ouvre la page correspondant à un lien du web (alertes de la cloche, tableau de bord).
  void _ouvrirLien(String lien) {
    if (!mounted) return;
    final morceaux = lien.split('/').where((s) => s.isNotEmpty).toList();
    final id = morceaux.length > 1 ? int.tryParse(morceaux[1]) : null;
    switch (morceaux.firstOrNull) {
      case 'absences':
        _pousser(const AbsencesEquipeScreen());
      case 'devoirs':
        id != null ? _pousser(DevoirDetailEquipeScreen(id: id)) : _allerA(_Page.devoirs);
      case 'beneficiaires':
        id != null ? _pousser(BeneficiaireFicheScreen(id: id)) : _allerA(_Page.beneficiaires);
      case 'parcours':
        id != null ? _pousser(ParcoursDetailScreen(id: id)) : _allerA(_Page.parcours);
      case 'discussion':
        _ouvrirDiscussion();
      default:
        break;
    }
  }

  void _ouvrirDiscussion() {
    if (_onglets.contains(_Page.discussion)) {
      _allerA(_Page.discussion);
    } else {
      _pousser(Scaffold(
        appBar: AppBar(),
        body: SafeArea(child: DiscussionScreen(actif: true, onOuvrirFabia: _ouvrirFabia)),
      ));
    }
  }

  void _ouvrirFabia() => _pousser(Scaffold(appBar: AppBar(), body: const SafeArea(child: FabiaScreen())));

  Widget _page(_Page p) => switch (p) {
        _Page.tableau => TableauDeBordScreen(key: _tableauKey, ouvrirLien: _ouvrirLien),
        _Page.beneficiaires => BeneficiairesScreen(key: _beneficiairesKey),
        _Page.parcours => ParcoursScreen(key: _parcoursKey),
        _Page.devoirs => DevoirsEquipeScreen(key: _devoirsKey),
        _Page.discussion => DiscussionScreen(actif: _onglets[_index] == _Page.discussion, onOuvrirFabia: _ouvrirFabia),
        _Page.menu => _Menu(
            discussionDansMenu: !_onglets.contains(_Page.discussion),
            onAbsences: () => _pousser(const AbsencesEquipeScreen()),
            onDiscussion: _ouvrirDiscussion,
            onFabia: _ouvrirFabia,
            onAdministrateurs: () => _pousser(const AdministrateursScreen()),
            onCompte: () => _pousser(const CompteScreen()),
          ),
      };

  NavigationDestination _destination(_Page p) => switch (p) {
        _Page.tableau => const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Tableau'),
        _Page.beneficiaires =>
          const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Bénéficiaires'),
        _Page.parcours =>
          const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Parcours'),
        _Page.devoirs =>
          const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Devoirs'),
        _Page.discussion => NavigationDestination(
            icon: _BadgeMessages(child: const Icon(Icons.chat_bubble_outline)),
            selectedIcon: _BadgeMessages(child: const Icon(Icons.chat_bubble)),
            label: 'Discussion'),
        _Page.menu => const NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'Menu'),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: [for (final p in _onglets) _page(p)]),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => _allerA(_onglets[i]),
            destinations: [for (final p in _onglets) _destination(p)],
          ),
        ),
      ),
    );
  }
}

class _BadgeMessages extends StatelessWidget {
  final Widget child;
  const _BadgeMessages({required this.child});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>().messagesNonLus;
    return Badge(
      isLabelVisible: n > 0,
      label: Text(n > 99 ? '99+' : '$n'),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      child: child,
    );
  }
}

/// Onglet « Menu » : le reste du menu latéral du web, filtré selon le rôle.
class _Menu extends StatelessWidget {
  final bool discussionDansMenu;
  final VoidCallback onAbsences, onDiscussion, onFabia, onAdministrateurs, onCompte;
  const _Menu({
    required this.discussionDansMenu,
    required this.onAbsences,
    required this.onDiscussion,
    required this.onFabia,
    required this.onAdministrateurs,
    required this.onCompte,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final messages = context.watch<NotificationsProvider>().messagesNonLus;

    Widget entree(IconData icone, String titre, String sousTitre, VoidCallback onTap, {int badge = 0}) => ListTile(
          minTileHeight: 60,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            backgroundColor: scheme.secondary,
            child: Icon(icone, color: scheme.primary),
          ),
          title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sousTitre),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    return ListView(
      children: [
        PageHeader(title: 'Menu', subtitle: '${auth.userName} · ${Roles.label(auth.role)}'),
        entree(Icons.event_busy_outlined, 'Absences', 'Historique et justificatifs', onAbsences),
        if (discussionDansMenu)
          entree(Icons.chat_bubble_outline, 'Discussion', 'Messagerie de l’établissement', onDiscussion, badge: messages),
        entree(Icons.auto_awesome_outlined, 'Assistant FAB’IA', 'Questions, rédaction, explications', onFabia),
        if (auth.role == 'admin_global')
          entree(Icons.admin_panel_settings_outlined, 'Administrateurs', 'Valider, rôles, accès', onAdministrateurs),
        entree(Icons.manage_accounts_outlined, 'Paramètres', 'Photo, informations, mot de passe', onCompte),
        const Divider(indent: 20, endIndent: 20),
        ListTile(
          minTileHeight: 56,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.logout, color: scheme.error),
          title: Text('Se déconnecter', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
          onTap: () => confirmerDeconnexion(context),
        ),
      ],
    );
  }
}
