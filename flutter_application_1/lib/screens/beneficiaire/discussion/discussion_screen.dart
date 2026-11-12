import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/messagerie.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/ui.dart';
import 'conversation_screen.dart';

/// Onglet « Discussion » : même organisation que la page Discussion du web
/// (groupe général, groupe du parcours, conversation privée, recherche, liste, FAB'IA).
class DiscussionScreen extends StatefulWidget {
  /// Vrai quand l'onglet est affiché : la liste n'est actualisée qu'à ce moment-là.
  final bool actif;
  final VoidCallback onOuvrirFabia;
  const DiscussionScreen({super.key, required this.actif, required this.onOuvrirFabia});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  List<ConversationResume>? _conversations;
  String? _erreur;
  final _recherche = TextEditingController();
  Timer? _timer;
  bool _ouverture = false;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _recherche.addListener(() => setState(() {}));
    if (widget.actif) _demarrer();
  }

  @override
  void didUpdateWidget(covariant DiscussionScreen old) {
    super.didUpdateWidget(old);
    if (widget.actif && !old.actif) _demarrer();
    if (!widget.actif && old.actif) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _demarrer() {
    _charger();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _charger(silencieux: true));
  }

  Future<void> _charger({bool silencieux = false}) async {
    try {
      final json = await _api.get('/conversations');
      if (!mounted) return;
      setState(() {
        _conversations = [for (final c in (json as List)) ConversationResume.fromJson(Map<String, dynamic>.from(c as Map))];
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silencieux) setState(() => _erreur = e.message);
    }
  }

  Future<void> _ouvrir(ConversationResume c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationScreen(id: c.id, nom: c.nom, type: c.type, sousTitre: c.sousTitre, admin: c.interlocuteurAdmin),
    ));
    if (!mounted) return;
    _charger(silencieux: true);
    context.read<NotificationsProvider>().charger(); // les messages lus ne comptent plus dans la cloche
  }

  /// Ouvre (ou crée) un groupe / une conversation puis l'affiche.
  Future<void> _ouvrirDepuis(Future<dynamic> Function() requete, {String? nom, String type = 'privee', bool admin = false}) async {
    if (_ouverture) return;
    setState(() => _ouverture = true);
    try {
      final json = Map<String, dynamic>.from(await requete() as Map);
      final id = (json['id'] as num).toInt();
      await _charger(silencieux: true);
      if (!mounted) return;
      final connue = _conversations?.where((c) => c.id == id).firstOrNull;
      if (connue != null) {
        await _ouvrir(connue);
      } else {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConversationScreen(id: id, nom: nom ?? '${json['nom'] ?? 'Conversation'}', type: type, admin: admin),
        ));
        _charger(silencieux: true);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _ouverture = false);
    }
  }

  Future<void> _groupeDUnParcours() async {
    List<dynamic> parcours;
    try {
      parcours = await _api.get('/parcours') as List;
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    final choisi = await showModalBottomSheet<Map>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Groupe d’un parcours', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (parcours.isEmpty) const ListTile(title: Text('Aucun parcours')),
            for (final p in parcours)
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text('${(p as Map)['nom']}'),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (choisi == null) return;
    _ouvrirDepuis(() => _api.get('/conversations/groupe-parcours/${choisi['id']}'), type: 'groupe_parcours');
  }

  Future<void> _nouvellePrivee() async {
    final contact = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChoixContact(),
    );
    if (contact == null) return;
    _ouvrirDepuis(() => _api.post('/conversations/privee', {'user_id': contact.id}), nom: contact.nom, admin: contact.admin);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final parcoursId = auth.user?['parcours_id'];
    final q = _recherche.text.trim().toLowerCase();
    final liste = (_conversations ?? const <ConversationResume>[]).where((c) => q.isEmpty || c.nom.toLowerCase().contains(q)).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _charger,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const PageHeader(title: 'Discussion', subtitle: 'Échangez avec l’équipe et les participants du FabLab'),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                  children: [
                    _Action(
                      icone: Icons.groups_outlined,
                      libelle: 'Groupe général',
                      onTap: _ouverture ? null : () => _ouvrirDepuis(() => _api.get('/conversations/groupe-general'), type: 'groupe_general'),
                    ),
                    // Équipe : choix du parcours, comme le menu « Groupe d'un parcours » du web
                    if (!auth.isBeneficiaire)
                      _Action(
                        icone: Icons.school_outlined,
                        libelle: 'Groupe d’un parcours',
                        onTap: _ouverture ? null : _groupeDUnParcours,
                      )
                    else if (parcoursId != null)
                      _Action(
                        icone: Icons.school_outlined,
                        libelle: 'Groupe de mon parcours',
                        onTap: _ouverture
                            ? null
                            : () => _ouvrirDepuis(() => _api.get('/conversations/groupe-parcours/$parcoursId'), type: 'groupe_parcours'),
                      ),
                    _Action(
                      icone: Icons.edit_square,
                      libelle: 'Message privé',
                      onTap: _ouverture ? null : _nouvellePrivee,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: TextField(
                  controller: _recherche,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une conversation…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _recherche.text.isEmpty
                        ? null
                        : IconButton(tooltip: 'Effacer la recherche', icon: const Icon(Icons.close), onPressed: _recherche.clear),
                  ),
                ),
              ),
              if (_ouverture) const LinearProgressIndicator(minHeight: 2),
              if (_conversations == null)
                _erreur != null
                    ? EtatErreur(message: _erreur!, onRetry: _charger)
                    : const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
              else if (liste.isEmpty)
                EtatVide(
                  icon: Icons.forum_outlined,
                  titre: _conversations!.isEmpty ? 'Aucune conversation' : 'Aucune conversation trouvée',
                  texte: _conversations!.isEmpty
                      ? 'Rejoignez le groupe général ou écrivez en privé à un membre de l’équipe.'
                      : 'Essayez un autre nom.',
                )
              else
                for (final c in liste) _LigneConversation(c: c, onTap: () => _ouvrir(c), scheme: scheme),
            ],
          ),
        ),
        // Comme sur le web : FAB'IA accessible depuis la messagerie
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fabia-discussion',
            tooltip: 'Ouvrir l’assistant FAB’IA',
            onPressed: widget.onOuvrirFabia,
            backgroundColor: StatusColors.of(context).warning,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('FAB’IA'),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final VoidCallback? onTap;
  const _Action({required this.icone, required this.libelle, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(avatar: Icon(icone, size: 18), label: Text(libelle), onPressed: onTap),
      );
}

