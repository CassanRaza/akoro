import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/messagerie.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/roles.dart';
import '../../../widgets/texte_markdown.dart';
import 'discussion_screen.dart' show AvatarPersonne, BadgeAdmin;

const _reactionsParDefaut = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Deux messages du même auteur à moins de 5 min d'écart forment un groupe (comme sur le web).
const _ecartGroupe = Duration(minutes: 5);

/// Conversation : messages groupés par date, réponses, réactions, modification (15 min),
/// suppression, indicateur « Vu », résumé FAB'IA. Actualisée toutes les 4 s comme le web.
class ConversationScreen extends StatefulWidget {
  final int id;
  final String nom, type;
  final String? sousTitre;
  final bool admin;
  const ConversationScreen({super.key, required this.id, required this.nom, required this.type, this.sousTitre, this.admin = false});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  List<MessageChat>? _messages;
  List<Lecture> _lectures = const [];
  List<String> _reactions = _reactionsParDefaut;
  String? _erreur;
  int? _dernierId;

  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  final _focus = FocusNode();
  MessageChat? _repondA, _modifie;
  bool _envoi = false;
  Timer? _timer;

  ApiService get _api => context.read<AuthProvider>().api;
  int get _moi => ((context.read<AuthProvider>().user?['id']) as num?)?.toInt() ?? -1;
  bool get _estGroupe => widget.type != 'privee';

