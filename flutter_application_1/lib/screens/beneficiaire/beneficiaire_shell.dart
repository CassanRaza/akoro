import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notifications_provider.dart';
import 'accueil_screen.dart';
import 'discussion/discussion_screen.dart';
import 'fabia/fabia_screen.dart';
import 'formations/formations_screen.dart';
import 'presences_page.dart';
import 'quiz/quiz_hub_screen.dart';

/// Squelette bénéficiaire : barre du bas à 5 onglets (Accueil, Formations, Devoirs, Discussion, Assistant).
class BeneficiaireShell extends StatefulWidget {
  const BeneficiaireShell({super.key});

  @override
  State<BeneficiaireShell> createState() => _BeneficiaireShellState();
}

class _BeneficiaireShellState extends State<BeneficiaireShell> {
  int _index = Onglet.accueil;
  final _accueilKey = GlobalKey<AccueilScreenState>();
  final _formationsKey = GlobalKey<FormationsScreenState>();
  final _devoirsKey = GlobalKey<QuizHubScreenState>();
  late final NotificationsProvider _notifications;

  @override
  void initState() {
    super.initState();
    // Cloche de l'en-tête : actualisée toutes les 30 s tant que l'espace bénéficiaire est ouvert
    _notifications = context.read<NotificationsProvider>()
      ..ouvrirOnglet = _ouvrirOnglet
      ..ouvrirAbsences = (() => _ouvrirPresences(absences: true))
      ..demarrer();
  }

  @override
  void dispose() {
    _notifications
      ..arreter()
      ..ouvrirOnglet = null
      ..ouvrirAbsences = null;
    super.dispose();
  }

  void _ouvrirOnglet(int i) {
    if (!mounted) return;
    setState(() => _index = i);
    // Revenir sur un onglet actualise ses données
    if (i == Onglet.accueil) _accueilKey.currentState?.recharger();
    if (i == Onglet.formations) _formationsKey.currentState?.recharger();
    if (i == Onglet.devoirs) _devoirsKey.currentState?.recharger();
  }

  Future<void> _ouvrirPresences({bool absences = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PresencesPage(ongletInitial: absences ? 1 : 0)),
    );
    // Un pointage ou un justificatif a pu changer les chiffres
    _accueilKey.currentState?.recharger();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Retour Android depuis un autre onglet : revient à l'accueil au lieu de quitter l'appli
      canPop: _index == Onglet.accueil,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ouvrirOnglet(Onglet.accueil);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              AccueilScreen(key: _accueilKey, onOpenTab: _ouvrirOnglet, onOpenPresences: _ouvrirPresences),
              FormationsScreen(key: _formationsKey),
              QuizHubScreen(key: _devoirsKey),
              DiscussionScreen(actif: _index == Onglet.discussion, onOuvrirFabia: () => _ouvrirOnglet(Onglet.assistant)),
              const FabiaScreen(),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _ouvrirOnglet,
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
              const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Formations'),
              const NavigationDestination(
                  icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Devoirs'),
              NavigationDestination(
                icon: _BadgeMessages(child: const Icon(Icons.chat_bubble_outline)),
                selectedIcon: _BadgeMessages(child: const Icon(Icons.chat_bubble)),
                label: 'Discussion',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Assistant'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille du nombre de messages non lus sur l'onglet Discussion.
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
