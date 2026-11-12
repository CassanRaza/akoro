import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/roles.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';
import '../beneficiaire/discussion/discussion_screen.dart' show AvatarPersonne;
import 'commun.dart';

/// Bénéficiaires (équipe) — mêmes droits que le web :
/// tous voient la liste et la fiche ; Manager + Super Admin activent/désactivent ;
/// seul le Super Admin valide une nouvelle inscription.
class BeneficiairesScreen extends StatefulWidget {
  final bool avecEnTete;
  const BeneficiairesScreen({super.key, this.avecEnTete = true});

  @override
  State<BeneficiairesScreen> createState() => BeneficiairesScreenState();
}

class BeneficiairesScreenState extends State<BeneficiairesScreen> {
  final _recherche = TextEditingController();
  Timer? _attente;
  List<Map<String, dynamic>> _parcours = const [];
  int? _parcoursId;
  String? _statut;

  List<Map<String, dynamic>> _liste = [];
  int _page = 1, _dernierePage = 1, _total = 0;
  bool _chargement = true, _plus = false;
  String? _erreur;

  ApiService get _api => context.read<AuthProvider>().api;
  String? get _role => context.read<AuthProvider>().role;

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
      if (_recherche.text.trim().isNotEmpty) 'search': _recherche.text.trim(),
      if (_parcoursId != null) 'parcours_id': '$_parcoursId',
      'statut': ?_statut,
      'page': '$page',
    }).query;
    try {
      final j = enMap(await _api.get('/beneficiaires?$q'));
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

  Future<void> _basculer(Map<String, dynamic> b) async {
    final enAttente = b['en_attente'] == true;
    final actif = b['actif'] == true;
    final action = enAttente ? 'Valider' : actif ? 'Désactiver' : 'Activer';
    final parcours = enMap(b['parcours'])['nom'] ?? 'sans parcours';
    if (!await confirmer(
      context,
      titre: enAttente ? 'Valider cette inscription ?' : 'Confirmer : ${action.toLowerCase()} le compte ?',
      message: enAttente
          ? '${b['name']} ($parcours) pourra se connecter à l’application mobile.'
          : 'Le compte de ${b['name']} sera ${actif ? 'désactivé' : 'activé'}.',
      action: action,
      danger: actif && !enAttente,
    )) {
      return;
    }
    try {
      await _api.put('/beneficiaires/${b['id']}', {'actif': !actif});
      if (!mounted) return;
      afficherMessage(context, enAttente
          ? 'Inscription validée : le compte est actif.'
          : actif
              ? 'Compte désactivé avec succès.'
              : 'Compte activé avec succès.');
      recharger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _ouvrirFiche(Map<String, dynamic> b) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BeneficiaireFicheScreen(id: (b['id'] as num).toInt())));
    recharger();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final peutGerer = Roles.peutGererBeneficiaires(_role);
    final peutValider = _role == 'admin_global';

    final contenu = RefreshIndicator(
      onRefresh: recharger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (widget.avecEnTete)
            PageHeader(
              title: 'Bénéficiaires',
              subtitle: peutGerer ? 'Gérer les profils et inscriptions des participants' : 'Consulter les participants du FabLab',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                TextField(
                  controller: _recherche,
                  maxLength: 100,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, email…',
                    prefixIcon: const Icon(Icons.search),
                    counterText: '',
                    suffixIcon: _recherche.text.isEmpty
                        ? null
                        : IconButton(tooltip: 'Effacer', icon: const Icon(Icons.close), onPressed: _recherche.clear),
                  ),
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
                          recharger();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FiltreDeroulant<String>(
                        libelle: 'Statut',
                        valeur: _statut,
                        options: const [(null, 'Tous'), ('en_attente', 'En attente')],
                        onChanged: (v) {
                          _statut = v;
                          recharger();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_chargement)
            const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
          else if (_erreur != null && _liste.isEmpty)
            EtatErreur(message: _erreur!, onRetry: recharger)
          else if (_liste.isEmpty)
            const EtatVide(icon: Icons.person_search_outlined, titre: 'Aucun bénéficiaire trouvé')
          else ...[
            for (final b in _liste)
              _LigneBeneficiaire(
                b: b,
                onTap: () => _ouvrirFiche(b),
                action: b['en_attente'] == true
                    ? (peutValider ? () => _basculer(b) : null)
                    : (peutGerer ? () => _basculer(b) : null),
                scheme: scheme,
              ),
            ChargerPlus(
              page: _page,
              dernierePage: _dernierePage,
              total: _total,
              chargement: _plus,
              unite: 'bénéficiaire(s)',
              onPlus: () => _charger(page: _page + 1),
            ),
          ],
        ],
      ),
    );

    return widget.avecEnTete ? contenu : PagePoussee(titre: 'Bénéficiaires', corps: contenu);
  }
}

