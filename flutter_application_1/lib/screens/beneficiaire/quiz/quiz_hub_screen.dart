import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/devoir.dart';
import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/carte_quiz.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/ui.dart';
import '../devoirs/rendu_screen.dart';
import '../formations/quiz_screen.dart';
import 'entrainement_screen.dart';

/// Onglet « Devoirs » : quiz notés et devoirs à rendre programmés par l'équipe,
/// + entraînement libre avec FAB'IA (non noté).
class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({super.key});

  @override
  State<QuizHubScreen> createState() => QuizHubScreenState();
}

/// Élément de la liste : un quiz (QCM) ou un devoir à rendre.
typedef _Element = ({QuizResume? quiz, DevoirRendu? rendu, DateTime? tri});

class QuizHubScreenState extends State<QuizHubScreen> {
  List<QuizResume>? _quiz;
  List<DevoirRendu>? _rendus;
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  /// Rechargé aussi au retour sur l'onglet.
  Future<void> recharger() async {
    setState(() {
      _chargement = _quiz == null;
      _erreur = null;
    });
    final api = context.read<AuthProvider>().api;
    try {
      final res = await Future.wait([api.get('/mes-quiz'), api.get('/mes-rendus')]);
      if (!mounted) return;
      setState(() {
        _quiz = [for (final q in (res[0] as List)) QuizResume.fromJson(Map<String, dynamic>.from(q as Map))];
        _rendus = [for (final d in (res[1] as List)) DevoirRendu.fromJson(Map<String, dynamic>.from(d as Map))];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ouvrirQuiz(QuizResume q) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(quiz: q)));
    recharger(); // la note ou l'état a pu changer
  }

  Future<void> _ouvrirRendu(DevoirRendu d) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RenduScreen(devoirId: d.id, titre: d.titre)));
    recharger();
  }

  void _ouvrirEntrainement() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EntrainementScreen()));

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz ?? const <QuizResume>[];
    final rendus = _rendus ?? const <DevoirRendu>[];

    List<_Element> trier(Iterable<_Element> e, {bool recents = false}) {
      final l = e.toList()
        ..sort((a, b) => (a.tri ?? DateTime(2100)).compareTo(b.tri ?? DateTime(2100)));
      return recents ? l.reversed.toList() : l;
    }

    _Element q(QuizResume x) => (quiz: x, rendu: null, tri: x.dateLimite ?? x.dateDebut);
    _Element r(DevoirRendu x) => (quiz: null, rendu: x, tri: x.dateLimite);

    final aFaire = trier([...quiz.where((x) => x.jouable).map(q), ...rendus.where((x) => x.aFaire).map(r)]);
    final aVenir = trier(quiz.where((x) => x.etat == 'a_venir').map(q));
    final faits = trier([
      ...quiz.where((x) => x.etat == 'termine').map(q),
      ...rendus.where((x) => x.etat == 'rendu' || x.etat == 'corrige').map(r),
    ], recents: true);
    final manques = trier([
      ...quiz.where((x) => x.etat == 'manque').map(q),
      ...rendus.where((x) => x.etat == 'manque').map(r),
    ], recents: true);
    final vide = quiz.isEmpty && rendus.isEmpty;

    Widget carte(_Element e) => e.quiz != null
        ? CarteQuiz(q: e.quiz!, avecFormation: true, onTap: () => _ouvrirQuiz(e.quiz!))
        : CarteRendu(d: e.rendu!, onTap: () => _ouvrirRendu(e.rendu!));

    Widget section(String titre, List<_Element> liste) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle('$titre (${liste.length})'),
            for (final e in liste) ...[carte(e), const SizedBox(height: 10)],
          ],
        );

    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const PageHeader(title: 'Devoirs', subtitle: 'Quiz, devoirs à rendre et entraînement libre'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _CarteEntrainement(onTap: _ouvrirEntrainement),
                if (_chargement)
                  const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
                else if (_quiz == null)
                  EtatErreur(message: _erreur ?? 'Impossible de charger les devoirs.', onRetry: recharger)
                else if (vide)
                  const EtatVide(
                    icon: Icons.event_note_outlined,
                    titre: 'Aucun devoir programmé',
                    texte: 'Les quiz notés et les devoirs à rendre de votre parcours apparaîtront ici dès que l’équipe '
                        'les aura programmés. En attendant, entraînez-vous avec FAB’IA.',
                  )
                else ...[
                  if (_erreur != null) ...[
                    const SizedBox(height: 12),
                    Text('Liste peut-être pas à jour : $_erreur',
                        style: TextStyle(color: StatusColors.of(context).warning, fontWeight: FontWeight.w600)),
                  ],
                  if (aFaire.isNotEmpty) section('À faire maintenant', aFaire),
                  if (aVenir.isNotEmpty) section('À venir', aVenir),
                  if (faits.isNotEmpty) section('Faits', faits),
                  if (manques.isNotEmpty) section('Manqués', manques),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'accès à l'entraînement libre (couleurs de l'en-tête des formations).
class _CarteEntrainement extends StatelessWidget {
  final VoidCallback onTap;
  const _CarteEntrainement({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fond = dark ? const Color(0xFF0B5E53) : const Color(0xFF0C6E62);

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Brand.orangeLight, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('S’entraîner avec FAB’IA',
                      style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                Tag('Non noté', fg: Colors.white, bg: Colors.white.withValues(alpha: 0.16)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Un quiz rapide sur la formation de votre choix, autant de fois que vous voulez. '
              'Vous voyez la correction tout de suite et votre score n’est pas transmis à l’équipe.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.orange, foregroundColor: Colors.white),
              onPressed: onTap,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Commencer un entraînement'),
            ),
          ],
        ),
      ),
    );
  }
}
