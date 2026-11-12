import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart' show SectionTitle;
import '../../widgets/ui.dart';
import '../beneficiaire/discussion/discussion_screen.dart' show AvatarPersonne;
import 'commun.dart';

const _statutRendu = {'en_attente': ('Pas encore rendu', 'neutre'), 'rendu': ('À corriger', 'alerte'), 'corrige': ('Corrigé', 'succes')};
const _statutQuiz = {'non_commence': 'Pas commencé', 'en_cours': 'En cours', 'termine': 'Terminé'};

/// Détail d'un devoir (équipe) : informations, statut, questions (manuelles ou IA), résultats, rendus et correction.
class DevoirDetailEquipeScreen extends StatefulWidget {
  final int id;
  const DevoirDetailEquipeScreen({super.key, required this.id});

  @override
  State<DevoirDetailEquipeScreen> createState() => _DevoirDetailEquipeScreenState();
}

class _DevoirDetailEquipeScreenState extends State<DevoirDetailEquipeScreen> {
  Map<String, dynamic>? _d;
  String? _erreur;
  bool _generation = false;
  int _nbIa = 5;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final j = enMap(await _api.get('/devoirs/${widget.id}'));
      if (mounted) setState(() => _d = j);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _changerStatut(String statut) async {
    final titres = {'programme': 'Programmer ce devoir', 'en_cours': 'Lancer la session', 'termine': 'Terminer ce devoir'};
    if (!await confirmer(context,
        titre: '${titres[statut]} ?',
        message: 'Le statut passera à « ${libellesStatutDevoir[statut]} ».'
            '${statut == 'programme' ? ' Les bénéficiaires du parcours seront prévenus sur l’application.' : ''}',
        action: 'Confirmer')) {
      return;
    }
    try {
      await _api.put('/devoirs/${widget.id}', {'statut': statut});
      if (!mounted) return;
      afficherMessage(context, 'Statut mis à jour.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _modifierDateLimite() async {
    final actuelle = lireDate(_d!['date_limite']) ?? DateTime.now();
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: actuelle.isBefore(now) ? now : actuelle,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(actuelle));
    if (t == null) return;
    final nouvelle = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    try {
      await _api.put('/devoirs/${widget.id}', {'date_limite': versIso(nouvelle)});
      if (!mounted) return;
      afficherMessage(context, 'Date limite mise à jour.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.fieldErrors['date_limite'] ?? e.message, erreur: true);
    }
  }

  Future<void> _genererIa() async {
    if (!await confirmer(context,
        titre: 'Générer des questions par IA ?',
        message: '$_nbIa question(s) seront créées à partir du contenu des fichiers liés aux leçons de ce devoir (3 choix chacune). '
            'Comptez jusqu’à 2 minutes.',
        action: 'Générer')) {
      return;
    }
    setState(() => _generation = true);
    try {
      await _api.post('/devoirs/${widget.id}/generer-questions', {'nombre': _nbIa}, const Duration(minutes: 5));
      if (!mounted) return;
      afficherMessage(context, 'Questions générées avec succès.');
      await _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.fieldErrors['ia'] ?? e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  Future<void> _questionnaire() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _QuestionnaireScreen(api: _api, devoirId: widget.id)));
    if (ok == true && mounted) {
      afficherMessage(context, 'Questionnaire enregistré.');
      _charger();
    }
  }

  Future<void> _corriger(Map<String, dynamic> s) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleCorrection(api: _api, soumission: s),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Note enregistrée : le bénéficiaire est prévenu sur l’application.');
      _charger();
    }
  }

  Future<void> _ouvrir(String? lien) async {
    if (lien == null) return;
    if (!await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication) && mounted) {
      afficherMessage(context, 'Impossible d’ouvrir le fichier.', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return PagePoussee(
        titre: 'Devoir',
        corps: _erreur != null ? EtatErreur(message: _erreur!, onRetry: _charger) : const Center(child: CircularProgressIndicator()),
      );
    }
    final qcm = d['type'] == 'qcm';
    final statut = '${d['statut']}';
    final questions = enListe(d['questions']);
    final resultats = enListe(d['resultats']);
    final rendus = enListe(d['soumissions']).where((s) => s['statut'] != 'en_attente').toList();
    final lecons = enListe(d['lecons']).map((l) => '${l['titre']}').join(', ');
    final scheme = Theme.of(context).colorScheme;

    final onglets = qcm ? ['Questions (${questions.length})', 'Résultats (${resultats.length})'] : ['Rendus (${rendus.length})'];

    return DefaultTabController(
      length: onglets.length,
      child: Scaffold(
        appBar: AppBar(title: Text('${d['titre']}', overflow: TextOverflow.ellipsis)),
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${qcm ? 'QCM programmé' : 'Rendu PDF'} · ${enMap(d['parcours'])['nom'] ?? '—'}',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                        Pastille(libellesStatutDevoir[statut] ?? statut, ton: statut == 'brouillon' ? 'neutre' : 'info'),
                      ]),
                      const SizedBox(height: 10),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (qcm) ...[
                              _Ligne('Début', dateHeure(d['date_debut'])),
                              _Ligne('Fin du QCM', dateHeure(d['date_limite'])),
                              _Ligne('Durée', '${d['duree_minutes'] ?? '—'} min'),
                            ] else
                              Row(children: [
                                Expanded(child: _Ligne('Date limite', dateHeure(d['date_limite']))),
                                TextButton(onPressed: _modifierDateLimite, child: const Text('Modifier')),
                              ]),
                            _Ligne('Créé par', '${enMap(d['createur'])['name'] ?? '—'}'),
                            _Ligne('Leçon(s)', lecons.isEmpty ? '${enMap(d['lecon'])['titre'] ?? '—'}' : lecons),
                            const SizedBox(height: 6),
                            Text('${(d['description'] ?? '').toString().isEmpty ? 'Aucune description.' : d['description']}'),
                            if (!qcm && d['consigne_url'] != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _ouvrir('${d['consigne_url']}'),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Ouvrir la consigne (PDF)'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (statut == 'brouillon')
                        FilledButton.icon(
                          onPressed: () => _changerStatut('programme'),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Programmer'),
                        ),
                      if (statut == 'programme' && qcm)
                        FilledButton.icon(
                          onPressed: () => _changerStatut('en_cours'),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Lancer la session'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: TabBar(tabs: [for (final o in onglets) Tab(text: o)])),
            ],
            body: TabBarView(
              children: [
                if (qcm) ...[
                  _ongletQuestions(questions, scheme),
                  _ongletResultats(resultats),
                ] else
                  _ongletRendus(rendus, d),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ongletQuestions(List<Map<String, dynamic>> questions, ColorScheme scheme) {
    final st = StatusColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        OutlinedButton.icon(onPressed: _questionnaire, icon: const Icon(Icons.edit_note), label: const Text('Créer un questionnaire')),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<int>(
                initialValue: _nbIa,
                decoration: const InputDecoration(labelText: 'Nombre', isDense: true),
                items: [for (var i = 1; i <= 20; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                onChanged: (v) => setState(() => _nbIa = v ?? 5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _generation ? null : _genererIa,
                icon: _generation
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_generation ? 'Génération…' : 'Générer par IA'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (questions.isEmpty)
          const EtatVide(icon: Icons.quiz_outlined, titre: 'Aucune question', texte: 'Ajoutez-en manuellement ou générez-les par IA.')
        else
          for (final (i, q) in questions.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${q['points']} pt(s)', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${q['enonce']}'),
                    const SizedBox(height: 6),
                    for (final c in enListe(q['choix']))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(c['est_correct'] == true ? Icons.check_circle : Icons.circle_outlined,
                                size: 18, color: c['est_correct'] == true ? st.success : scheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${c['texte']}',
                                  style: TextStyle(fontWeight: c['est_correct'] == true ? FontWeight.w700 : FontWeight.w400)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _ongletResultats(List<Map<String, dynamic>> resultats) => resultats.isEmpty
      ? const EtatVide(icon: Icons.leaderboard_outlined, titre: 'Aucun résultat pour le moment')
      : ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            for (final r in resultats)
              ListTile(
                leading: AvatarPersonne(nom: '${enMap(r['user'])['name'] ?? '?'}', photo: enMap(r['user'])['photo_url']?.toString(), rayon: 18),
                title: Text('${enMap(r['user'])['name'] ?? '?'}'),
                subtitle: Text('${_statutQuiz[r['statut']] ?? r['statut']} · ${dateHeure(r['termine_le'])}'),
                trailing: Text(
                  '${r['score']}/${r['score_max']}${r['pourcentage'] != null ? '\n${r['pourcentage']} %' : ''}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        );

  Widget _ongletRendus(List<Map<String, dynamic>> rendus, Map<String, dynamic> d) {
    final corriges = rendus.where((s) => s['statut'] == 'corrige').length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '${rendus.length} rendu(s)${d['nb_beneficiaires'] != null ? ' sur ${d['nb_beneficiaires']} bénéficiaire(s)' : ''} · $corriges corrigé(s)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (rendus.isEmpty)
          const EtatVide(
            icon: Icons.inbox_outlined,
            titre: 'Aucun rendu pour le moment',
            texte: 'Les bénéficiaires déposent leur fichier (PDF ou photo) depuis l’application.',
          )
        else
          for (final s in rendus)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      AvatarPersonne(nom: '${enMap(s['user'])['name'] ?? '?'}', photo: enMap(s['user'])['photo_url']?.toString(), rayon: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${enMap(s['user'])['name'] ?? '?'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('Rendu le ${dateHeure(s['date_soumission'])}', style: const TextStyle(fontSize: 12.5)),
                        ]),
                      ),
                      Pastille(_statutRendu[s['statut']]?.$1 ?? '${s['statut']}', ton: _statutRendu[s['statut']]?.$2 ?? 'neutre'),
                    ]),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        if (s['fichier_url'] != null)
                          TextButton.icon(
                            onPressed: () => _ouvrir('${s['fichier_url']}'),
                            icon: const Icon(Icons.insert_drive_file_outlined),
                            label: Text('${s['nom_fichier'] ?? 'Fichier rendu'}', overflow: TextOverflow.ellipsis),
                          ),
                        if (s['note'] != null) Text('Note : ${num.tryParse('${s['note']}') ?? s['note']}/20', style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextButton.icon(
                          onPressed: () => _corriger(s),
                          icon: const Icon(Icons.grading_outlined),
                          label: Text(s['statut'] == 'corrige' ? 'Modifier la note' : 'Évaluer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  final String libelle, valeur;
  const _Ligne(this.libelle, this.valeur);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(libelle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Évaluation d'un rendu : note sur 20 (pas de 0,5) et commentaire visible par le bénéficiaire.
class _FeuilleCorrection extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> soumission;
  const _FeuilleCorrection({required this.api, required this.soumission});

  @override
  State<_FeuilleCorrection> createState() => _FeuilleCorrectionState();
}

class _FeuilleCorrectionState extends State<_FeuilleCorrection> {
  late final _note = TextEditingController(text: widget.soumission['note'] == null ? '' : '${num.tryParse('${widget.soumission['note']}') ?? ''}');
  late final _commentaire = TextEditingController(text: '${widget.soumission['commentaire'] ?? ''}');
  Map<String, String> _erreurs = const {};
  bool _envoi = false;

  @override
  void dispose() {
    _note.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final v = double.tryParse(_note.text.replaceAll(',', '.').trim());
    if (v == null || v < 0 || v > 20) {
      setState(() => _erreurs = {'note': 'Saisissez une note entre 0 et 20.'});
      return;
    }
    setState(() {
      _envoi = true;
      _erreurs = const {};
    });
    try {
      await widget.api.put('/soumissions/${widget.soumission['id']}/corriger', {
        'note': v,
        'commentaire': _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurs = e.fieldErrors.isEmpty ? {'note': e.message} : e.fieldErrors);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.soumission['statut'] == 'corrige' ? 'Modifier la note' : 'Évaluer le rendu',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('${enMap(widget.soumission['user'])['name'] ?? ''}'),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Note (/20) *', errorText: _erreurs['note']),
                onChanged: (_) => setState(() => _erreurs = const {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentaire,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Commentaire (visible par le bénéficiaire)', errorText: _erreurs['commentaire']),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _envoi ? null : _valider,
                child: _envoi
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Enregistrer la note'),
              ),
              TextButton(onPressed: _envoi ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
            ],
          ),
        ),
      );
}

/// Questionnaire manuel : 5 à 20 questions, 3 choix chacune, une seule bonne réponse (règles du web et du serveur).
class _QuestionnaireScreen extends StatefulWidget {
  final ApiService api;
  final int devoirId;
  const _QuestionnaireScreen({required this.api, required this.devoirId});

  @override
  State<_QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionBrouillon {
  final enonce = TextEditingController();
  final choix = [TextEditingController(), TextEditingController(), TextEditingController()];
  int bonne = 0;
  int points = 1;

  void dispose() {
    enonce.dispose();
    for (final c in choix) {
      c.dispose();
    }
  }
}

class _QuestionnaireScreenState extends State<_QuestionnaireScreen> {
  static const _min = 5, _max = 20;
  final List<_QuestionBrouillon> _questions = List.generate(_min, (_) => _QuestionBrouillon());
  final Map<int, String> _erreurs = {};
  bool _envoi = false;

  @override
  void dispose() {
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    _erreurs.clear();
    for (final (i, q) in _questions.indexed) {
      if (q.enonce.text.trim().length < 5) {
        _erreurs[i] = 'Écrivez l’énoncé (5 caractères minimum).';
      } else if (q.choix.any((c) => c.text.trim().isEmpty)) {
        _erreurs[i] = 'Les trois choix de réponse sont obligatoires.';
      }
    }
    setState(() {});
    if (_erreurs.isNotEmpty) {
      afficherMessage(context, 'Complétez la question ${_erreurs.keys.first + 1}.', erreur: true);
      return;
    }
    setState(() => _envoi = true);
    try {
      await widget.api.post('/devoirs/${widget.devoirId}/questions', {
        'questions': [
          for (final q in _questions)
            {
              'enonce': q.enonce.text.trim(),
              'points': q.points,
              'choix': [for (final (i, c) in q.choix.indexed) {'texte': c.text.trim(), 'est_correct': i == q.bonne}],
            },
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PagePoussee(
      titre: 'Créer un questionnaire',
      corps: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Préparez au moins $_min questions. Chaque question comporte trois réponses et une seule bonne réponse '
              '(touchez la pastille de la bonne réponse).',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          for (final (i, q) in _questions.indexed) ...[
            SectionTitle(
              'Question ${i + 1}',
              action: _questions.length > _min
                  ? TextButton(
                      onPressed: () => setState(() {
                        _questions.removeAt(i).dispose();
                        _erreurs.clear();
                      }),
                      child: const Text('Retirer'),
                    )
                  : null,
            ),
            TextField(
              controller: q.enonce,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'Énoncé *', errorText: _erreurs[i]),
            ),
            const SizedBox(height: 8),
            for (var c = 0; c < 3; c++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Choix ${c + 1} : bonne réponse',
                      onPressed: () => setState(() => q.bonne = c),
                      icon: Icon(q.bonne == c ? Icons.radio_button_checked : Icons.radio_button_off, color: scheme.primary),
                    ),
                    Expanded(
                      child: TextField(controller: q.choix[c], decoration: InputDecoration(labelText: 'Choix ${c + 1} *', isDense: true)),
                    ),
                  ],
                ),
              ),
            DropdownButtonFormField<int>(
              initialValue: q.points,
              decoration: const InputDecoration(labelText: 'Points', isDense: true),
              items: [for (var p = 1; p <= 5; p++) DropdownMenuItem(value: p, child: Text('$p'))],
              onChanged: (v) => q.points = v ?? 1,
            ),
          ],
          const SizedBox(height: 14),
          if (_questions.length < _max)
            OutlinedButton.icon(
              onPressed: () => setState(() => _questions.add(_QuestionBrouillon())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une question'),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _envoi ? null : _enregistrer,
            child: _envoi
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text('Enregistrer le questionnaire (${_questions.length} questions)'),
          ),
        ],
      ),
    );
  }
}

/// Format court utilisé ailleurs.
final formatJour = DateFormat('d MMM', 'fr');