class _LigneBeneficiaire extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback onTap;
  final VoidCallback? action;
  final ColorScheme scheme;
  const _LigneBeneficiaire({required this.b, required this.onTap, required this.action, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final enAttente = b['en_attente'] == true;
    final actif = b['actif'] == true;
    final (statut, ton) = enAttente ? ('En attente', 'alerte') : actif ? ('Actif', 'succes') : ('Inactif', 'danger');
    final parcours = enMap(b['parcours'])['nom']?.toString() ?? '—';

    return ListTile(
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
      leading: AvatarPersonne(nom: '${b['name']}', photo: b['photo_url']?.toString(), rayon: 22),
      title: Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('$parcours · inscrit le ${dateCourte(b['created_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pastille(statut, ton: ton),
          if (action != null)
            IconButton(
              tooltip: enAttente ? 'Valider l’inscription' : actif ? 'Désactiver' : 'Activer',
              onPressed: action,
              icon: Icon(enAttente ? Icons.how_to_reg_outlined : Icons.power_settings_new,
                  color: enAttente ? scheme.primary : actif ? scheme.error : scheme.primary),
            ),
        ],
      ),
    );
  }
}

/// Fiche détaillée d'un bénéficiaire (lecture seule pour le formateur et le gérant).
class BeneficiaireFicheScreen extends StatefulWidget {
  final int id;
  const BeneficiaireFicheScreen({super.key, required this.id});

  @override
  State<BeneficiaireFicheScreen> createState() => _BeneficiaireFicheScreenState();
}

