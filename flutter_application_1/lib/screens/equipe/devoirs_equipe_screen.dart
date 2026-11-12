import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';
import 'commun.dart';
import 'devoir_detail_equipe_screen.dart';
import 'parcours_screen.dart' show FormulaireFeuille;

/// Devoirs (équipe) : QCM programmés et devoirs à rendre. Toute l'équipe programme des devoirs, comme sur le web.
class DevoirsEquipeScreen extends StatefulWidget {
  const DevoirsEquipeScreen({super.key});

  @override
  State<DevoirsEquipeScreen> createState() => DevoirsEquipeScreenState();
}

class DevoirsEquipeScreenState extends State<DevoirsEquipeScreen> {
  final _recherche = TextEditingController();
  Timer? _attente;
  List<Map<String, dynamic>> _parcours = const [];
  int? _parcoursId;
  String? _type, _statut;

  List<Map<String, dynamic>> _liste = [];
  int _page = 1, _dernierePage = 1, _total = 0;
  bool _chargement = true, _plus = false;
  String? _erreur;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _api.get('/parcours').then((j) {
      if (mounted) setState(() => _parcours = enListe(j));
    }).catchError((_) {});
    _recherche.addListener(() {
      _attente?.cancel();
      _attente = Timer(const Duration(milliseconds: 350), recharger);
    });
    recharger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  Future<void> recharger() => _charger(page: 1);

  Future<void> _charger({required int page}) async {
    setState(() {
      if (page == 1) _chargement = _liste.isEmpty;
      _plus = page > 1;
      _erreur = null;
    });
    final q = Uri(queryParameters: {
      if (_parcoursId != null) 'parcours_id': '$_parcoursId',
      'type': ?_type,
      'statut': ?_statut,
      if (_recherche.text.trim().isNotEmpty) 'search': _recherche.text.trim(),
      'page': '$page',
    }).query;
    try {
      final j = enMap(await _api.get('/devoirs?$q'));
      if (!mounted) return;
      setState(() {
        final lot = enListe(j['data']);
        _liste = page == 1 ? lot : [..._liste, ...lot];
        _page = (j['current_page'] as num?)?.toInt() ?? 1;
        _dernierePage = (j['last_page'] as num?)?.toInt() ?? 1;
        _total = (j['total'] as num?)?.toInt() ?? _liste.length;
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

  Future<void> _creer() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireDevoir(api: _api, parcours: _parcours),
    );
    if (id == null || !mounted) return;
    afficherMessage(context, 'Devoir créé avec succès.');
    await _ouvrir(id);
  }

  Future<void> _ouvrir(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DevoirDetailEquipeScreen(id: id)));
    recharger();
  }

