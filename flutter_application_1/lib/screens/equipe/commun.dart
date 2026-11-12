import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// Outils partagés par les écrans de l'équipe (mêmes libellés et confirmations que le web).

/// Fenêtre de confirmation (équivalent de useConfirmation du web).
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  required String action,
  bool danger = false,
  IconData? icone,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icone ?? (danger ? Icons.warning_amber_rounded : Icons.help_outline),
          color: danger ? scheme.error : scheme.primary),
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Retour visible après chaque action (équivalent du toast web).
void afficherMessage(BuildContext context, String texte, {bool erreur = false}) {
  final st = StatusColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(erreur ? Icons.error_outline : Icons.check_circle_outline, color: erreur ? st.dangerBg : st.successBg),
        const SizedBox(width: 10),
        Expanded(child: Text(texte)),
      ]),
    ));
}

DateTime? lireDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// « 2026-11-12 » → « 12/11/2026 »
String dateCourte(dynamic v) {
  final d = lireDate(v);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

String dateHeure(dynamic v) {
  final d = lireDate(v);
  return d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String hhmm(dynamic v) {
  final s = v?.toString() ?? '';
  return s.length >= 5 ? s.substring(0, 5) : (s.isEmpty ? '—' : s);
}

/// Date + heure en ISO (UTC), comme toIsoDateTime() du web.
String versIso(DateTime local) => local.toUtc().toIso8601String();

Map<String, dynamic> enMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> enListe(dynamic v) => [for (final e in (v is List ? v : const [])) enMap(e)];

/// Étiquette de statut colorée.
class Pastille extends StatelessWidget {
  final String texte;
  final String ton; // succes | alerte | danger | neutre | info
  const Pastille(this.texte, {super.key, this.ton = 'neutre'});

  @override
  Widget build(BuildContext context) {
    final st = StatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (ton) {
      'succes' => (st.success, st.successBg),
      'alerte' => (st.warning, st.warningBg),
      'danger' => (st.danger, st.dangerBg),
      'info' => (scheme.primary, scheme.primaryContainer),
      _ => (scheme.onSurfaceVariant, scheme.outlineVariant.withValues(alpha: 0.5)),
    };
    return Tag(texte, fg: fg, bg: bg);
  }
}

/// Écran poussé depuis le menu (Absences, Administrateurs…) : barre de titre + retour.
class PagePoussee extends StatelessWidget {
  final String titre;
  final Widget corps;
  final List<Widget> actions;
  final Widget? boutonFlottant;
  const PagePoussee({super.key, required this.titre, required this.corps, this.actions = const [], this.boutonFlottant});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titre), actions: actions),
        floatingActionButton: boutonFlottant,
        body: SafeArea(child: corps),
      );
}

/// Pied de liste paginée : « Charger plus » (équivalent de Précédent / Suivant du web).
class ChargerPlus extends StatelessWidget {
  final int page, dernierePage, total;
  final bool chargement;
  final VoidCallback onPlus;
  final String unite;
  const ChargerPlus({
    super.key,
    required this.page,
    required this.dernierePage,
    required this.total,
    required this.chargement,
    required this.onPlus,
    required this.unite,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text('$total $unite', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          if (page < dernierePage) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: chargement ? null : onPlus,
              icon: chargement
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more),
              label: const Text('Afficher plus'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Liste déroulante de filtre (parcours, statut…) avec 48 dp de hauteur.
class FiltreDeroulant<T> extends StatelessWidget {
  final String libelle;
  final T? valeur;
  final List<(T?, String)> options;
  final ValueChanged<T?> onChanged;
  const FiltreDeroulant({super.key, required this.libelle, required this.valeur, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T?>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(labelText: libelle, isDense: true),
        items: [for (final (v, l) in options) DropdownMenuItem<T?>(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      );
}

const libellesStatutDevoir = {
  'brouillon': 'Brouillon',
  'programme': 'Programmé',
  'en_cours': 'En cours',
  'termine': 'Terminé',
  'archive': 'Archivé',
};

const libellesStatutAbsence = {
  'non_justifiee': ('Non justifiée', 'danger'),
  'a_valider': ('À valider', 'alerte'),
  'justifiee': ('Justifiée', 'succes'),
  'refusee': ('Refusée', 'danger'),
};