String heureCourte(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return DateFormat('HH:mm').format(d);
  if (now.difference(d).inDays < 7) return DateFormat('EEE', 'fr').format(d);
  return DateFormat('d MMM', 'fr').format(d);
}

class AvatarPersonne extends StatelessWidget {
  final String nom;
  final String? photo;
  final double rayon;
  final IconData? icone;
  const AvatarPersonne({super.key, required this.nom, this.photo, this.rayon = 24, this.icone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: rayon,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo != null && photo!.isNotEmpty ? NetworkImage(photo!) : null,
      onForegroundImageError: photo != null && photo!.isNotEmpty ? (_, _) {} : null,
      child: icone != null
          ? Icon(icone, color: scheme.onPrimaryContainer, size: rayon)
          : Text(UserAvatarButton.initiales(nom),
              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: rayon * 0.62)),
    );
  }
}

class BadgeAdmin extends StatelessWidget {
  const BadgeAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final st = StatusColors.of(context);
    return Padding(padding: const EdgeInsets.only(left: 6), child: Tag('Équipe', fg: st.warning, bg: st.warningBg));
  }
}

class _LigneConversation extends StatelessWidget {
  final ConversationResume c;
  final VoidCallback onTap;
  final ColorScheme scheme;
  const _LigneConversation({required this.c, required this.onTap, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final apercu = c.dernierContenu == null
        ? 'Aucun message'
        : c.dernierSupprime
            ? 'Message supprimé'
            : '${c.estGroupe && c.dernierAuteur != null ? '${c.dernierAuteur} : ' : c.dernierAuteur == 'Vous' ? 'Vous : ' : ''}${c.dernierContenu}';
    final nonLu = c.nonLus > 0;

    return Semantics(
      button: true,
      label: '${c.nom}${nonLu ? ', ${c.nonLus} non lu(s)' : ''}. $apercu',
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                AvatarPersonne(
                  nom: c.nom,
                  photo: c.avatarUrl,
                  icone: c.type == 'groupe_general' ? Icons.groups : c.type == 'groupe_parcours' ? Icons.school : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(c.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: nonLu ? FontWeight.w800 : FontWeight.w700)),
                          ),
                          if (c.interlocuteurAdmin) const BadgeAdmin(),
                          const Spacer(),
                          if (c.dernierDate != null)
                            Text(heureCourte(c.dernierDate!),
                                style: TextStyle(
                                    color: nonLu ? scheme.primary : scheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: nonLu ? FontWeight.w800 : FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(apercu,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: nonLu ? scheme.onSurface : scheme.onSurfaceVariant,
                                    fontStyle: c.dernierSupprime ? FontStyle.italic : null,
                                    fontWeight: nonLu ? FontWeight.w600 : FontWeight.w400)),
                          ),
                          if (nonLu)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: scheme.secondary, borderRadius: BorderRadius.circular(10)),
                              child: Text(c.nonLus > 99 ? '99+' : '${c.nonLus}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille « Nouvelle conversation privée » : recherche d'une personne de l'établissement.
class _ChoixContact extends StatefulWidget {
  const _ChoixContact();

  @override
  State<_ChoixContact> createState() => _ChoixContactState();
}

class _ChoixContactState extends State<_ChoixContact> {
  List<Contact>? _contacts;
  String? _erreur;
  final _recherche = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recherche.addListener(() => setState(() {}));
    context.read<AuthProvider>().api.get('/conversations/contacts').then((json) {
      if (mounted) {
        setState(() => _contacts = [for (final c in (json as List)) Contact.fromJson(Map<String, dynamic>.from(c as Map))]);
      }
    }).catchError((Object e) {
      if (mounted) setState(() => _erreur = e is ApiException ? e.message : 'Impossible de charger les contacts.');
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _recherche.text.trim().toLowerCase();
    final liste = (_contacts ?? const <Contact>[]).where((c) => '${c.nom} ${c.detail}'.toLowerCase().contains(q)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Text('Nouvelle conversation privée', style: Theme.of(context).textTheme.titleMedium),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _recherche,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Rechercher une personne ou un parcours…', prefixIcon: Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: _contacts == null
                    ? (_erreur != null
                        ? Center(child: Text(_erreur!))
                        : const Center(child: CircularProgressIndicator()))
                    : liste.isEmpty
                        ? const EtatVide(icon: Icons.person_search_outlined, titre: 'Aucune personne trouvée')
                        : ListView.builder(
                            itemCount: liste.length,
                            itemBuilder: (_, i) {
                              final c = liste[i];
                              return ListTile(
                                minTileHeight: 60,
                                leading: AvatarPersonne(nom: c.nom, photo: c.photoUrl, rayon: 20),
                                title: Row(children: [
                                  Flexible(child: Text(c.nom, overflow: TextOverflow.ellipsis)),
                                  if (c.admin) const BadgeAdmin(),
                                ]),
                                subtitle: Text(c.detail),
                                onTap: () => Navigator.of(context).pop(c),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
