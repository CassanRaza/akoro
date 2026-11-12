import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';
import 'commun.dart';

/// Tableau de bord (Manager et Super Admin, comme sur le web) : chiffres clés, présence du jour,
/// courbe de présence, devoirs, bénéficiaires à suivre, parcours et FAB'IA.
class TableauDeBordScreen extends StatefulWidget {
  final void Function(String lien)? ouvrirLien;
  const TableauDeBordScreen({super.key, this.ouvrirLien});

  @override
  State<TableauDeBordScreen> createState() => TableauDeBordScreenState();
}

class TableauDeBordScreenState extends State<TableauDeBordScreen> {
  Map<String, dynamic>? _d;
  String? _erreur;
  String _periode = 'semaine';
  int? _etablissementId;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  Future<void> recharger() async {
    setState(() => _erreur = null);
    final q = Uri(queryParameters: {
      'periode': _periode,
      if (_etablissementId != null) 'etablissement_id': '$_etablissementId',
    }).query;
    try {
      final j = enMap(await _api.get('/dashboard?$q'));
      if (mounted) setState(() => _d = j);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);

    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          PageHeader(title: 'Tableau de bord', subtitle: '${enMap(d?['etablissement'])['nom'] ?? 'Vue d’ensemble du FabLab'}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: d == null
                ? (_erreur != null
                    ? EtatErreur(message: _erreur!, onRetry: recharger)
                    : const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator())))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'semaine', label: Text('7 derniers jours')),
                          ButtonSegment(value: 'mois', label: Text('Ce mois')),
                        ],
                        selected: {_periode},
                        onSelectionChanged: (s) {
                          _periode = s.first;
                          recharger();
                        },
                      ),
                      if (d['etablissements'] is List) ...[
                        const SizedBox(height: 10),
                        FiltreDeroulant<int>(
                          libelle: 'FabLab',
                          valeur: _etablissementId ?? (enMap(d['etablissement'])['id'] as num?)?.toInt(),
                          options: [for (final e in enListe(d['etablissements'])) ((e['id'] as num).toInt(), '${e['nom']}')],
                          onChanged: (v) {
                            _etablissementId = v;
                            recharger();
                          },
                        ),
                      ],
                      if (_erreur != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Données peut-être pas à jour : $_erreur', style: TextStyle(color: st.warning)),
                        ),
                      ..._contenu(d, scheme, st),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contenu(Map<String, dynamic> d, ColorScheme scheme, StatusColors st) {
    final k = enMap(d['kpis']);
    final b = enMap(k['beneficiaires']);
    final p = enMap(d['presences']);
    final jour = enMap(p['resume_jour']);
    final courbe = enListe(p['courbe']);
    final dv = enMap(d['devoirs']);
    final fabia = enMap(d['fabia']);
    final lien = widget.ouvrirLien;

    return [
      const SectionTitle('Chiffres clés'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          _Tuile(Icons.groups_outlined, '${b['total'] ?? 0}', 'Bénéficiaires', '${b['actifs'] ?? 0} actifs · ${b['inactifs'] ?? 0} inactifs',
              onTap: lien == null ? null : () => lien('/beneficiaires')),
          _Tuile(Icons.fact_check_outlined, '${jour['presents'] ?? 0}/${jour['attendus'] ?? 0}', 'Présents aujourd’hui', 'pointage QR',
              onTap: lien == null ? null : () => lien('/absences')),
          _Tuile(Icons.menu_book_outlined, '${k['parcours'] ?? 0}', 'Parcours', '${k['lecons'] ?? 0} leçons',
              onTap: lien == null ? null : () => lien('/parcours')),
          _Tuile(Icons.assignment_outlined, '${k['devoirs_actifs'] ?? 0}', 'Devoirs actifs',
              dv['taux_reussite_moyen'] == null ? 'réussite : —' : 'réussite : ${dv['taux_reussite_moyen']} %',
              onTap: lien == null ? null : () => lien('/devoirs')),
        ],
      ),
      const SectionTitle('Présence sur la période'),
      AppCard(
        child: courbe.isEmpty
            ? const Text('Aucune séance sur la période.')
            : SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final c in courbe)
                      Expanded(
                        child: Tooltip(
                          message: '${dateCourte(c['date'])} : ${c['taux'] == null ? 'pas de séance' : '${c['taux']} %'}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: c['taux'] == null ? 4 : 4 + 96 * ((c['taux'] as num).toDouble() / 100),
                                  decoration: BoxDecoration(
                                    color: c['taux'] == null ? scheme.outlineVariant : st.success,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      if (enListe(p['plus_absents']).isNotEmpty) ...[
        const SectionTitle('Bénéficiaires à suivre (absences)'),
        for (final a in enListe(p['plus_absents']))
          _LigneSimple(
            titre: '${a['name']}',
            sousTitre: '${a['parcours'] ?? '—'}',
            valeur: '${a['total']} abs.',
            ton: 'danger',
            onTap: lien == null ? null : () => lien('/beneficiaires/${a['id']}'),
          ),
      ],
      if (enListe(dv['en_difficulte']).isNotEmpty) ...[
        const SectionTitle('En difficulté (moyenne < 50 %)'),
        for (final a in enListe(dv['en_difficulte']))
          _LigneSimple(
            titre: '${a['name']}',
            sousTitre: '${a['parcours'] ?? '—'} · ${a['evaluations']} évaluation(s)',
            valeur: '${a['moyenne']} %',
            ton: 'alerte',
            onTap: lien == null ? null : () => lien('/beneficiaires/${a['id']}'),
          ),
      ],
      const SectionTitle('Devoirs'),
      for (final x in [...enListe(dv['en_cours']), ...enListe(dv['a_venir'])])
        _LigneSimple(
          titre: '${x['titre']}',
          sousTitre: '${enMap(x['parcours'])['nom'] ?? '—'}',
          valeur: libellesStatutDevoir[x['statut']] ?? '${x['statut'] ?? ''}',
          ton: 'info',
          onTap: lien == null ? null : () => lien('/devoirs/${x['id']}'),
        ),
      for (final x in enListe(dv['derniers']))
        _LigneSimple(
          titre: '${x['titre']}',
          sousTitre: '${x['parcours'] ?? '—'} · ${x['participants']} participant(s)',
          valeur: x['moyenne'] == null ? '—' : 'moy. ${x['moyenne']} %',
          ton: 'succes',
          onTap: lien == null ? null : () => lien('/devoirs/${x['id']}'),
        ),
      const SectionTitle('Parcours'),
      for (final x in enListe(d['parcours']))
        _LigneSimple(
          titre: '${x['nom']}',
          sousTitre: '${x['beneficiaires'] ?? 0} bénéficiaire(s) · ${x['lecons'] ?? 0} leçon(s)',
          valeur: x['taux_presence'] == null ? '—' : '${x['taux_presence']} %',
          ton: 'info',
          onTap: lien == null ? null : () => lien('/parcours/${x['id']}'),
        ),
      if (fabia.isNotEmpty) ...[
        const SectionTitle('FAB’IA'),
        AppCard(
          child: Text(
            '${fabia['questions_periode'] ?? 0} question(s) sur la période, posées par ${fabia['utilisateurs_periode'] ?? 0} personne(s) · '
            '${fabia['questions_total'] ?? 0} au total.',
          ),
        ),
      ],
    ];
  }
}

class _Tuile extends StatelessWidget {
  final IconData icone;
  final String valeur, libelle, detail;
  final VoidCallback? onTap;
  const _Tuile(this.icone, this.valeur, this.libelle, this.detail, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      semantique: '$libelle : $valeur, $detail',
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icone, color: scheme.primary, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
          ]),
          const SizedBox(height: 4),
          Text(valeur, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _LigneSimple extends StatelessWidget {
  final String titre, sousTitre, valeur, ton;
  final VoidCallback? onTap;
  const _LigneSimple({required this.titre, required this.sousTitre, required this.valeur, required this.ton, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 52,
        onTap: onTap,
        title: Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Pastille(valeur, ton: ton),
      );
}
