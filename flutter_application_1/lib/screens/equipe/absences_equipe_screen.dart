import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/roles.dart';
import '../../widgets/ui.dart';
import '../beneficiaire/discussion/discussion_screen.dart' show AvatarPersonne;
import 'commun.dart';

/// Historique des absences (équipe) — mêmes règles que le web :
/// tous consultent ; seuls le Manager et le Super Admin justifient, valident, refusent ou annulent.
class AbsencesEquipeScreen extends StatefulWidget {
  const AbsencesEquipeScreen({super.key});

  @override
  State<AbsencesEquipeScreen> createState() => _AbsencesEquipeScreenState();
}

class _AbsencesEquipeScreenState extends State<AbsencesEquipeScreen> {
  static final _fmt = DateFormat('yyyy-MM-dd');
  final _recherche = TextEditingController();
  Timer? _attente;
  List<Map<String, dynamic>> _parcours = const [];
  int? _parcoursId;
  String? _statut;
  String _periode = 'month';
  DateTime? _debut, _fin;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _liste = [];
  int _page = 1, _dernierePage = 1, _total = 0;
  bool _chargement = true, _plus = false;
  String? _erreur;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _appliquerPeriode('month', charger: false);
    _api.get('/parcours').then((j) {
      if (mounted) setState(() => _parcours = enListe(j));
    }).catchError((_) {});
    _recherche.addListener(() {
      _attente?.cancel();
      _attente = Timer(const Duration(milliseconds: 350), () => _charger(page: 1));
    });
    _charger(page: 1);
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _appliquerPeriode(String p, {bool charger = true}) {
    final now = DateTime.now();
    final jour = DateTime(now.year, now.month, now.day);
    final (DateTime? debut, DateTime? fin) = switch (p) {
      'today' => (jour, jour),
      '7days' => (jour.subtract(const Duration(days: 6)), jour),
      '30days' => (jour.subtract(const Duration(days: 29)), jour),
      'month' => (DateTime(now.year, now.month, 1), jour),
      _ => (null, null),
    };
    setState(() {
      _periode = p;
      _debut = debut;
      _fin = fin;
    });
    if (charger) _charger(page: 1);
  }