class _BeneficiaireFicheScreenState extends State<BeneficiaireFicheScreen> {
  Map<String, dynamic>? _b;
  String? _erreur;
  bool _occupe = false;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final j = enMap(await _api.get('/beneficiaires/${widget.id}'));
      if (mounted) setState(() => _b = j);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _basculer() async {
    final b = _b!;
    final actif = b['actif'] == true;
    if (!await confirmer(context,
        titre: 'Confirmer : ${actif ? 'désactiver' : 'activer'} le compte ?',
        message: actif ? '${b['name']} sera déconnecté de l’application.' : 'Le compte de ${b['name']} sera activé.',
        action: actif ? 'Désactiver' : 'Activer',
        danger: actif)) {
      return;
    }
    setState(() => _occupe = true);
    try {
      await _api.put('/beneficiaires/${widget.id}', {'actif': !actif});
      await _charger();
      if (mounted) afficherMessage(context, actif ? 'Compte désactivé avec succès.' : 'Compte activé avec succès.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _photo() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (img == null) return;
    final octets = await img.readAsBytes();
    if (octets.length > 2 * 1024 * 1024) {
      if (mounted) afficherMessage(context, 'La photo est trop volumineuse (2 Mo maximum).', erreur: true);
      return;
    }
    setState(() => _occupe = true);
    try {
      await _api.postMultipart('/beneficiaires/${widget.id}/photo', const {},
          file: ApiFile('photo', img.name.isEmpty ? 'photo.jpg' : img.name, octets));
      await _charger();
      if (mounted) afficherMessage(context, 'Photo mise à jour.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.fieldErrors['photo'] ?? e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _retirerPhoto() async {
    if (!await confirmer(context,
        titre: 'Retirer cette photo ?', message: 'La photo de profil de ce bénéficiaire sera supprimée.', action: 'Retirer', danger: true)) {
      return;
    }
    try {
      await _api.delete('/beneficiaires/${widget.id}/photo');
      await _charger();
      if (mounted) afficherMessage(context, 'Photo supprimée avec succès.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final peutGerer = Roles.peutGererBeneficiaires(context.watch<AuthProvider>().role);
    if (b == null) {
      return PagePoussee(
        titre: 'Fiche bénéficiaire',
        corps: _erreur != null ? EtatErreur(message: _erreur!, onRetry: _charger) : const Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final absences = enListe(b['absences']);
    final presences = enListe(b['presences']);
    final actif = b['actif'] == true;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Fiche bénéficiaire')),
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    children: [
                      AvatarPersonne(nom: '${b['name']}', photo: b['photo_url']?.toString(), rayon: 46),
                      const SizedBox(height: 10),
                      Text('${b['name']}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Pastille(actif ? 'Actif' : (b['en_attente'] == true ? 'En attente' : 'Inactif'),
                          ton: actif ? 'succes' : 'danger'),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          children: [
                            _Info('Email', '${b['email'] ?? '—'}'),
                            _Info('Téléphone', '${b['telephone'] ?? '—'}'),
                            _Info('Parcours assigné', '${enMap(b['parcours'])['nom'] ?? '—'}'),
                            _Info('Date d’inscription', dateCourte(b['created_at'])),
                          ],
                        ),
                      ),
                      if (peutGerer) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                              onPressed: _occupe ? null : _photo,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(b['photo_url'] == null ? 'Ajouter une photo' : 'Changer la photo'),
                            ),
                            if (b['photo_url'] != null)
                              TextButton(onPressed: _occupe ? null : _retirerPhoto, child: const Text('Retirer la photo')),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                              onPressed: _occupe ? null : _basculer,
                              icon: const Icon(Icons.power_settings_new),
                              label: Text(actif ? 'Désactiver le compte' : 'Activer le compte'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: TabBar(tabs: [
                  Tab(text: 'Absences (${absences.length})'),
                  Tab(text: 'Présences (${presences.length})'),
                ]),
              ),
            ],
            body: TabBarView(
              children: [
                absences.isEmpty
                    ? const EtatVide(icon: Icons.event_available_outlined, titre: 'Aucune absence enregistrée')
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final a in absences)
                            Card(
                              child: ListTile(
                                title: Text(dateCourte(a['date'])),
                                subtitle: Text(
                                    '${enMap(a['lecon'])['titre'] ?? 'Séance libre'}\n${a['motif'] ?? 'Pas de motif fourni'}'),
                                isThreeLine: true,
                                trailing: Pastille(libellesStatutAbsence[a['statut']]?.$1 ?? '${a['statut']}',
                                    ton: libellesStatutAbsence[a['statut']]?.$2 ?? 'neutre'),
                              ),
                            ),
                        ],
                      ),
                presences.isEmpty
                    ? const EtatVide(
                        icon: Icons.qr_code_scanner,
                        titre: 'Aucun pointage',
                        texte: 'Les présences arrivent depuis l’application mobile.')
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final p in presences)
                            Card(
                              child: ListTile(
                                leading: Icon(Icons.login, color: scheme.primary),
                                title: Text(dateCourte(p['date'])),
                                subtitle: Text('Arrivée ${hhmm(p['heure_arrivee'])} · départ ${hhmm(p['heure_depart'])}'),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String libelle, valeur;
  const _Info(this.libelle, this.valeur);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(libelle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