  @override
  void initState() {
    super.initState();
    _saisie.addListener(() => setState(() {}));
    _charger();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _charger(silencieux: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saisie.dispose();
    _defilement.dispose();
    _focus.dispose();
    super.dispose();
  }

  // La liste est inversée : la position 0 est le bas (messages récents)
  bool get _procheDuBas => !_defilement.hasClients || _defilement.offset < 120;

  void _versLeBas() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_defilement.hasClients) {
          _defilement.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      });

  Future<void> _charger({bool silencieux = false}) async {
    try {
      final json = Map<String, dynamic>.from(await _api.get('/conversations/${widget.id}/messages') as Map);
      if (!mounted) return;
      final liste = [for (final m in (json['messages'] as List? ?? const [])) MessageChat.fromJson(Map<String, dynamic>.from(m as Map))];
      final dernier = liste.isEmpty ? null : liste.last.id;
      final suivre = !silencieux || (dernier != _dernierId && _procheDuBas);
      setState(() {
        _messages = liste;
        _lectures = [for (final l in (json['lectures'] as List? ?? const [])) Lecture.fromJson(Map<String, dynamic>.from(l as Map))];
        final dispo = [for (final r in (json['reactions_disponibles'] as List? ?? const [])) '$r'];
        if (dispo.isNotEmpty) _reactions = dispo;
        _dernierId = dernier;
        _erreur = null;
      });
      if (suivre) _versLeBas();
    } on ApiException catch (e) {
      if (mounted && !silencieux) setState(() => _erreur = e.message);
    }
  }

  void _remplacer(dynamic json) {
    final m = MessageChat.fromJson(Map<String, dynamic>.from(json as Map));
    setState(() => _messages = [for (final x in _messages ?? const <MessageChat>[]) x.id == m.id ? m : x]);
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    try {
      if (_modifie != null) {
        _remplacer(await _api.put('/messages/${_modifie!.id}', {'contenu': texte}));
      } else {
        final json = await _api.post('/conversations/${widget.id}/messages', {
          'contenu': texte,
          if (_repondA != null) 'reply_to_id': _repondA!.id,
        });
        final m = MessageChat.fromJson(Map<String, dynamic>.from(json as Map));
        setState(() {
          _messages = [...?_messages, m];
          _dernierId = m.id;
        });
        _versLeBas();
      }
      _saisie.clear();
      setState(() {
        _repondA = null;
        _modifie = null;
      });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _reagir(MessageChat m, String emoji) async {
    try {
      _remplacer(await _api.post('/messages/${m.id}/reactions', {'emoji': emoji}));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _supprimer(MessageChat m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Supprimer ce message ?'),
        content: const Text('Il sera supprimé pour tout le monde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _remplacer(await _api.delete('/messages/${m.id}'));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _actions(MessageChat m) {
    if (m.supprime) return;
    final mien = m.auteurId == _moi;
    final role = context.read<AuthProvider>().role;
    // L'auteur, ou un responsable du FabLab pour modérer un groupe (même règle que le serveur)
    final peutSupprimer = mien || (_estGroupe && Roles.peutGererParcours(role));

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in _reactions)
                    IconButton(
                      tooltip: 'Réagir $e',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _reagir(m, e);
                      },
                      icon: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                ],
              ),
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _repondA = m;
                  _modifie = null;
                });
                _focus.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copier le texte'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: m.contenu ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texte copié.')));
              },
            ),
            if (m.peutModifier)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                subtitle: const Text('Possible pendant 15 minutes après l’envoi'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _modifie = m;
                    _repondA = null;
                    _saisie.text = m.contenu ?? '';
                  });
                  _focus.requestFocus();
                },
              ),
            if (peutSupprimer)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                title: Text('Supprimer pour tout le monde', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _supprimer(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _resumer() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleResume(api: _api, conversationId: widget.id, nom: widget.nom),
    );
  }

  /// « Vu » sous mon dernier message (comme le web).
  String? _libelleVu(List<MessageChat> msgs) {
    final monDernier = msgs.reversed.where((m) => m.auteurId == _moi && !m.supprime).firstOrNull;
    if (monDernier == null) return null;
    final vus = _lectures.where((l) => l.lu != null && !l.lu!.isBefore(monDernier.createdAt)).toList();
    if (vus.isEmpty) return null;
    if (!_estGroupe) return 'Vu';
    return vus.length <= 3 ? 'Vu par ${vus.map((l) => l.nom.split(' ').first).join(', ')}' : 'Vu par ${vus.length} personnes';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msgs = _messages;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarPersonne(
              nom: widget.nom,
              rayon: 18,
              icone: widget.type == 'groupe_general' ? Icons.groups : widget.type == 'groupe_parcours' ? Icons.school : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(widget.nom, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17))),
                    if (widget.admin) const BadgeAdmin(),
                  ]),
                  if (widget.sousTitre != null)
                    Text(widget.sousTitre!,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: msgs == null || msgs.isEmpty ? null : _resumer,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Résumer'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: msgs == null
                  ? (_erreur != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, textAlign: TextAlign.center)))
                      : const Center(child: CircularProgressIndicator()))
                  : msgs.isEmpty
                      ? Center(
                          child: Text('Aucun message. Écrivez le premier !', style: TextStyle(color: scheme.onSurfaceVariant)),
                        )
                      : _liste(msgs),
            ),
            if (_repondA != null || _modifie != null) _contexte(scheme),
            _composer(scheme),
          ],
        ),
      ),
    );
  }

  Widget _liste(List<MessageChat> msgs) {
    // Construit les éléments dans l'ordre chronologique, puis inverse pour l'affichage
    final elements = <Widget>[];
    final vu = _libelleVu(msgs);
    final monDernierId = msgs.reversed.where((m) => m.auteurId == _moi && !m.supprime).firstOrNull?.id;
    bool memeGroupe(MessageChat? a, MessageChat? b) =>
        a != null &&
        b != null &&
        a.auteurId == b.auteurId &&
        !a.supprime &&
        !b.supprime &&
        DateUtils.isSameDay(a.createdAt, b.createdAt) &&
        b.createdAt.difference(a.createdAt).abs() < _ecartGroupe;

    DateTime? jour;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (jour == null || !DateUtils.isSameDay(jour, m.createdAt)) {
        jour = m.createdAt;
        elements.add(_Separateur(date: m.createdAt));
      }
      elements.add(_Bulle(
        m: m,
        mien: m.auteurId == _moi,
        groupe: _estGroupe,
        debut: !memeGroupe(i > 0 ? msgs[i - 1] : null, m),
        fin: !memeGroupe(m, i + 1 < msgs.length ? msgs[i + 1] : null),
        vu: m.id == monDernierId ? vu : null,
        onActions: () => _actions(m),
        onReagir: (e) => _reagir(m, e),
      ));
    }

    final inverses = elements.reversed.toList();
    return ListView.builder(
      controller: _defilement,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: inverses.length,
      itemBuilder: (_, i) => inverses[i],
    );
  }

  Widget _contexte(ColorScheme scheme) {
    final enModif = _modifie != null;
    final m = _modifie ?? _repondA!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      color: scheme.primaryContainer.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(enModif ? Icons.edit_outlined : Icons.reply, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(enModif ? 'Modification du message' : 'Réponse à ${m.auteurId == _moi ? 'vous-même' : m.auteurNom ?? '?'}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary, fontSize: 13)),
                Text(m.contenu ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Annuler',
            onPressed: () => setState(() {
              if (enModif) _saisie.clear();
              _modifie = null;
              _repondA = null;
            }),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _composer(ColorScheme scheme) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _saisie,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: _modifie != null ? 'Modifier le message…' : 'Écrire un message…',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: _modifie != null ? 'Enregistrer la modification' : 'Envoyer',
              onPressed: _envoi || _saisie.text.trim().isEmpty ? null : _envoyer,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: _envoi
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Icon(_modifie != null ? Icons.check : Icons.send_rounded),
            ),
          ],
        ),
      );
}

