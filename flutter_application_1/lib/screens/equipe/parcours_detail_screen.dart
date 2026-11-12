import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart' show SectionTitle;
import '../../widgets/ui.dart';
import '../beneficiaire/discussion/discussion_screen.dart' show AvatarPersonne;
import 'commun.dart';
import 'parcours_screen.dart' show FormulaireFeuille, verifierLibelle;

/// Extensions acceptées pour les documents de leçon (identiques à Rules::extensionsFichier()).
const extensionsDocuments = [
  'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'ppt', 'pptx', 'odp', 'xls', 'xlsx', 'ods', 'csv',
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'zip', 'stl', 'dxf', 'svg', 'ino',
];
const _maxDocument = 20 * 1024 * 1024;

String tailleLisible(dynamic o) {
  final n = (o as num?)?.toInt() ?? 0;
  if (n <= 0) return '';
  return n < 1024 * 1024 ? '${(n / 1024).ceil()} Ko' : '${(n / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

/// Choisit un document de leçon et vérifie format et taille avant l'envoi.
Future<({ApiFile? fichier, String? erreur})?> choisirDocument() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensionsDocuments);
  if (f == null) return null;
  final ext = (f.extension ?? '').toLowerCase();
  if (!extensionsDocuments.contains(ext)) {
    return (fichier: null, erreur: 'Format non autorisé. Formats acceptés : Word, PowerPoint, Excel, PDF, images, ZIP, STL, DXF, SVG, INO.');
  }
  final octets = await f.readAsBytes();
  if (octets.length > _maxDocument) return (fichier: null, erreur: 'Le fichier est trop volumineux (20 Mo maximum).');
  return (fichier: ApiFile('fichier', f.name, octets), erreur: null);
}

/// Détail d'un parcours : leçons (ajout, modification, suppression, documents) et séances (planification, QR).
/// Accessible à toute l'équipe, comme sur le web.
class ParcoursDetailScreen extends StatefulWidget {
  final int id;
  final bool ajoutLecon;
  const ParcoursDetailScreen({super.key, required this.id, this.ajoutLecon = false});

  @override
  State<ParcoursDetailScreen> createState() => _ParcoursDetailScreenState();
}