  Future<void> _charger({required int page}) async {
    setState(() {
      if (page == 1) _chargement = _liste.isEmpty;
      _plus = page > 1;
      _erreur = null;
    });
    final q = Uri(queryParameters: {
      if (_debut != null) 'date_debut': _fmt.format(_debut!),
      if (_fin != null) 'date_fin': _fmt.format(_fin!),
      if (_parcoursId != null) 'parcours_id': '$_parcoursId',
      'statut': ?_statut,
      if (_recherche.text.trim().isNotEmpty) 'search': _recherche.text.trim(),
      'page': '$page',
    }).query;
    try {
      final j = enMap(await _api.get('/absences?$q'));
      final a = enMap(j['absences']);
      if (!mounted) return;
      setState(() {
        _stats = enMap(j['stats']);
        final lot = enListe(a['data']);
        _liste = page == 1 ? lot : [..._liste, ...lot];
        _page = (a['current_page'] as num?)?.toInt() ?? 1;
        _dernierePage = (a['last_page'] as num?)?.toInt() ?? 1;
        _total = (a['total'] as num?)?.toInt() ?? _liste.length;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _chargement = false;
          _plus = false;
        });
      }
    }
  }

  Future<void> _changerStatut(Map<String, dynamic> a, String statut) async {
    final valider = statut == 'justifiee';
    final nom = enMap(a['user'])['name'];
    if (!await confirmer(context,
        titre: '${valider ? 'Valider' : 'Refuser'} ce justificatif ?',
        message: 'Le justificatif de $nom du ${dateCourte(a['date'])} sera ${valider ? 'validé' : 'refusé'}.',
        action: valider ? 'Valider' : 'Refuser',
        danger: !valider)) {
      return;
    }
    try {
      await _api.put('/absences/${a['id']}', {'statut': statut});
      if (!mounted) return;
      afficherMessage(context, valider ? 'Justificatif validé avec succès.' : 'Justificatif refusé.');
      _charger(page: 1);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.fieldErrors['motif'] ?? e.message, erreur: true);
    }
  }

  Future<void> _justifier(Map<String, dynamic> a) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleJustifier(api: _api, absence: a),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Absence justifiée avec succès.');
      _charger(page: 1);
    }
  }

  Future<void> _annuler(Map<String, dynamic> a) async {
    if (!await confirmer(context,
        titre: 'Annuler cette absence ?',
        message: 'L’absence de ${enMap(a['user'])['name']} du ${dateCourte(a['date'])} sera supprimée.',
        action: 'Annuler l’absence',
        danger: true)) {
      return;
    }
    try {
      await _api.delete('/absences/${a['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Absence annulée avec succès.');
      _charger(page: 1);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peutTraiter = Roles.peutTraiterAbsences(context.watch<AuthProvider>().role);
    final scheme = Theme.of(context).colorScheme;
    final s = _stats;

    return PagePoussee(
      titre: 'Absences',
      corps: RefreshIndicator(
        onRefresh: () => _charger(page: 1),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              peutTraiter
                  ? 'Suivre et valider les justificatifs d’absences envoyés via l’application'
                  : 'Suivre les absences et les justificatifs envoyés via l’application',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (s != null) ...[
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _Chiffre('${s['total'] ?? 0}', 'Total des absences'),
                  _Chiffre('${s['non_justifiees'] ?? 0}', 'Non justifiées', ton: 'danger'),
                  _Chiffre('${s['a_valider'] ?? 0}', 'Justificatifs à valider', ton: 'alerte'),
                  _Chiffre(s['taux'] == null ? '—' : '${s['taux']} %', 'Taux d’absentéisme'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _recherche,
              maxLength: 100,
              decoration: const InputDecoration(hintText: 'Rechercher un bénéficiaire…', prefixIcon: Icon(Icons.search), counterText: ''),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (v, l) in const [
                  ('today', 'Aujourd’hui'),
                  ('7days', '7 jours'),
                  ('30days', '30 jours'),
                  ('month', 'Ce mois'),
                  ('all', 'Tout'),
                ])
                  ChoiceChip(label: Text(l), selected: _periode == v, onSelected: (_) => _appliquerPeriode(v)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FiltreDeroulant<int>(
                    libelle: 'Parcours',
                    valeur: _parcoursId,
                    options: [(null, 'Tous'), for (final p in _parcours) ((p['id'] as num).toInt(), '${p['nom']}')],
                    onChanged: (v) {
                      _parcoursId = v;
                      _charger(page: 1);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FiltreDeroulant<String>(
                    libelle: 'Justification',
                    valeur: _statut,
                    options: const [
                      (null, 'Toutes'),
                      ('non_justifiee', 'Non justifiées'),
                      ('a_valider', 'À valider'),
                      ('justifiee', 'Justifiées'),
                      ('refusee', 'Refusées'),
                    ],
                    onChanged: (v) {
                      _statut = v;
                      _charger(page: 1);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_chargement)
              const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
            else if (_erreur != null && _liste.isEmpty)
              EtatErreur(message: _erreur!, onRetry: () => _charger(page: 1))
            else if (_liste.isEmpty)
              const EtatVide(icon: Icons.event_available_outlined, titre: 'Aucune absence trouvée pour ces filtres')
            else ...[
              for (final a in _liste)
                _CarteAbsence(
                  a: a,
                  peutTraiter: peutTraiter,
                  onValider: () => _changerStatut(a, 'justifiee'),
                  onRefuser: () => _changerStatut(a, 'refusee'),
                  onJustifier: () => _justifier(a),
                  onAnnuler: () => _annuler(a),
                ),
              ChargerPlus(
                page: _page,
                dernierePage: _dernierePage,
                total: _total,
                chargement: _plus,
                unite: 'absence(s)',
                onPlus: () => _charger(page: _page + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  final String valeur, libelle;
  final String ton;
  const _Chiffre(this.valeur, this.libelle, {this.ton = 'neutre'});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(valeur, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
          ],
        ),
      );
}

class _CarteAbsence extends StatelessWidget {
  final Map<String, dynamic> a;
  final bool peutTraiter;
  final VoidCallback onValider, onRefuser, onJustifier, onAnnuler;
  const _CarteAbsence({
    required this.a,
    required this.peutTraiter,
    required this.onValider,
    required this.onRefuser,
    required this.onJustifier,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final u = enMap(a['user']);
    final statut = '${a['statut']}';
    final (libelle, ton) = libellesStatutAbsence[statut] ?? (statut, 'neutre');
    final seance = enMap(a['seance']);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarPersonne(nom: '${u['name'] ?? '?'}', photo: u['photo_url']?.toString(), rayon: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${u['name'] ?? '?'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${dateCourte(a['date'])} · ${enMap(u['parcours'])['nom'] ?? '—'}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
                Pastille(libelle, ton: ton),
              ],
            ),
            const SizedBox(height: 8),
            Text('${enMap(a['lecon'])['titre'] ?? 'Séance libre'}'
                '${seance.isEmpty ? '' : ' · ${hhmm(seance['heure_debut'])} – ${hhmm(seance['heure_fin'])}'}'),
            Text('Motif : ${a['motif'] ?? 'Pas de motif fourni'}', style: TextStyle(color: scheme.onSurfaceVariant)),
            if (peutTraiter)
              Wrap(
                spacing: 4,
                children: [
                  if (statut == 'a_valider') ...[
                    TextButton.icon(onPressed: onValider, icon: const Icon(Icons.check), label: const Text('Valider')),
                    TextButton.icon(
                      onPressed: onRefuser,
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      icon: const Icon(Icons.close),
                      label: const Text('Refuser'),
                    ),
                  ],
                  if (statut == 'non_justifiee' || statut == 'refusee')
                    TextButton.icon(onPressed: onJustifier, icon: const Icon(Icons.edit_note), label: const Text('Justifier')),
                  TextButton.icon(
                    onPressed: onAnnuler,
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Annuler l’absence'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FeuilleJustifier extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> absence;
  const _FeuilleJustifier({required this.api, required this.absence});

  @override
  State<_FeuilleJustifier> createState() => _FeuilleJustifierState();
}

class _FeuilleJustifierState extends State<_FeuilleJustifier> {
  late final _motif = TextEditingController(text: '${widget.absence['motif'] ?? ''}');
  String? _erreur;
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final m = _motif.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (m.length < 3) {
      setState(() => _erreur = 'Le motif est obligatoire (3 caractères minimum).');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await widget.api.put('/absences/${widget.absence['id']}', {'statut': 'justifiee', 'motif': m});
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.fieldErrors['motif'] ?? e.message);
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
              Text('Justifier l’absence', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${enMap(widget.absence['user'])['name']} — absence du ${dateCourte(widget.absence['date'])}'),
              const SizedBox(height: 14),
              TextField(
                controller: _motif,
                autofocus: true,
                maxLength: 255,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Motif de l’absence *', errorText: _erreur),
                onChanged: (_) => setState(() => _erreur = null),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _envoi ? null : _valider,
                child: _envoi
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Justifier'),
              ),
              TextButton(onPressed: _envoi ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
            ],
          ),
        ),
      );
}
