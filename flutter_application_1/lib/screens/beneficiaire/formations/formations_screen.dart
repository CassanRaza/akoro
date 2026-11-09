import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/ui.dart';
import 'formation_detail_screen.dart';

enum _Filtre { tous, monParcours, enCours, termine }

/// « Nos Formations » : catalogue des leçons, avec la progression de chaque formation.
class FormationsScreen extends StatefulWidget {
  const FormationsScreen({super.key});

  @override
  State<FormationsScreen> createState() => FormationsScreenState();
}

class FormationsScreenState extends State<FormationsScreen> {
  List<FormationResume>? _formations;
  String? _erreur;
  bool _chargement = true;
  _Filtre _filtre = _Filtre.tous;
  final _recherche = TextEditingController();

  @override
  void initState() {
    super.initState();
    recharger();
    _recherche.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> recharger() async {
    setState(() {
      _chargement = _formations == null;
      _erreur = null;
    });
    try {
      final json = await context.read<AuthProvider>().api.get('/mes-formations');
      if (!mounted) return;
      setState(() => _formations = [
            for (final f in (json as List)) FormationResume.fromJson(Map<String, dynamic>.from(f as Map)),
          ]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ouvrir(FormationResume f) async {
    if (!f.accessible) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('« ${f.titre} » fait partie du parcours ${f.parcours}. '
              'Demandez à l’équipe du FabLab si vous souhaitez y accéder.'),
        ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FormationDetailScreen(formationId: f.id, titre: f.titre)));
    recharger(); // la progression a pu changer
  }

  List<FormationResume> get _filtrees {
    final q = _recherche.text.trim().toLowerCase();
    return (_formations ?? const <FormationResume>[]).where((f) {
      final okFiltre = switch (_filtre) {
        _Filtre.tous => true,
        _Filtre.monParcours => f.accessible,
        _Filtre.enCours => f.accessible && f.avancement.enCours,
        _Filtre.termine => f.accessible && f.avancement.termine,
      };
      final okTexte = q.isEmpty ||
          '${f.titre} ${f.description ?? ''} ${f.parcours}'.toLowerCase().contains(q);
      return okFiltre && okTexte;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liste = _filtrees;
    final miennes = liste.where((f) => f.accessible).toList();
    final autres = liste.where((f) => !f.accessible).toList();

    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const PageHeader(title: 'Nos Formations', subtitle: 'Développez vos compétences pratiques au FabLab'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: _recherche,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher une formation, une machine…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close),
                        onPressed: _recherche.clear,
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              children: [
                for (final (f, label) in const [
                  (_Filtre.tous, 'Tous'),
                  (_Filtre.monParcours, 'Mon parcours'),
                  (_Filtre.enCours, 'En cours'),
                  (_Filtre.termine, 'Terminé'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filtre == f,
                      showCheckmark: false,
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(
                        color: _filtre == f ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(color: _filtre == f ? scheme.primary : scheme.outlineVariant),
                      shape: const StadiumBorder(),
                      onSelected: (_) => setState(() => _filtre = f),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _chargement
                ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
                : _formations == null
                    ? EtatErreur(message: _erreur ?? 'Impossible de charger les formations.', onRetry: recharger)
                    : liste.isEmpty
                        ? EtatVide(
                            icon: Icons.search_off_rounded,
                            titre: _formations!.isEmpty ? 'Aucune formation pour le moment' : 'Aucune formation trouvée',
                            texte: _formations!.isEmpty
                                ? 'Les formations de votre parcours apparaîtront ici dès que l’équipe les aura publiées.'
                                : 'Essayez un autre mot ou un autre filtre.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (miennes.isNotEmpty) ...[
                                SectionTitle('Mon parcours · ${miennes.first.parcours}'),
                                for (final f in miennes) ...[_CarteFormation(f: f, onTap: () => _ouvrir(f)), const SizedBox(height: 12)],
                              ],
                              if (autres.isNotEmpty) ...[
                                const SectionTitle('Autres parcours du FabLab'),
                                for (final f in autres) ...[_CarteFormation(f: f, onTap: () => _ouvrir(f)), const SizedBox(height: 12)],
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _CarteFormation extends StatelessWidget {
  final FormationResume f;
  final VoidCallback onTap;
  const _CarteFormation({required this.f, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final a = f.avancement;
    final verrou = !f.accessible;

    final (etat, couleurEtat) = verrou
        ? ('', scheme.onSurfaceVariant)
        : a.statut == 'vide'
            ? ('Bientôt', scheme.onSurfaceVariant)
            : a.termine
                ? ('Terminé', st.success)
                : a.enCours
                    ? ('${a.pourcentage}% complété', st.success)
                    : ('À commencer', scheme.onSurfaceVariant);

    final semantique = verrou
        ? '${f.titre}, parcours ${f.parcours}, verrouillée'
        : '${f.titre}, parcours ${f.parcours}, $etat, ${a.termines} chapitres sur ${a.total}'
            '${f.quizOuverts > 0 ? ', ${f.quizOuverts} quiz disponible' : ''}';

    return Opacity(
      opacity: verrou ? 0.62 : 1,
      child: AppCard(
        onTap: onTap,
        semantique: semantique,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Tag(
                    f.parcours,
                    fg: verrou ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
                    bg: verrou ? scheme.outlineVariant.withValues(alpha: 0.6) : scheme.primaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                if (verrou)
                  Icon(Icons.lock_outline, size: 20, color: scheme.onSurfaceVariant)
                else
                  Text(etat, style: TextStyle(color: couleurEtat, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text(f.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            if ((f.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(f.description!,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            if (!verrou) ...[
              const SizedBox(height: 14),
              BarreProgression(valeur: a.pourcentage / 100, couleur: a.pourcentage < 34 && a.pourcentage > 0 ? st.warning : st.success),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    a.total == 0 ? 'Aucun chapitre pour l’instant' : '${a.termines} / ${a.total} chapitre${a.total > 1 ? 's' : ''}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                  const Spacer(),
                  if (f.quizOuverts > 0)
                    Tag(f.quizOuverts == 1 ? 'Quiz ouvert' : '${f.quizOuverts} quiz ouverts',
                        fg: st.warning, bg: st.warningBg, icon: Icons.quiz_outlined),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