  Future<void> _supprimer(Map<String, dynamic> d) async {
    if (!await confirmer(context,
        titre: 'Supprimer ce devoir ?',
        message: 'Le devoir « ${d['titre']} » sera définitivement supprimé.',
        action: 'Supprimer',
        danger: true)) {
      return;
    }
    try {
      await _api.delete('/devoirs/${d['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Devoir supprimé.');
      recharger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: recharger,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const PageHeader(title: 'Devoirs', subtitle: 'QCM synchronisés et devoirs à rendre (PDF / photo)'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _recherche,
                      maxLength: 100,
                      decoration: const InputDecoration(hintText: 'Rechercher un devoir…', prefixIcon: Icon(Icons.search), counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    FiltreDeroulant<int>(
                      libelle: 'Parcours',
                      valeur: _parcoursId,
                      options: [(null, 'Tous'), for (final p in _parcours) ((p['id'] as num).toInt(), '${p['nom']}')],
                      onChanged: (v) {
                        _parcoursId = v;
                        recharger();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: FiltreDeroulant<String>(
                          libelle: 'Type',
                          valeur: _type,
                          options: const [(null, 'Tous'), ('qcm', 'QCM'), ('rendu', 'Rendu PDF')],
                          onChanged: (v) {
                            _type = v;
                            recharger();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FiltreDeroulant<String>(
                          libelle: 'Statut',
                          valeur: _statut,
                          options: [(null, 'Tous'), for (final e in libellesStatutDevoir.entries) (e.key, e.value)],
                          onChanged: (v) {
                            _statut = v;
                            recharger();
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_chargement)
                const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
              else if (_erreur != null && _liste.isEmpty)
                EtatErreur(message: _erreur!, onRetry: recharger)
              else if (_liste.isEmpty)
                const EtatVide(icon: Icons.assignment_outlined, titre: 'Aucun devoir', texte: 'Créez un QCM ou un devoir à rendre avec le bouton +.')
              else ...[
                for (final d in _liste)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                    child: AppCard(
                      onTap: () => _ouvrir((d['id'] as num).toInt()),
                      child: Row(
                        children: [
                          Icon(d['type'] == 'qcm' ? Icons.quiz_outlined : Icons.upload_file_outlined, color: scheme.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${d['titre']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  '${d['type'] == 'qcm' ? 'QCM' : 'Rendu PDF'} · ${enMap(d['parcours'])['nom'] ?? '—'}\n'
                                  '${d['type'] == 'qcm' ? 'Début : ${dateHeure(d['date_debut'])}' : 'Limite : ${dateHeure(d['date_limite'])}'}'
                                  ' · ${d['type'] == 'qcm' ? '${d['nb_resultats'] ?? 0} résultat(s)' : '${d['nb_soumissions'] ?? 0} rendu(s)'}',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Pastille(libellesStatutDevoir[d['statut']] ?? '${d['statut']}',
                                  ton: switch ('${d['statut']}') {
                                    'brouillon' => 'neutre',
                                    'programme' => 'info',
                                    'en_cours' => 'alerte',
                                    _ => 'succes',
                                  }),
                              IconButton(
                                tooltip: 'Supprimer',
                                onPressed: () => _supprimer(d),
                                icon: Icon(Icons.delete_outline, color: scheme.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ChargerPlus(
                  page: _page,
                  dernierePage: _dernierePage,
                  total: _total,
                  chargement: _plus,
                  unite: 'devoir(s)',
                  onPlus: () => _charger(page: _page + 1),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'ajout-devoir',
            onPressed: _creer,
            icon: const Icon(Icons.add),
            label: const Text('Devoir'),
          ),
        ),
      ],
    );
  }
}

/// Création d'un devoir — mêmes champs et règles que le web :
/// QCM : leçons de référence, date de début (future) et durée obligatoires ;
/// rendu : date limite obligatoire, consigne PDF facultative (10 Mo).
class _FormulaireDevoir extends StatefulWidget {
  final ApiService api;
  final List<Map<String, dynamic>> parcours;
  const _FormulaireDevoir({required this.api, required this.parcours});

  @override
  State<_FormulaireDevoir> createState() => _FormulaireDevoirState();
}

class _FormulaireDevoirState extends State<_FormulaireDevoir> {
  final _cle = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _description = TextEditingController();
  String _type = 'qcm';
  int? _parcoursId;
  List<Map<String, dynamic>> _lecons = const [];
  final Set<int> _leconIds = {};
  DateTime? _date;
  int _duree = 30;
  ({String nom, List<int> octets})? _consigne;
  Map<String, String> _erreurs = const {};
  bool _envoi = false;

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _choisirParcours(int? id) async {
    setState(() {
      _parcoursId = id;
      _leconIds.clear();
      _lecons = const [];
    });
    if (id == null) return;
    try {
      final j = await widget.api.get('/parcours/$id/lecons');
      if (mounted) setState(() => _lecons = enListe(j));
    } catch (_) {}
  }

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _date ?? now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date ?? now.add(const Duration(hours: 1))));
    if (t == null) return;
    setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _choisirConsigne() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (f == null) return;
    final octets = await f.readAsBytes();
    setState(() {
      if (octets.length > 10 * 1024 * 1024) {
        _erreurs = {..._erreurs, 'fichier_consigne': 'Le fichier ne doit pas dépasser 10 Mo.'};
      } else {
        _consigne = (nom: f.name, octets: octets);
        _erreurs = Map.of(_erreurs)..remove('fichier_consigne');
      }
    });
  }

  Future<void> _enregistrer() async {
    final e = <String, String>{};
    if (_parcoursId == null) e['parcours_id'] = 'Le parcours est obligatoire.';
    if (_type == 'qcm' && _leconIds.isEmpty) e['lecon_ids'] = 'Sélectionnez au moins une leçon de référence.';
    if (_date == null) {
      e[_type == 'qcm' ? 'date_debut' : 'date_limite'] =
          _type == 'qcm' ? 'La date et l’heure de début sont obligatoires pour un QCM programmé.' : 'La date limite de rendu est obligatoire.';
    } else if (_date!.isBefore(DateTime.now())) {
      e[_type == 'qcm' ? 'date_debut' : 'date_limite'] = 'La date doit être dans le futur.';
    }
    final formOk = _cle.currentState!.validate();
    setState(() => _erreurs = e);
    if (e.isNotEmpty || !formOk) return;

    if (!await confirmer(context, titre: 'Créer ce devoir ?', message: 'Le devoir « ${_titre.text.trim()} » sera créé en brouillon.', action: 'Créer')) {
      return;
    }
    setState(() => _envoi = true);
    final champs = <String, String>{
      'type': _type,
      'parcours_id': '$_parcoursId',
      'titre': _titre.text.trim(),
      'statut': 'brouillon',
      if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
      for (final (i, id) in _leconIds.indexed) 'lecon_ids[$i]': '$id',
      if (_type == 'qcm') ...{'date_debut': versIso(_date!), 'duree_minutes': '$_duree'} else 'date_limite': versIso(_date!),
    };
    try {
      final j = enMap(await widget.api.postMultipart('/devoirs', champs,
          file: _type == 'rendu' && _consigne != null ? ApiFile('fichier_consigne', _consigne!.nom, _consigne!.octets) : null));
      if (mounted) Navigator.pop(context, (j['id'] as num).toInt());
    } on ApiException catch (ex) {
      if (mounted) setState(() => _erreurs = ex.fieldErrors.isEmpty ? {'titre': ex.message} : ex.fieldErrors);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleDate = _type == 'qcm' ? 'date_debut' : 'date_limite';
    Widget erreur(String k) => _erreurs[k] == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(top: 4), child: Text(_erreurs[k]!, style: TextStyle(color: scheme.error, fontSize: 12.5)));

    return FormulaireFeuille(
      titre: 'Nouveau devoir',
      cle: _cle,
      envoi: _envoi,
      libelleAction: 'Créer le devoir',
      onValider: _enregistrer,
      champs: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'qcm', label: Text('QCM programmé'), icon: Icon(Icons.quiz_outlined)),
            ButtonSegment(value: 'rendu', label: Text('Rendu PDF'), icon: Icon(Icons.upload_file_outlined)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() {
            _type = s.first;
            _erreurs = const {};
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: _parcoursId,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Parcours *', errorText: _erreurs['parcours_id']),
          items: [for (final p in widget.parcours) DropdownMenuItem(value: (p['id'] as num).toInt(), child: Text('${p['nom']}'))],
          onChanged: _choisirParcours,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _titre,
          maxLength: 255,
          decoration: InputDecoration(labelText: 'Titre *', errorText: _erreurs['titre']),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Le titre est obligatoire (3 caractères minimum).' : null,
        ),
        TextFormField(
          controller: _description,
          maxLength: 2000,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Description', errorText: _erreurs['description']),
        ),
        if (_parcoursId != null) ...[
          const SizedBox(height: 4),
          Text(_type == 'qcm' ? 'Leçons de référence pour l’IA *' : 'Leçons liées (facultatif)',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_lecons.isEmpty)
            Text('Aucune leçon dans ce parcours.', style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final l in _lecons)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _leconIds.contains((l['id'] as num).toInt()),
                title: Text('${l['titre']}'),
                onChanged: (v) => setState(() {
                  final id = (l['id'] as num).toInt();
                  v == true ? _leconIds.add(id) : _leconIds.remove(id);
                }),
              ),
          erreur('lecon_ids'),
        ],
        const SizedBox(height: 12),
        InkWell(
          onTap: _choisirDate,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: _type == 'qcm' ? 'Date et heure de début *' : 'Date limite de rendu *',
              prefixIcon: const Icon(Icons.event),
              errorText: _erreurs[cleDate],
            ),
            child: Text(_date == null ? 'Choisir' : DateFormat('EEEE d MMMM y à HH:mm', 'fr').format(_date!)),
          ),
        ),
        if (_type == 'qcm') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duree,
            decoration: InputDecoration(labelText: 'Durée du QCM *', errorText: _erreurs['duree_minutes']),
            items: [for (final m in const [5, 10, 15, 20, 30, 45, 60, 90, 120, 180]) DropdownMenuItem(value: m, child: Text('$m minutes'))],
            onChanged: (v) => setState(() => _duree = v ?? 30),
          ),
          if (_date != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Fin du QCM : ${DateFormat('d MMM à HH:mm', 'fr').format(_date!.add(Duration(minutes: _duree)))}',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
        ] else ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _choisirConsigne,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_consigne?.nom ?? 'Fichier de consigne (PDF, facultatif)', overflow: TextOverflow.ellipsis),
          ),
          erreur('fichier_consigne'),
        ],
      ],
    );
  }
}
