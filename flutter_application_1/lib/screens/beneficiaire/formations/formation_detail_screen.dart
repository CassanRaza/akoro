import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/ui.dart';
import 'chapitre_screen.dart';
import 'quiz_screen.dart';

class FormationDetailScreen extends StatefulWidget {
  final int formationId;
  final String titre;
  const FormationDetailScreen({super.key, required this.formationId, required this.titre});

  @override
  State<FormationDetailScreen> createState() => _FormationDetailScreenState();
}

class _FormationDetailScreenState extends State<FormationDetailScreen> {
  FormationDetail? _f;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final json = await context.read<AuthProvider>().api.get('/mes-formations/${widget.formationId}');
      if (mounted) setState(() => _f = FormationDetail.fromJson(Map<String, dynamic>.from(json as Map)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _ouvrirChapitre(Chapitre c) async {
    final f = _f!;
    if (!c.accessible) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Terminez d’abord le chapitre précédent pour débloquer celui-ci.')));
      return;
    }
    final maj = await Navigator.of(context).push<FormationDetail>(
      MaterialPageRoute(builder: (_) => ChapitreScreen(formation: f, chapitreId: c.id)),
    );
    if (maj != null && mounted) {
      setState(() => _f = maj);
    } else {
      _charger();
    }
  }

  Future<void> _ouvrirQuiz(QuizResume q) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(quiz: q)));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Text('Toutes les formations',
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: const [ThemeToggleButton()],
      ),
      body: f == null
          ? (_erreur != null
              ? EtatErreur(message: _erreur!, onRetry: _charger)
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _EnTete(f: f),
                  const SectionTitle('Programme des chapitres'),
                  if (f.chapitres.isEmpty)
                    const EtatVide(
                      icon: Icons.menu_book_outlined,
                      titre: 'Aucun chapitre pour l’instant',
                      texte: 'L’équipe du FabLab n’a pas encore publié de document pour cette formation.',
                    )
                  else
                    for (final c in f.chapitres) ...[
                      _LigneChapitre(c: c, enCours: c.id == f.chapitreSuivant?.id && f.avancement.termines > 0, onTap: () => _ouvrirChapitre(c)),
                      const SizedBox(height: 10),
                    ],
                  if (f.quiz.isNotEmpty) ...[
                    const SectionTitle('Évaluations'),
                    for (final q in f.quiz) ...[
                      _CarteQuiz(q: q, onTap: () => _ouvrirQuiz(q)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
      bottomNavigationBar: f == null || f.chapitres.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                iconAlignment: IconAlignment.end,
                icon: Icon(f.avancement.termine ? Icons.replay_rounded : Icons.play_arrow_rounded),
                label: Text(f.avancement.termine
                    ? 'Revoir la formation'
                    : f.avancement.termines == 0
                        ? 'Commencer la formation'
                        : 'Continuer la formation'),
                onPressed: () => _ouvrirChapitre(f.chapitreSuivant ?? f.chapitres.first),
              ),
            ),
    );
  }
}

class _EnTete extends StatelessWidget {
  final FormationDetail f;
  const _EnTete({required this.f});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fond = dark ? const Color(0xFF0B5E53) : const Color(0xFF0C6E62);
    final a = f.avancement;

    return Semantics(
      label: '${f.titre}. Parcours ${f.parcours}. Progression ${a.pourcentage} pour cent, ${a.termines} chapitres sur ${a.total}.',
      child: ExcludeSemantics(
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
              Tag(f.parcours, fg: Colors.white, bg: Colors.white.withValues(alpha: 0.16)),
              const SizedBox(height: 12),
              Text(f.titre, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800, height: 1.2)),
              if ((f.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(f.description!, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.45)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Progression de la formation',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                  const Spacer(),
                  Text('${a.pourcentage}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              BarreProgression(valeur: a.pourcentage / 100, couleur: Brand.orangeLight, fond: Colors.white.withValues(alpha: 0.22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneChapitre extends StatelessWidget {
  final Chapitre c;
  final bool enCours;
  final VoidCallback onTap;
  const _LigneChapitre({required this.c, required this.enCours, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final verrou = !c.accessible;

    final Widget pastille = c.termine
        ? CircleAvatar(radius: 16, backgroundColor: st.successBg, child: Icon(Icons.check_rounded, size: 18, color: st.success))
        : verrou
            ? CircleAvatar(radius: 16, backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5), child: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant))
            : CircleAvatar(
                radius: 16,
                backgroundColor: enCours ? st.warningBg : scheme.primaryContainer,
                child: enCours
                    ? Container(width: 10, height: 10, decoration: BoxDecoration(color: st.warning, shape: BoxShape.circle))
                    : Text('${c.numero}', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
              );

    final etat = c.termine ? 'terminé' : verrou ? 'verrouillé' : enCours ? 'en cours' : 'à faire';

    return Opacity(
      opacity: verrou ? 0.55 : 1,
      child: AppCard(
        onTap: onTap,
        semantique: 'Chapitre ${c.numero} : ${c.titre}, $etat',
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: enCours ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
        borderColor: enCours ? scheme.primary : null,
        borderWidth: enCours ? 1.5 : 1,
        child: Row(
          children: [
            pastille,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ch.${c.numero} ${c.titre}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, color: enCours ? scheme.primary : scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    [c.type.toUpperCase(), c.tailleLisible].where((t) => t.isNotEmpty).join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (enCours) Tag('En cours', fg: Colors.white, bg: st.warning),
          ],
        ),
      ),
    );
  }
}

class _CarteQuiz extends StatelessWidget {
  final QuizResume q;
  final VoidCallback onTap;
  const _CarteQuiz({required this.q, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final fmt = DateFormat('d MMM à HH:mm', 'fr');

    final (String etat, Color fg, Color bg) = switch (q.etat) {
      'termine' => (q.resultat?.noteLisible ?? 'Terminé', q.resultat?.reussi == true ? st.success : st.danger,
          q.resultat?.reussi == true ? st.successBg : st.dangerBg),
      'en_cours' => ('Reprendre', st.warning, st.warningBg),
      'disponible' => ('Ouvert', st.warning, st.warningBg),
      'a_venir' => ('À venir', scheme.onSurfaceVariant, scheme.outlineVariant.withValues(alpha: 0.5)),
      _ => ('Fermé', scheme.onSurfaceVariant, scheme.outlineVariant.withValues(alpha: 0.5)),
    };

    final details = <String>[
      '${q.nbQuestions} question${q.nbQuestions > 1 ? 's' : ''}',
      if (q.dureeMinutes != null) '${q.dureeMinutes} min',
      if (q.etat == 'a_venir' && q.dateDebut != null) 'ouvre le ${fmt.format(q.dateDebut!)}',
      if (q.jouable && q.dateLimite != null) 'avant le ${fmt.format(q.dateLimite!)}',
    ];

    return AppCard(
      onTap: q.jouable || q.etat == 'termine' ? onTap : null,
      semantique: 'Quiz ${q.titre}, $etat, ${details.join(', ')}',
      color: q.jouable ? st.warningBg : null,
      borderColor: q.jouable ? st.warning.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Icon(Icons.quiz_outlined, color: q.jouable ? st.warning : scheme.onSurfaceVariant, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tag(etat, fg: fg, bg: bg),
        ],
      ),
    );
  }
}