class _ParcoursDetailScreenState extends State<ParcoursDetailScreen> {
  Map<String, dynamic>? _parcours;
  List<Map<String, dynamic>> _lecons = const [];
  List<Map<String, dynamic>> _seances = const [];
  String? _erreur;
  int? _envoiDocPour;
  final Map<int, String> _erreursLecon = {};

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger().then((_) {
      if (widget.ajoutLecon && mounted) _formLecon();
    });
  }

  Future<void> _charger() async {
    try {
      final r = await Future.wait([
        _api.get('/parcours/${widget.id}'),
        _api.get('/parcours/${widget.id}/lecons'),
        _api.get('/parcours/${widget.id}/seances'),
      ]);
      if (!mounted) return;
      setState(() {
        _parcours = enMap(r[0]);
        _lecons = enListe(r[1]);
        _seances = enListe(r[2]);
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  // ---------- Leçons ----------
  Future<void> _formLecon([Map<String, dynamic>? lecon]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireLecon(api: _api, parcoursId: widget.id, lecon: lecon),
    );
    if (ok == true && mounted) {
      afficherMessage(context, lecon == null ? 'Leçon ajoutée avec succès.' : 'Leçon modifiée avec succès.');
      _charger();
    }
  }

  Future<void> _supprimerLecon(Map<String, dynamic> l) async {
    if (!await confirmer(context,
        titre: 'Supprimer cette leçon ?',
        message: 'Cette leçon et tous les documents associés seront supprimés.',
        action: 'Supprimer',
        danger: true)) {
      return;
    }
    try {
      await _api.delete('/lecons/${l['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Leçon supprimée avec succès.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _ajouterDocument(Map<String, dynamic> l) async {
    final id = (l['id'] as num).toInt();
    final choix = await choisirDocument();
    if (choix == null || !mounted) return;
    if (choix.erreur != null) {
      setState(() => _erreursLecon[id] = choix.erreur!);
      return;
    }
    if (!await confirmer(context,
        titre: 'Ajouter ce document ?',
        message: '« ${choix.fichier!.filename} » sera ajouté à la leçon « ${l['titre']} ».',
        action: 'Ajouter')) {
      return;
    }
    setState(() {
      _envoiDocPour = id;
      _erreursLecon.remove(id);
    });
    try {
      await _api.postMultipart('/lecons/$id/ressources', const {}, file: choix.fichier, timeout: const Duration(minutes: 3));
      if (!mounted) return;
      afficherMessage(context, 'Fichier ajouté avec succès.');
      await _charger();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreursLecon[id] = e.fieldErrors['fichier'] ?? e.message);
    } finally {
      if (mounted) setState(() => _envoiDocPour = null);
    }
  }

  Future<void> _supprimerDocument(Map<String, dynamic> r) async {
    if (!await confirmer(context,
        titre: 'Supprimer ce document ?', message: 'Le document « ${r['titre']} » sera supprimé.', action: 'Supprimer', danger: true)) {
      return;
    }
    try {
      await _api.delete('/ressources/${r['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Document supprimé avec succès.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _ouvrirDocument(Map<String, dynamic> r) async {
    final lien = r['url']?.toString();
    if (lien == null) return;
    if (!await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication) && mounted) {
      afficherMessage(context, 'Impossible d’ouvrir le document.', erreur: true);
    }
  }

  // ---------- Séances ----------
  Future<void> _planifier() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireSeance(api: _api, parcoursId: widget.id, lecons: _lecons),
    );
    if (ok == true && mounted) {
      afficherMessage(context, 'Séance planifiée avec succès.');
      _charger();
    }
  }

  Future<void> _supprimerSeance(Map<String, dynamic> s) async {
    if (!await confirmer(context,
        titre: 'Supprimer cette séance ?', message: 'Cette séance planifiée sera supprimée.', action: 'Supprimer', danger: true)) {
      return;
    }
    try {
      await _api.delete('/seances/${s['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Séance supprimée avec succès.');
      _charger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _parcours;
    if (p == null) {
      return PagePoussee(
        titre: 'Parcours',
        corps: _erreur != null ? EtatErreur(message: _erreur!, onRetry: _charger) : const Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final aujourdhui = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final aVenir = _seances.where((s) => '${s['date']}'.substring(0, 10).compareTo(aujourdhui) >= 0).toList();
    final passees = _seances.where((s) => '${s['date']}'.substring(0, 10).compareTo(aujourdhui) < 0).toList().reversed.take(5).toList();

    return PagePoussee(
      titre: '${p['nom']}',
      boutonFlottant: FloatingActionButton.extended(
        heroTag: 'ajout-lecon',
        onPressed: () => _formLecon(),
        icon: const Icon(Icons.add),
        label: const Text('Leçon'),
      ),
      corps: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
          children: [
            Text('${(p['description'] ?? '').toString().isEmpty ? 'Sans description' : p['description']}',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            SectionTitle('Leçons (${_lecons.length})'),
            if (_lecons.isEmpty)
              const EtatVide(icon: Icons.menu_book_outlined, titre: 'Aucune leçon dans ce parcours pour le moment'),
            for (final (i, l) in _lecons.indexed) ...[
              _CarteLecon(
                numero: i + 1,
                l: l,
                envoi: _envoiDocPour == l['id'],
                erreur: _erreursLecon[(l['id'] as num).toInt()],
                onModifier: () => _formLecon(l),
                onSupprimer: () => _supprimerLecon(l),
                onAjouterDoc: () => _ajouterDocument(l),
                onOuvrirDoc: _ouvrirDocument,
                onSupprimerDoc: _supprimerDocument,
              ),
              const SizedBox(height: 10),
            ],
            SectionTitle(
              'Séances planifiées',
              action: TextButton.icon(onPressed: _planifier, icon: const Icon(Icons.event_available), label: const Text('Planifier')),
            ),
            Text(
              'Chaque séance a son QR code de présence : affichez-le pendant la séance, les bénéficiaires le scannent avec l’application. '
              'Celui qui ne l’a pas scanné est marqué absent.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (aVenir.isEmpty)
              const EtatVide(icon: Icons.event_busy_outlined, titre: 'Aucune séance à venir pour ce parcours')
            else
              for (final s in aVenir)
                _LigneSeance(
                  s: s,
                  onQr: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SeanceQrScreen(seanceId: (s['id'] as num).toInt()))),
                  onSupprimer: () => _supprimerSeance(s),
                ),
            if (passees.isNotEmpty) ...[
              const SectionTitle('Passées (5 dernières)'),
              for (final s in passees) _LigneSeance(s: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarteLecon extends StatelessWidget {
  final int numero;
  final Map<String, dynamic> l;
  final bool envoi;
  final String? erreur;
  final VoidCallback onModifier, onSupprimer, onAjouterDoc;
  final ValueChanged<Map<String, dynamic>> onOuvrirDoc, onSupprimerDoc;
  const _CarteLecon({
    required this.numero,
    required this.l,
    required this.envoi,
    required this.erreur,
    required this.onModifier,
    required this.onSupprimer,
    required this.onAjouterDoc,
    required this.onOuvrirDoc,
    required this.onSupprimerDoc,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final docs = enListe(l['ressources']);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: scheme.primaryContainer,
                child: Text('$numero', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('${l['titre']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
              PopupMenuButton<String>(
                tooltip: 'Actions de la leçon',
                onSelected: (v) => switch (v) {
                  'doc' => onAjouterDoc(),
                  'modifier' => onModifier(),
                  _ => onSupprimer(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'doc', child: Text('Ajouter un fichier')),
                  const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                  PopupMenuItem(value: 'supprimer', child: Text('Supprimer la leçon', style: TextStyle(color: scheme.error))),
                ],
              ),
            ],
          ),
          if ((l['description'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, right: 10, top: 2),
              child: Text('${l['description']}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            ),
          for (final r in docs)
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: ListTile(
                dense: true,
                minTileHeight: 48,
                contentPadding: const EdgeInsets.only(left: 12),
                leading: Tag('${r['type'] ?? 'fichier'}', fg: scheme.primary, bg: scheme.primaryContainer),
                title: Text('${r['titre']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(tailleLisible(r['taille'])),
                onTap: () => onOuvrirDoc(r),
                trailing: IconButton(
                  tooltip: 'Supprimer le document',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => onSupprimerDoc(r),
                ),
              ),
            ),
          if (envoi)
            const Padding(
              padding: EdgeInsets.only(left: 42, top: 6),
              child: Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Envoi du fichier…'),
              ]),
            ),
          if (erreur != null)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 6, right: 10),
              child: Text(erreur!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _LigneSeance extends StatelessWidget {
  final Map<String, dynamic> s;
  final VoidCallback? onQr, onSupprimer;
  const _LigneSeance({required this.s, this.onQr, this.onSupprimer});

  @override
  Widget build(BuildContext context) {
    final d = lireDate(s['date']);
    final jour = d == null ? '' : DateFormat('EEEE d MMMM', 'fr').format(d);
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onQr == null ? 0.7 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: Icon(Icons.event_outlined, color: scheme.primary),
        title: Text('${jour.isEmpty ? '' : jour[0].toUpperCase() + jour.substring(1)} · ${hhmm(s['heure_debut'])} – ${hhmm(s['heure_fin'])}'),
        subtitle: Text('${enMap(s['lecon'])['titre'] ?? 'Séance libre'}'),
        trailing: onQr == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Afficher le QR code de présence', onPressed: onQr, icon: const Icon(Icons.qr_code_2)),
                IconButton(
                  tooltip: 'Supprimer la séance',
                  onPressed: onSupprimer,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ]),
      ),
    );
  }
}

/// Ajout / modification d'une leçon (fichier facultatif à l'ajout, comme sur le web).
class _FormulaireLecon extends StatefulWidget {
  final ApiService api;
  final int parcoursId;
  final Map<String, dynamic>? lecon;
  const _FormulaireLecon({required this.api, required this.parcoursId, this.lecon});

  @override
  State<_FormulaireLecon> createState() => _FormulaireLeconState();
}

class _FormulaireLeconState extends State<_FormulaireLecon> {
  final _cle = GlobalKey<FormState>();
  late final _titre = TextEditingController(text: '${widget.lecon?['titre'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.lecon?['description'] ?? ''}');
  ApiFile? _fichier;
  Map<String, String> _erreurs = const {};
  bool _envoi = false;

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _choisir() async {
    final c = await choisirDocument();
    if (c == null) return;
    setState(() {
      _fichier = c.fichier;
      _erreurs = {..._erreurs, 'fichier': c.erreur ?? ''};
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _erreurs = const {});
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    final corps = {'titre': _titre.text.trim(), 'description': _description.text.trim()};
    try {
      if (widget.lecon != null) {
        await widget.api.put('/lecons/${widget.lecon!['id']}', corps);
      } else {
        final cree = enMap(await widget.api.post('/parcours/${widget.parcoursId}/lecons', corps));
        if (_fichier != null) {
          try {
            await widget.api.postMultipart('/lecons/${cree['id']}/ressources', const {},
                file: _fichier, timeout: const Duration(minutes: 3));
          } on ApiException catch (e) {
            if (mounted) {
              afficherMessage(context, 'Leçon créée, mais le fichier n’a pas été ajouté : ${e.fieldErrors['fichier'] ?? e.message}',
                  erreur: true);
            }
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurs = e.fieldErrors.isEmpty ? {'titre': e.message} : e.fieldErrors);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final erreurFichier = _erreurs['fichier'];
    return FormulaireFeuille(
      titre: widget.lecon == null ? 'Ajouter une leçon' : 'Modifier la leçon',
      cle: _cle,
      envoi: _envoi,
      libelleAction: widget.lecon == null ? 'Ajouter' : 'Enregistrer',
      onValider: _enregistrer,
      champs: [
        TextFormField(
          controller: _titre,
          maxLength: 100,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Titre de la leçon *', errorText: _erreurs['titre']),
          validator: (v) => verifierLibelle(v, 'Le titre de la leçon'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _description,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(labelText: 'Description (facultatif)', errorText: _erreurs['description']),
        ),
        if (widget.lecon == null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _envoi ? null : _choisir,
            icon: const Icon(Icons.attach_file),
            label: Text(_fichier == null ? 'Ajouter un fichier (facultatif)' : _fichier!.filename, overflow: TextOverflow.ellipsis),
          ),
          Text('PDF, documents, images et autres formats autorisés (20 Mo maximum).',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          if (erreurFichier != null && erreurFichier.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(erreurFichier, style: TextStyle(color: scheme.error)),
            ),
        ],
      ],
    );
  }
}

/// Planification d'une séance : leçon facultative, date (pas dans le passé), début et fin.
class _FormulaireSeance extends StatefulWidget {
  final ApiService api;
  final int parcoursId;
  final List<Map<String, dynamic>> lecons;
  const _FormulaireSeance({required this.api, required this.parcoursId, required this.lecons});

  @override
  State<_FormulaireSeance> createState() => _FormulaireSeanceState();
}

class _FormulaireSeanceState extends State<_FormulaireSeance> {
  final _cle = GlobalKey<FormState>();
  int? _lecon;
  DateTime? _date;
  TimeOfDay? _debut, _fin;
  Map<String, String> _erreurs = const {};
  bool _envoi = false;

  String _h(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _enregistrer() async {
    final e = <String, String>{};
    if (_date == null) e['date'] = 'La date est obligatoire.';
    if (_debut == null) e['heure_debut'] = 'L’heure de début est obligatoire.';
    if (_fin == null) e['heure_fin'] = 'L’heure de fin est obligatoire.';
    if (_debut != null && _fin != null && _fin!.hour * 60 + _fin!.minute <= _debut!.hour * 60 + _debut!.minute) {
      e['heure_fin'] = 'L’heure de fin doit être après l’heure de début.';
    }
    setState(() => _erreurs = e);
    if (e.isNotEmpty) return;
    setState(() => _envoi = true);
    try {
      await widget.api.post('/parcours/${widget.parcoursId}/seances', {
        'lecon_id': _lecon,
        'date': DateFormat('yyyy-MM-dd').format(_date!),
        'heure_debut': _h(_debut!),
        'heure_fin': _h(_fin!),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (ex) {
      if (mounted) setState(() => _erreurs = ex.fieldErrors.isEmpty ? {'date': ex.message} : ex.fieldErrors);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Widget _champ(String libelle, String? valeur, IconData icone, String? erreur, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(labelText: libelle, prefixIcon: Icon(icone), errorText: erreur),
            child: Text(valeur ?? 'Choisir', style: TextStyle(color: valeur == null ? Theme.of(context).hintColor : null)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => FormulaireFeuille(
        titre: 'Planifier une séance',
        cle: _cle,
        envoi: _envoi,
        libelleAction: 'Planifier',
        onValider: _enregistrer,
        champs: [
          DropdownButtonFormField<int?>(
            initialValue: _lecon,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Leçon (facultatif)', errorText: _erreurs['lecon_id']),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Séance libre (sans leçon)')),
              for (final (i, l) in widget.lecons.indexed)
                DropdownMenuItem<int?>(
                  value: (l['id'] as num).toInt(),
                  child: Text('${i + 1}. ${l['titre']}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _lecon = v),
          ),
          const SizedBox(height: 12),
          _champ('Date *', _date == null ? null : DateFormat('EEEE d MMMM y', 'fr').format(_date!), Icons.event, _erreurs['date'],
              () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365)),
              initialDate: _date ?? now,
            );
            if (d != null) setState(() => _date = d);
          }),
          Row(
            children: [
              Expanded(
                child: _champ('Début *', _debut == null ? null : _h(_debut!), Icons.schedule, _erreurs['heure_debut'], () async {
                  final t = await showTimePicker(context: context, initialTime: _debut ?? const TimeOfDay(hour: 9, minute: 0));
                  if (t != null) setState(() => _debut = t);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _champ('Fin *', _fin == null ? null : _h(_fin!), Icons.schedule, _erreurs['heure_fin'], () async {
                  final t = await showTimePicker(context: context, initialTime: _fin ?? const TimeOfDay(hour: 12, minute: 0));
                  if (t != null) setState(() => _fin = t);
                }),
              ),
            ],
          ),
        ],
      );
}

/// QR code de présence d'une séance, à montrer aux bénéficiaires (actualisé toutes les 5 s).
class SeanceQrScreen extends StatefulWidget {
  final int seanceId;
  const SeanceQrScreen({super.key, required this.seanceId});

  @override
  State<SeanceQrScreen> createState() => _SeanceQrScreenState();
}

class _SeanceQrScreenState extends State<SeanceQrScreen> {
  Map<String, dynamic>? _d;
  String? _erreur;
  bool _regeneration = false;
  Timer? _timer;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _charger());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final j = enMap(await _api.get('/seances/${widget.seanceId}/qr'));
      if (mounted) setState(() => _d = j);
    } on ApiException catch (e) {
      if (mounted && _d == null) setState(() => _erreur = e.message);
    }
  }

  Future<void> _regenerer() async {
    if (!await confirmer(context,
        titre: 'Générer un nouveau QR ?',
        message: 'L’ancien QR code et l’ancien code de secours ne fonctionneront plus.',
        action: 'Régénérer')) {
      return;
    }
    setState(() => _regeneration = true);
    try {
      final j = enMap(await _api.post('/seances/${widget.seanceId}/qr/regenerer'));
      if (!mounted) return;
      setState(() => _d = j);
      afficherMessage(context, 'Nouveau QR code généré.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _regeneration = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return PagePoussee(
        titre: 'QR de présence',
        corps: _erreur != null ? EtatErreur(message: _erreur!, onRetry: _charger) : const Center(child: CircularProgressIndicator()),
      );
    }
    final s = enMap(d['seance']);
    final st = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final code = '${d['code'] ?? ''}';
    final (etat, ton) = switch ('${d['etat']}') {
      'ouverte' => ('Pointage ouvert · jusqu’à ${d['fermeture']}', 'succes'),
      'terminee' => ('Pointage terminé', 'neutre'),
      _ => ('Pas encore ouvert · ouvre à ${d['ouverture']}', 'alerte'),
    };
    final pointages = enListe(d['pointages']);

    return PagePoussee(
      titre: 'QR de présence',
      corps: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('${s['parcours'] ?? ''} · ${s['lecon'] ?? 'Séance libre'}',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('${dateCourte(s['date'])} · ${s['heure_debut']} – ${s['heure_fin']}',
              textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: QrImageView(
                data: '${d['qr']}',
                size: 260,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                semanticsLabel: 'QR code de présence de la séance',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Scannez ce QR avec l’application : Présence → Scanner', textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          if (code.length >= 6) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Code de secours : ${code.split('').join(' ')}',
              child: ExcludeSemantics(
                child: Text('Code de secours : ${code.substring(0, 3)} ${code.substring(3)}',
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 2)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Center(child: Pastille(etat, ton: ton)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _regeneration ? null : _regenerer,
            icon: const Icon(Icons.refresh),
            label: const Text('Générer un nouveau QR'),
          ),
          SectionTitle('Pointages : ${d['presents'] ?? 0} / ${d['attendus'] ?? 0} présent(s)'),
          if (pointages.isEmpty)
            const EtatVide(icon: Icons.groups_outlined, titre: 'Aucun bénéficiaire attendu dans ce parcours')
          else
            for (final p in pointages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AvatarPersonne(nom: '${p['name']}', photo: p['photo_url']?.toString(), rayon: 18),
                title: Text('${p['name']}'),
                trailing: p['arrivee'] == null
                    ? Pastille('Pas encore arrivé', ton: 'neutre')
                    : Tag('${p['arrivee']}${p['depart'] != null ? ' – ${p['depart']}' : ''}', fg: st.success, bg: st.successBg),
              ),
        ],
      ),
    );
  }
}
