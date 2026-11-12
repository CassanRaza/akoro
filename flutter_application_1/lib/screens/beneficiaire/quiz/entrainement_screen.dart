import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/ui.dart';

enum _Etape { choix, preparation, jeu, resultat }

/// Entraînement libre : quiz généré par FAB'IA sur une formation, corrigé tout de suite,
/// jouable à volonté. Le score reste sur le téléphone (rien n'est envoyé à l'équipe).
class EntrainementScreen extends StatefulWidget {
  const EntrainementScreen({super.key});

  @override
  State<EntrainementScreen> createState() => _EntrainementScreenState();
}

class _EntrainementScreenState extends State<EntrainementScreen> {
  _Etape _etape = _Etape.choix;

  // Choix de la formation
  List<FormationResume>? _formations;
  String? _erreurChargement;
  int? _leconId;
  int _nombre = 5;
  String? _erreurLancement;
  int _jeton = 0; // ignore la réponse d'une préparation annulée

  // Partie en cours
  List<QuestionEntrainement> _questions = const [];
  String _titreFormation = '';
  int _index = 0;
  int? _choix;
  bool _verifie = false;
  int _bonnes = 0;

  ApiService get _api => context.read<AuthProvider>().api;
  QuestionEntrainement get _q => _questions[_index];

  @override
  void initState() {
    super.initState();
    _chargerFormations();
  }

  Future<void> _chargerFormations() async {
    setState(() => _erreurChargement = null);
    try {
      final json = await _api.get('/mes-formations');
      if (!mounted) return;
      final toutes = [for (final f in (json as List)) FormationResume.fromJson(Map<String, dynamic>.from(f as Map))];
      setState(() {
        _formations = toutes.where((f) => f.accessible && f.avancement.total > 0).toList();
        if (_formations!.length == 1) _leconId = _formations!.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurChargement = e.message);
    }
  }

  Future<void> _lancer() async {
    final id = _leconId;
    if (id == null) {
      setState(() => _erreurLancement = 'Choisissez une formation.');
      return;
    }
    final jeton = ++_jeton;
    setState(() {
      _etape = _Etape.preparation;
      _erreurLancement = null;
    });

    try {
      // La première préparation d'une formation peut dépasser une minute
      final json = await _api.post('/entrainement', {'lecon_id': id, 'nombre': _nombre}, const Duration(seconds: 180));
      if (!mounted || jeton != _jeton) return;
      final m = Map<String, dynamic>.from(json as Map);
      final questions = [
        for (final q in (m['questions'] as List? ?? const []))
          QuestionEntrainement.fromJson(Map<String, dynamic>.from(q as Map)),
      ].where((q) => q.choix.length >= 2 && q.indexCorrect >= 0).toList();
      if (questions.isEmpty) throw ApiException('FAB’IA n’a renvoyé aucune question. Réessayez.');

      setState(() {
        _questions = questions;
        _titreFormation = '${m['formation'] ?? ''}';
        _index = 0;
        _choix = null;
        _verifie = false;
        _bonnes = 0;
        _etape = _Etape.jeu;
      });
    } on ApiException catch (e) {
      if (!mounted || jeton != _jeton) return;
      setState(() {
        _etape = _Etape.choix;
        _erreurLancement = e.fieldErrors['lecon_id'] ?? e.fieldErrors['nombre'] ?? e.message;
      });
    }
  }

  void _annulerPreparation() => setState(() {
        _jeton++;
        _etape = _Etape.choix;
      });

  void _verifier() {
    if (_choix == null || _verifie) return;
    setState(() {
      _verifie = true;
      if (_choix == _q.indexCorrect) _bonnes++;
    });
  }

  void _suivant() => setState(() {
        if (_index + 1 >= _questions.length) {
          _etape = _Etape.resultat;
        } else {
          _index++;
          _choix = null;
          _verifie = false;
        }
      });

  Future<bool> _confirmerSortie() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sports_esports_outlined),
        title: const Text('Quitter l’entraînement ?'),
        content: const Text('Votre partie en cours ne sera pas conservée. Vous pourrez en relancer une à tout moment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget corps = switch (_etape) {
      _Etape.choix => _vueChoix(scheme),
      _Etape.preparation => _VuePreparation(onAnnuler: _annulerPreparation),
      _Etape.jeu => _vueJeu(scheme),
      _Etape.resultat => _VueResultat(
          bonnes: _bonnes,
          total: _questions.length,
          formation: _titreFormation,
          onRejouer: _lancer,
          onChanger: () => setState(() => _etape = _Etape.choix),
        ),
    };

