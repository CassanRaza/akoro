import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ui.dart';

/// Passage d'un quiz (devoir QCM) : présentation → questions une à une → résultat.
class QuizScreen extends StatefulWidget {
  final QuizResume quiz;
  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  SessionQuiz? _session;
  ResultatQuiz? _resultat;
  String? _erreur;
  bool _chargement = false;
  bool _envoi = false;
  int? _choix; // choix sélectionné pour la question en cours
  Timer? _timer;
  Duration? _reste;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    // Quiz déjà commencé ou terminé : on l'ouvre directement (sinon écran de présentation)
    if (widget.quiz.etat == 'en_cours' || widget.quiz.etat == 'termine') _demarrer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final json = await _api.get('/mes-quiz/${widget.quiz.id}');
      final s = SessionQuiz.fromJson(Map<String, dynamic>.from(json as Map));
      if (!mounted) return;
      setState(() {
        _session = s;
        _resultat = s.resultat;
      });
      _lancerChrono();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _lancerChrono() {
    final fin = _session?.echeance;
    if (fin == null || _resultat != null) return;
    void tick() {
      final reste = fin.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _reste = reste.isNegative ? Duration.zero : reste);
      if (reste <= Duration.zero) {
        _timer?.cancel();
        _terminer(tempsEcoule: true);
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  QuestionQuiz? get _question => _session?.questions.where((q) => q.reponseChoixId == null).firstOrNull;
  int get _repondues => _session?.questions.where((q) => q.reponseChoixId != null).length ?? 0;

  Future<void> _valider() async {
    final q = _question;
    if (q == null || _choix == null || _envoi) return;
    setState(() => _envoi = true);
    try {
      await _api.post('/mes-quiz/${widget.quiz.id}/reponses', {'question_id': q.id, 'choix_id': _choix});
      if (!mounted) return;
      setState(() {
        q.reponseChoixId = _choix;
        _choix = null;
      });
      if (_question == null) await _terminer();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      if (e.message.contains('temps est écoulé')) await _terminer(tempsEcoule: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _terminer({bool tempsEcoule = false}) async {
    if (_resultat != null) return;
    setState(() => _envoi = true);
    try {
      final json = await _api.post('/mes-quiz/${widget.quiz.id}/terminer');
      final r = ResultatQuiz.fromJson(Map<String, dynamic>.from((json as Map)['resultat'] as Map));
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _resultat = r);
      if (tempsEcoule) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temps écoulé : vos réponses validées ont été enregistrées.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<bool> _confirmerSortie() async {
    if (_session == null || _resultat != null) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.timer_outlined),
        title: const Text('Quitter le quiz ?'),
        content: Text(_session!.echeance != null
            ? 'Vos réponses validées sont enregistrées, mais le chronomètre continue de tourner.'
            : 'Vos réponses validées sont enregistrées. Vous pourrez reprendre plus tard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer le quiz')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget corps;
    if (_chargement) {
      corps = const Center(child: CircularProgressIndicator());
    } else if (_erreur != null) {
      corps = EtatVide(
        icon: Icons.error_outline,
        titre: 'Quiz indisponible',
        texte: _erreur,
        action: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour')),
      );
    } else if (_resultat != null) {
      corps = _VueResultat(r: _resultat!, titre: widget.quiz.titre);
    } else if (_session == null) {
      corps = _Presentation(q: widget.quiz, onCommencer: _demarrer);
    } else {
      corps = _vueQuestion(scheme);
    }

    return PopScope(
      canPop: _session == null || _resultat != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmerSortie()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Text('Retour', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          actions: [
            if (_reste != null && _resultat == null) _Chrono(reste: _reste!),
            const ThemeToggleButton(),
          ],
        ),
        body: SafeArea(child: corps),
      ),
    );
  }

  Widget _vueQuestion(ColorScheme scheme) {
    final s = _session!;
    final q = _question;
    final st = StatusColors.of(context);
    if (q == null) return const Center(child: CircularProgressIndicator());
    final numero = _repondues + 1;
    final total = s.questions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Semantics(
          header: true,
          child: Text('Quiz – ${widget.quiz.titre}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Question en cours', style: TextStyle(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text('$numero sur $total', style: TextStyle(color: st.warning, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Question $numero sur $total',
          child: ExcludeSemantics(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _repondues
                          ? st.success
                          : i == _repondues
                              ? st.warning
                              : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Text(q.enonce, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
        ),
        const SizedBox(height: 14),
        for (final (i, c) in q.choix.indexed) ...[
          _Choix(
            lettre: String.fromCharCode(65 + i),
            texte: c.texte,
            selectionne: _choix == c.id,
            onTap: _envoi ? null : () => setState(() => _choix = c.id),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: st.warning, foregroundColor: Colors.white),
          onPressed: _choix == null || _envoi ? null : _valider,
          child: _envoi
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(numero == total ? 'Valider et terminer' : 'Valider la réponse'),
        ),
        const SizedBox(height: 10),
        Text(
          _choix == null ? 'Choisissez une réponse.' : 'Attention : une réponse validée ne peut plus être modifiée.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Presentation extends StatelessWidget {
  final QuizResume q;
  final VoidCallback onCommencer;
  const _Presentation({required this.q, required this.onCommencer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final fmt = DateFormat('EEEE d MMMM à HH:mm', 'fr');

    Widget ligne(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Icon(Icons.quiz_outlined, size: 56, color: st.warning),
        const SizedBox(height: 12),
        Text(q.titre, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if ((q.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(q.description!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              ligne(Icons.format_list_numbered, '${q.nbQuestions} question${q.nbQuestions > 1 ? 's' : ''} à choix multiple, une à la fois.'),
              ligne(Icons.timer_outlined, q.dureeMinutes != null
                  ? 'Durée : ${q.dureeMinutes} minutes, à partir du moment où vous commencez.'
                  : 'Pas de limite de durée.'),
              if (q.dateLimite != null) ligne(Icons.event_outlined, 'À terminer avant le ${fmt.format(q.dateLimite!)}.'),
              ligne(Icons.lock_clock_outlined, 'Une seule tentative : chaque réponse validée est définitive.'),
              ligne(Icons.cloud_done_outlined, 'Vos réponses sont enregistrées au fur et à mesure, même si le réseau coupe.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: st.warning, foregroundColor: Colors.white),
          onPressed: q.jouable ? onCommencer : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Commencer le quiz'),
        ),
        if (!q.jouable) ...[
          const SizedBox(height: 10),
          Text(
            q.etat == 'a_venir' && q.dateDebut != null
                ? 'Ce quiz ouvrira le ${fmt.format(q.dateDebut!)}.'
                : 'Ce quiz est fermé.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _Choix extends StatelessWidget {
  final String lettre, texte;
  final bool selectionne;
  final VoidCallback? onTap;
  const _Choix({required this.lettre, required this.texte, required this.selectionne, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selectionne,
      label: 'Réponse $lettre : $texte',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: selectionne ? scheme.primaryContainer : null,
        borderColor: selectionne ? scheme.primary : null,
        borderWidth: selectionne ? 2 : 1,
        child: ExcludeSemantics(
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: selectionne ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
                child: Text(lettre,
                    style: TextStyle(
                      color: selectionne ? scheme.onPrimary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(texte,
                    style: TextStyle(
                      fontWeight: selectionne ? FontWeight.w800 : FontWeight.w500,
                      color: selectionne ? scheme.onPrimaryContainer : scheme.onSurface,
                    )),
              ),
              if (selectionne) Icon(Icons.check_circle_outline, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chrono extends StatelessWidget {
  final Duration reste;
  const _Chrono({required this.reste});

  @override
  Widget build(BuildContext context) {
    final st = StatusColors.of(context);
    final urgent = reste.inSeconds <= 60;
    final m = reste.inMinutes.toString().padLeft(2, '0');
    final s = (reste.inSeconds % 60).toString().padLeft(2, '0');
    return Semantics(
      label: 'Temps restant : ${reste.inMinutes} minutes ${reste.inSeconds % 60} secondes',
      child: Tag('$m:$s', icon: Icons.timer_outlined, fg: urgent ? st.danger : st.warning, bg: urgent ? st.dangerBg : st.warningBg),
    );
  }
}

class _VueResultat extends StatelessWidget {
  final ResultatQuiz r;
  final String titre;
  const _VueResultat({required this.r, required this.titre});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final couleur = r.reussi ? st.success : st.warning;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Semantics(
          liveRegion: true,
          label: 'Quiz terminé. Note ${r.noteLisible}. ${r.score} points sur ${r.scoreMax}.',
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
                        value: (r.pourcentage ?? 0) / 100,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        color: couleur,
                        backgroundColor: scheme.outlineVariant,
                      ),
                      Center(
                        child: Text(r.noteLisible, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: couleur)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(r.reussi ? 'Bravo, quiz réussi ! 🎉' : 'Quiz terminé',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('$titre · ${r.score} / ${r.scoreMax} points (${r.pourcentage ?? 0} %)',
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          color: r.reussi ? st.successBg : st.warningBg,
          borderColor: Colors.transparent,
          child: Text(
            r.reussi
                ? 'Votre résultat est transmis à votre formateur.'
                : 'Votre résultat est transmis à votre formateur. Relisez les chapitres de la formation '
                    'et n’hésitez pas à poser vos questions à l’équipe ou à FAB’IA.',
            style: const TextStyle(height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Retour à la formation')),
      ],
    );
  }
}