class _Separateur extends StatelessWidget {
  final DateTime date;
  const _Separateur({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final texte = DateUtils.isSameDay(date, now)
        ? 'Aujourd’hui'
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
            ? 'Hier'
            : DateFormat('d MMMM y', 'fr').format(date);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: scheme.outlineVariant.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
          child: Text(texte, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  final MessageChat m;
  final bool mien, groupe, debut, fin;
  final String? vu;
  final VoidCallback onActions;
  final ValueChanged<String> onReagir;
  const _Bulle({
    required this.m,
    required this.mien,
    required this.groupe,
    required this.debut,
    required this.fin,
    required this.vu,
    required this.onActions,
    required this.onReagir,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fond = m.supprime ? scheme.surfaceContainerHighest : mien ? scheme.primary : scheme.surface;
    final texteCouleur = m.supprime ? scheme.onSurfaceVariant : mien ? scheme.onPrimary : scheme.onSurface;
    const r = Radius.circular(18);
    const petit = Radius.circular(5);
    final rayons = BorderRadius.only(
      topLeft: !mien && !debut ? petit : r,
      bottomLeft: !mien && !fin ? petit : r,
      topRight: mien && !debut ? petit : r,
      bottomRight: mien && !fin ? petit : r,
    );
    final heure = DateFormat('HH:mm').format(m.createdAt);

    final bulle = GestureDetector(
      onLongPress: onActions,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: rayons,
          border: mien && !m.supprime ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.reponseA != null && !m.supprime)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: BoxDecoration(
                  color: (mien ? scheme.onPrimary : scheme.primary).withValues(alpha: 0.12),
                  border: Border(left: BorderSide(color: mien ? scheme.onPrimary : scheme.primary, width: 3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.reponseA!.auteur ?? '?',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: texteCouleur)),
                    Text(m.reponseA!.supprime ? 'Message supprimé' : m.reponseA!.extrait ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: texteCouleur.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            m.supprime
                ? Text('Message supprimé', style: TextStyle(fontStyle: FontStyle.italic, color: texteCouleur))
                : TexteMarkdown(m.contenu ?? '', style: TextStyle(color: texteCouleur, height: 1.4, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${m.modifie && !m.supprime ? 'modifié · ' : ''}$heure',
                style: TextStyle(fontSize: 11, color: texteCouleur.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );

    return Semantics(
      label: '${mien ? 'Vous' : m.auteurNom ?? ''}, $heure : ${m.supprime ? 'message supprimé' : m.contenu ?? ''}',
      hint: m.supprime ? null : 'Appui long pour répondre, réagir ou modifier',
      child: Padding(
        padding: EdgeInsets.only(top: debut ? 8 : 2),
        child: Row(
          mainAxisAlignment: mien ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mien && groupe)
              SizedBox(width: 38, child: fin ? AvatarPersonne(nom: m.auteurNom ?? '?', photo: m.auteurPhoto, rayon: 15) : null),
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: mien ? 52 : 0, right: mien ? 0 : 40),
                child: Column(
                  crossAxisAlignment: mien ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!mien && groupe && debut)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(m.auteurNom ?? '?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                          if (m.auteurAdmin) const BadgeAdmin(),
                        ]),
                      ),
                    bulle,
                    if (m.reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final r in m.reactions)
                              Tooltip(
                                message: r.noms.join(', '),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => onReagir(r.emoji),
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: r.moi ? scheme.primaryContainer : scheme.surface,
                                      border: Border.all(color: r.moi ? scheme.primary : scheme.outlineVariant),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text(r.emoji, style: const TextStyle(fontSize: 15)),
                                      if (r.total > 1) ...[
                                        const SizedBox(width: 3),
                                        Text('${r.total}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ],
                                    ]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (vu != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: Text(vu!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Résumé de la conversation par FAB'IA (comme le bouton « Résumer » du web).
class _FeuilleResume extends StatefulWidget {
  final ApiService api;
  final int conversationId;
  final String nom;
  const _FeuilleResume({required this.api, required this.conversationId, required this.nom});

  @override
  State<_FeuilleResume> createState() => _FeuilleResumeState();
}

class _FeuilleResumeState extends State<_FeuilleResume> {
  String? _resume, _erreur, _source;
  int? _nb;

  @override
  void initState() {
    super.initState();
    widget.api.post('/conversations/${widget.conversationId}/resume', null, const Duration(seconds: 90)).then((json) {
      final m = Map<String, dynamic>.from(json as Map);
      if (mounted) {
        setState(() {
          _resume = '${m['resume'] ?? ''}';
          _source = '${m['source'] ?? ''}';
          _nb = (m['messages'] as num?)?.toInt();
        });
      }
    }).catchError((Object e) {
      if (mounted) setState(() => _erreur = e is ApiException ? e.message : 'Résumé indisponible.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: StatusColors.of(context).warning),
                const SizedBox(width: 8),
                Expanded(child: Text('Résumé FAB’IA · ${widget.nom}', style: Theme.of(context).textTheme.titleMedium)),
              ]),
              const SizedBox(height: 14),
              if (_resume == null && _erreur == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('FAB’IA lit la conversation…'),
                    ]),
                  ),
                )
              else if (_erreur != null)
                Text(_erreur!, style: TextStyle(color: scheme.error))
              else ...[
                TexteMarkdown(_resume!),
                const SizedBox(height: 12),
                Text(
                  '${_nb ?? 0} message(s) analysé(s)${_source == 'local' ? ' · résumé simplifié (IA indisponible)' : ''}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