    return PopScope(
      canPop: _etape != _Etape.jeu,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmerSortie()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text('Retour aux devoirs', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          actions: const [ThemeToggleButton()],
        ),
        body: SafeArea(child: corps),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Étape 1 : choix de la formation et du nombre de questions
  // ---------------------------------------------------------------------
  Widget _vueChoix(ColorScheme scheme) {
    final formations = _formations;
    if (formations == null) {
      return _erreurChargement != null
          ? EtatErreur(message: _erreurChargement!, onRetry: _chargerFormations)
          : const Center(child: CircularProgressIndicator());
    }
    if (formations.isEmpty) {
      return const EtatVide(
        icon: Icons.menu_book_outlined,
        titre: 'Aucune formation disponible',
        texte: 'L’entraînement se base sur les documents de vos formations. '
            'Il sera possible dès que l’équipe en aura publié dans votre parcours.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Semantics(
          header: true,
          child: Text('Entraînement FAB’IA',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Text('Choisissez une formation : FAB’IA prépare des questions à partir de ses documents.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const SectionTitle('1. Formation'),
        for (final f in formations) ...[
          _ChoixFormation(
            f: f,
            selectionne: _leconId == f.id,
            onTap: () => setState(() {
              _leconId = f.id;
              _erreurLancement = null;
            }),
          ),
          const SizedBox(height: 10),
        ],
        const SectionTitle('2. Nombre de questions'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5 questions'), icon: Icon(Icons.bolt_outlined)),
            ButtonSegment(value: 10, label: Text('10 questions'), icon: Icon(Icons.fitness_center_outlined)),
          ],
          selected: {_nombre},
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onSelectionChanged: (s) => setState(() => _nombre = s.first),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: StatusColors.of(context).warning, foregroundColor: Colors.white),
          onPressed: _leconId == null ? null : _lancer,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Lancer l’entraînement'),
        ),
        if (_erreurLancement != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(_erreurLancement!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            _leconId == null
                ? 'Sélectionnez d’abord une formation.'
                : 'Score non enregistré : entraînez-vous autant que vous voulez.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Étape 3 : questions une à une, correction immédiate
  // ---------------------------------------------------------------------
  Widget _vueJeu(ColorScheme scheme) {
    final st = StatusColors.of(context);
    final q = _q;
    final total = _questions.length;
    final juste = _verifie && _choix == q.indexCorrect;
    final lettreCorrecte = String.fromCharCode(65 + q.indexCorrect);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_titreFormation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
            Tag('Score $_bonnes', fg: st.success, bg: st.successBg, icon: Icons.emoji_events_outlined),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Question ${_index + 1} sur $total', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('Entraînement', style: TextStyle(color: st.warning, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Question ${_index + 1} sur $total',
          child: BarreProgression(valeur: (_index + (_verifie ? 1 : 0)) / total, couleur: st.warning),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Text(q.enonce, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        ),
        const SizedBox(height: 14),
        for (final (i, c) in q.choix.indexed) ...[
          _ChoixReponse(
            lettre: String.fromCharCode(65 + i),
            texte: c.texte,
            selectionne: _choix == i,
            // Après vérification : la bonne réponse en vert, l'erreur éventuelle en rouge
            etat: !_verifie
                ? null
                : c.correct
                    ? true
                    : _choix == i
                        ? false
                        : null,
            onTap: _verifie ? null : () => setState(() => _choix = i),
          ),
          const SizedBox(height: 10),
        ],
        if (_verifie) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: AppCard(
              color: juste ? st.successBg : st.dangerBg,
              borderColor: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(juste ? Icons.check_circle_outline : Icons.lightbulb_outline, color: juste ? st.success : st.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      juste
                          ? 'Bonne réponse !'
                          : 'Pas tout à fait. La bonne réponse est $lettreCorrecte : ${q.choix[q.indexCorrect].texte}',
                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (!_verifie)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: st.warning, foregroundColor: Colors.white),
            onPressed: _choix == null ? null : _verifier,
            child: const Text('Vérifier ma réponse'),
          )
        else
          FilledButton.icon(
            iconAlignment: IconAlignment.end,
            onPressed: _suivant,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(_index + 1 >= total ? 'Voir mon score' : 'Question suivante'),
          ),
        if (!_verifie) ...[
          const SizedBox(height: 10),
          Text(
            _choix == null ? 'Choisissez une réponse.' : 'Vérifiez pour voir la correction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

// =====================================================================
// Composants
// =====================================================================

class _ChoixFormation extends StatelessWidget {
  final FormationResume f;
  final bool selectionne;
  final VoidCallback onTap;
  const _ChoixFormation({required this.f, required this.selectionne, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = f.avancement;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selectionne,
      child: AppCard(
        onTap: onTap,
        semantique: 'Formation ${f.titre}, ${a.total} chapitre${a.total > 1 ? 's' : ''}',
        color: selectionne ? scheme.primaryContainer : null,
        borderColor: selectionne ? scheme.primary : null,
        borderWidth: selectionne ? 2 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(selectionne ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selectionne ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${a.total} chapitre${a.total > 1 ? 's' : ''} · ${a.pourcentage}% suivi',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoixReponse extends StatelessWidget {
  final String lettre, texte;
  final bool selectionne;
  /// null : neutre ; true : bonne réponse révélée ; false : mauvaise réponse choisie.
  final bool? etat;
  final VoidCallback? onTap;
  const _ChoixReponse({required this.lettre, required this.texte, required this.selectionne, required this.etat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);

    final (Color? fond, Color? bord, Color pastille, IconData? icone) = switch (etat) {
      true => (st.successBg, st.success, st.success, Icons.check_circle),
      false => (st.dangerBg, st.danger, st.danger, Icons.cancel),
      null when selectionne => (scheme.primaryContainer, scheme.primary, scheme.primary, Icons.radio_button_checked),
      null => (null, null, scheme.outlineVariant, null),
    };
    final marque = etat != null || selectionne;
    final suffixe = etat == true ? ', bonne réponse' : etat == false ? ', réponse incorrecte' : '';

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selectionne,
      label: 'Réponse $lettre : $texte$suffixe',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: fond,
        borderColor: bord,
        borderWidth: marque ? 2 : 1,
        child: ExcludeSemantics(
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: marque ? pastille : pastille.withValues(alpha: 0.6),
                child: Text(lettre,
                    style: TextStyle(
                      color: marque ? Colors.white : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(texte,
                    style: TextStyle(fontWeight: marque ? FontWeight.w800 : FontWeight.w500, color: scheme.onSurface)),
              ),
              if (icone != null) Icon(icone, color: bord),
            ],
          ),
        ),
      ),
    );
  }
}

class _VuePreparation extends StatelessWidget {
  final VoidCallback onAnnuler;
  const _VuePreparation({required this.onAnnuler});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 52, color: StatusColors.of(context).warning),
            const SizedBox(height: 20),
            const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3.5)),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text('FAB’IA prépare vos questions…',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Text(
              'La première fois pour une formation, cela peut prendre jusqu’à deux minutes. Les parties suivantes démarrent tout de suite.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onAnnuler, child: const Text('Annuler')),
          ],
        ),
      ),
    );
  }
}

class _VueResultat extends StatelessWidget {
  final int bonnes, total;
  final String formation;
  final VoidCallback onRejouer, onChanger;
  const _VueResultat({
    required this.bonnes,
    required this.total,
    required this.formation,
    required this.onRejouer,
    required this.onChanger,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final pct = total == 0 ? 0 : (bonnes * 100 / total).round();
    final couleur = pct >= 50 ? st.success : st.warning;
    final message = pct == 100
        ? 'Sans faute, bravo ! 🎉'
        : pct >= 70
            ? 'Très bien, vous maîtrisez le sujet !'
            : pct >= 50
                ? 'Pas mal ! Encore un petit effort.'
                : 'Continuez à vous entraîner, ça vient !';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Semantics(
          liveRegion: true,
          label: 'Entraînement terminé. $bonnes bonnes réponses sur $total. $message',
          child: ExcludeSemantics(
            child: Column(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        color: couleur,
                        backgroundColor: scheme.outlineVariant,
                      ),
                      Center(
                        child: Text('$bonnes/$total', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: couleur)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('$formation · $pct % de bonnes réponses',
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          color: st.warningBg,
          borderColor: Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: st.warning),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Entraînement : ce score reste sur votre téléphone, il n’est pas transmis à l’équipe.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: st.warning, foregroundColor: Colors.white),
          onPressed: onRejouer,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Rejouer avec d’autres questions'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onChanger, child: const Text('Changer de formation')),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour aux devoirs')),
      ],
    );
  }
}
