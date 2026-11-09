import 'package:flutter/material.dart';

import '../../widgets/page_header.dart';
import 'accueil_screen.dart';
import 'formations/formations_screen.dart';
import 'presences_page.dart';

/// Squelette bénéficiaire : barre du bas à 4 onglets (maquettes).
class BeneficiaireShell extends StatefulWidget {
  const BeneficiaireShell({super.key});

  @override
  State<BeneficiaireShell> createState() => _BeneficiaireShellState();
}

class _BeneficiaireShellState extends State<BeneficiaireShell> {
  int _index = Onglet.accueil;
  final _accueilKey = GlobalKey<AccueilScreenState>();
  final _formationsKey = GlobalKey<FormationsScreenState>();

  void _ouvrirOnglet(int i) {
    setState(() => _index = i);
    // Revenir sur l'accueil actualise les chiffres
    if (i == Onglet.accueil) _accueilKey.currentState?.recharger();
    if (i == Onglet.formations) _formationsKey.currentState?.recharger();
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
              const _BientotDisponible(
                titre: 'Discussion',
                sousTitre: 'Échangez avec la communauté du FabLab',
                icon: Icons.chat_bubble_outline,
              ),
              const _BientotDisponible(
                titre: 'Assistant FAB’IA',
                sousTitre: 'Votre mentor d’intelligence artificielle au FabLab',
                icon: Icons.auto_awesome_outlined,
              ),
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
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Formations'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Discussion'),
            NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: 'Assistant'),
          ],
        ),
        ),
      ),
    );
  }
}

/// Onglets des prochaines étapes : en-tête définitif + message clair.
class _BientotDisponible extends StatelessWidget {
  final String titre, sousTitre;
  final IconData icon;
  const _BientotDisponible({required this.titre, required this.sousTitre, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        PageHeader(title: titre, subtitle: sousTitre),
        const SizedBox(height: 60),
        Icon(icon, size: 56, color: scheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          'Bientôt disponible',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Cette partie de l’application arrive dans une prochaine version.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
