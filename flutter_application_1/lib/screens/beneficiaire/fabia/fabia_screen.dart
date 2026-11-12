import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/messagerie.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/texte_markdown.dart';

/// Onglet « Assistant » : conversation avec FAB'IA, même disposition que le chat FAB'IA du web
/// (message d'accueil, suggestions, bulles, « Nouvelle discussion »).
class FabiaScreen extends StatefulWidget {
  const FabiaScreen({super.key});

  @override
  State<FabiaScreen> createState() => _FabiaScreenState();
}

class _FabiaScreenState extends State<FabiaScreen> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  List<EchangeFabia> _echanges = const [];
  List<String> _suggestions = const [];
  bool _chargement = true;
  String? _erreur;
  String? _enAttente; // question envoyée, réponse en cours

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
    _saisie.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _enBas() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_defilement.hasClients) {
          _defilement.animateTo(_defilement.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final json = Map<String, dynamic>.from(await _api.get('/fabia/historique') as Map);
      if (!mounted) return;
      setState(() {
        _echanges = [for (final e in (json['echanges'] as List? ?? const [])) EchangeFabia.fromJson(Map<String, dynamic>.from(e as Map))];
        _suggestions = [for (final s in (json['suggestions'] as List? ?? const [])) '$s'];
      });
      _enBas();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _poser([String? texte]) async {
    final q = (texte ?? _saisie.text).trim();
    if (q.length < 2 || _enAttente != null) return;
    _saisie.clear();
    setState(() => _enAttente = q);
    _enBas();
    try {
      // FAB'IA peut essayer plusieurs modèles avant de répondre
      final json = await _api.post('/fabia/questions', {'question': q}, const Duration(seconds: 90));
      if (!mounted) return;
      setState(() => _echanges = [..._echanges, EchangeFabia.fromJson(Map<String, dynamic>.from(json as Map))]);
    } on ApiException catch (e) {
      if (!mounted) return;
      _saisie.text = q; // la question n'est pas perdue
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.statusCode == 429 ? 'Trop de questions en peu de temps. Patientez une minute.' : e.message),
      ));
    } finally {
      if (mounted) setState(() => _enAttente = null);
      _enBas();
    }
  }

  Future<void> _nouvelleDiscussion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.add_comment_outlined),
        title: const Text('Nouvelle discussion ?'),
        content: const Text('Les échanges affichés seront effacés de votre écran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Effacer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/fabia/historique');
      if (mounted) setState(() => _echanges = const []);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final prenom = auth.userName.trim().split(RegExp(r'\s+')).last;

    return Column(
      children: [
        const PageHeader(title: 'Assistant FAB’IA', subtitle: 'Votre mentor d’intelligence artificielle au FabLab'),
        Expanded(
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _defilement,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: [
                    _BulleBot(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Bonjour $prenom ! Je suis '),
                        const TextSpan(text: 'FAB’IA', style: TextStyle(fontWeight: FontWeight.w800)),
                        const TextSpan(
                            text: ', l’assistant du FabLab. Posez-moi une question sur le FabLab, votre parcours, '
                                'vos séances… ou demandez-moi de vous expliquer une notion.'),
                      ])),
                    ),
                    if (_erreur != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Historique indisponible : $_erreur', style: TextStyle(color: scheme.error)),
                      ),
                    for (final e in _echanges) ...[
                      _BulleMoi(texte: e.question, heure: e.date),
                      _BulleBot(
                        pied: '${e.source == 'local' ? 'Base de connaissances (hors ligne)' : 'FAB’IA'}'
                            '${e.date == null ? '' : ' · ${DateFormat('HH:mm').format(e.date!)}'}',
                        child: TexteMarkdown(e.reponse),
                      ),
                    ],
                    if (_enAttente != null) ...[
                      _BulleMoi(texte: _enAttente!),
                      const _BulleBot(child: _Ecrit()),
                    ],
                  ],
                ),
        ),
        if (!_chargement && _echanges.isEmpty && _enAttente == null && _suggestions.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(s), onPressed: () => _poser(s)),
                  ),
              ],
            ),
          ),
        _Saisie(
          controleur: _saisie,
          occupe: _enAttente != null,
          indication: 'Écrire à FAB’IA…',
          onEnvoyer: () => _poser(),
          peutEnvoyer: _saisie.text.trim().length >= 2,
        ),
        if (_echanges.isNotEmpty)
          TextButton.icon(
            onPressed: _enAttente != null ? null : _nouvelleDiscussion,
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: const Text('Nouvelle discussion'),
          ),
      ],
    );
  }
}

/// Zone de saisie commune (FAB'IA et messagerie).
class _Saisie extends StatelessWidget {
  final TextEditingController controleur;
  final bool occupe, peutEnvoyer;
  final String indication;
  final VoidCallback onEnvoyer;
  const _Saisie({
    required this.controleur,
    required this.occupe,
    required this.indication,
    required this.onEnvoyer,
    required this.peutEnvoyer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controleur,
              enabled: !occupe,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(hintText: indication, counterText: '', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Envoyer',
            onPressed: occupe || !peutEnvoyer ? null : onEnvoyer,
            icon: occupe
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
    );
  }
}

class _BulleMoi extends StatelessWidget {
  final String texte;
  final DateTime? heure;
  const _BulleMoi({required this.texte, this.heure});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 12, left: 48),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(texte, style: TextStyle(color: scheme.onPrimary, height: 1.4)),
            if (heure != null)
              Text(DateFormat('HH:mm').format(heure!),
                  style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BulleBot extends StatelessWidget {
  final Widget child;
  final String? pied;
  const _BulleBot({required this.child, this.pied});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: StatusColors.of(context).warningBg,
            child: Icon(Icons.auto_awesome, size: 17, color: StatusColors.of(context).warning),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(style: const TextStyle(height: 1.45), child: child),
                  if (pied != null) ...[
                    const SizedBox(height: 4),
                    Text(pied!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « FAB'IA écrit… » : trois points animés.
class _Ecrit extends StatefulWidget {
  const _Ecrit();

  @override
  State<_Ecrit> createState() => _EcritState();
}

class _EcritState extends State<_Ecrit> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'FAB’IA écrit',
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withValues(alpha: 0.3 + 0.7 * (((_a.value * 3) - i) % 3 < 1 ? 1 : 0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
