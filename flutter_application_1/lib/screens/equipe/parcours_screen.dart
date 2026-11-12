import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/roles.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';
import 'commun.dart';
import 'parcours_detail_screen.dart';

/// Parcours & Leçons (équipe) — mêmes droits que le web :
/// ajout, modification et suppression d'un parcours réservés au Manager et au Super Admin ;
/// tous gèrent les leçons et les séances (écran de détail).
class ParcoursScreen extends StatefulWidget {
  const ParcoursScreen({super.key});

  @override
  State<ParcoursScreen> createState() => ParcoursScreenState();
}

class ParcoursScreenState extends State<ParcoursScreen> {
  List<Map<String, dynamic>>? _parcours;
  String? _erreur;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  Future<void> recharger() async {
    try {
      final j = await _api.get('/parcours');
      if (!mounted) return;
      setState(() {
        _parcours = enListe(j);
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _formulaire([Map<String, dynamic>? p]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaireParcours(api: _api, parcours: p),
    );
    if (ok == true && mounted) {
      afficherMessage(context, p == null ? 'Parcours ajouté avec succès.' : 'Parcours modifié avec succès.');
      recharger();
    }
  }

  Future<void> _supprimer(Map<String, dynamic> p) async {
    final n = (p['lecons_count'] as num?)?.toInt() ?? 0;
    if (!await confirmer(context,
        titre: 'Supprimer ce parcours ?',
        message: n > 0 ? 'Ses $n leçon(s) et leurs documents seront aussi supprimés.' : 'Le parcours « ${p['nom']} » sera supprimé.',
        action: 'Supprimer',
        danger: true)) {
      return;
    }
    try {
      await _api.delete('/parcours/${p['id']}');
      if (!mounted) return;
      afficherMessage(context, 'Parcours supprimé avec succès.');
      recharger();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _ouvrir(Map<String, dynamic> p, {bool ajout = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParcoursDetailScreen(id: (p['id'] as num).toInt(), ajoutLecon: ajout),
    ));
    recharger();
  }

  @override
  Widget build(BuildContext context) {
    final peutGerer = Roles.peutGererParcours(context.watch<AuthProvider>().role);
    final scheme = Theme.of(context).colorScheme;
    final liste = _parcours;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: recharger,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const PageHeader(title: 'Parcours & Leçons', subtitle: 'Structure des formations, leçons et séances du FabLab'),
              if (liste == null)
                _erreur != null
                    ? EtatErreur(message: _erreur!, onRetry: recharger)
                    : const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
              else if (liste.isEmpty)
                EtatVide(
                  icon: Icons.menu_book_outlined,
                  titre: 'Aucun parcours pour le moment',
                  texte: peutGerer ? 'Ajoutez le premier parcours avec le bouton +.' : 'Un Manager doit d’abord créer un parcours.',
                )
              else
                for (final p in liste)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: AppCard(
                      onTap: () => _ouvrir(p),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: scheme.primary, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                  '${(p['description'] ?? '').toString().isEmpty ? 'Sans description' : p['description']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text('${p['lecons_count'] ?? 0} leçon(s)',
                                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Actions',
                            onSelected: (v) => switch (v) {
                              'voir' => _ouvrir(p),
                              'lecon' => _ouvrir(p, ajout: true),
                              'modifier' => _formulaire(p),
                              _ => _supprimer(p),
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'voir', child: Text('Visionner')),
                              const PopupMenuItem(value: 'lecon', child: Text('Ajouter une leçon')),
                              if (peutGerer) ...[
                                const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                                PopupMenuItem(value: 'supprimer', child: Text('Supprimer', style: TextStyle(color: scheme.error))),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (peutGerer)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'ajout-parcours',
              onPressed: () => _formulaire(),
              icon: const Icon(Icons.add),
              label: const Text('Parcours'),
            ),
          ),
      ],
    );
  }
}

/// Ajout / modification d'un parcours (mêmes règles que le web : nom obligatoire, description ≤ 500).
class _FormulaireParcours extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? parcours;
  const _FormulaireParcours({required this.api, this.parcours});

  @override
  State<_FormulaireParcours> createState() => _FormulaireParcoursState();
}

class _FormulaireParcoursState extends State<_FormulaireParcours> {
  final _cle = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: '${widget.parcours?['nom'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.parcours?['description'] ?? ''}');
  Map<String, String> _erreurs = const {};
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _erreurs = const {});
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    final corps = {'nom': _nom.text.trim(), 'description': _description.text.trim()};
    try {
      if (widget.parcours == null) {
        await widget.api.post('/parcours', corps);
      } else {
        await widget.api.put('/parcours/${widget.parcours!['id']}', corps);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurs = e.fieldErrors.isEmpty ? {'nom': e.message} : e.fieldErrors);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormulaireFeuille(
        titre: widget.parcours == null ? 'Ajouter un parcours' : 'Modifier le parcours',
        cle: _cle,
        envoi: _envoi,
        libelleAction: widget.parcours == null ? 'Ajouter' : 'Enregistrer',
        onValider: _enregistrer,
        champs: [
          TextFormField(
            controller: _nom,
            maxLength: 100,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nom du parcours *', errorText: _erreurs['nom']),
            validator: (v) => verifierLibelle(v, 'Le nom du parcours'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Description', errorText: _erreurs['description']),
          ),
        ],
      );
}

/// Libellé : mêmes règles que checkLabel() du web et Rules::libelle() du serveur.
String? verifierLibelle(String? v, String quoi) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return '$quoi est obligatoire.';
  if (s.length < 2) return '$quoi est trop court (2 caractères minimum).';
  if (!RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} '’\-&.()]*$", unicode: true).hasMatch(s)) {
    return '$quoi contient des caractères non autorisés (lettres, chiffres, espaces, tirets, apostrophes, & . ( ) seulement).';
  }
  return null;
}

/// Feuille de formulaire commune : titre, champs, erreurs sous les champs, bouton désactivé pendant l'envoi.
class FormulaireFeuille extends StatelessWidget {
  final String titre, libelleAction;
  final GlobalKey<FormState> cle;
  final bool envoi;
  final VoidCallback onValider;
  final List<Widget> champs;
  const FormulaireFeuille({
    super.key,
    required this.titre,
    required this.cle,
    required this.envoi,
    required this.libelleAction,
    required this.onValider,
    required this.champs,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Form(
              key: cle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titre, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  ...champs,
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: envoi ? null : onValider,
                    child: envoi
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Text(libelleAction),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: envoi ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
                ],
              ),
            ),
          ),
        ),
      );
}
