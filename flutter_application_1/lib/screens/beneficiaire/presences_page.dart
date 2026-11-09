import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/presence.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';
import '../absences_screen.dart';
import 'presence/scanner_screen.dart';

/// Page « Présence » : pointage du jour par QR code, historique mensuel, mes absences.
class PresencesPage extends StatelessWidget {
  final int ongletInitial;
  const PresencesPage({super.key, this.ongletInitial = 0});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        initialIndex: ongletInitial,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Présence'),
            actions: const [ThemeToggleButton()],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Pointage'),
                Tab(icon: Icon(Icons.event_busy_outlined), text: 'Mes absences'),
              ],
            ),
          ),
          body: const TabBarView(children: [_OngletPresence(), AbsencesScreen()]),
        ),
      );
}

class _OngletPresence extends StatefulWidget {
  const _OngletPresence();

  @override
  State<_OngletPresence> createState() => _OngletPresenceState();
}

class _OngletPresenceState extends State<_OngletPresence> {
  Aujourdhui? _jour;
  HistoriqueMois? _historique;
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  String? _erreur;
  bool _chargementMois = false;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final reponses = await Future.wait([
        _api.get('/presences/aujourdhui'),
        _api.get('/mes-presences?mois=${DateFormat('yyyy-MM').format(_mois)}'),
      ]);
      if (!mounted) return;
      setState(() {
        _jour = Aujourdhui.fromJson(Map<String, dynamic>.from(reponses[0] as Map));
        _historique = HistoriqueMois.fromJson(Map<String, dynamic>.from(reponses[1] as Map));
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _changerMois(int delta) async {
    final mois = DateTime(_mois.year, _mois.month + delta);
    setState(() {
      _mois = mois;
      _chargementMois = true;
    });
    try {
      final json = await _api.get('/mes-presences?mois=${DateFormat('yyyy-MM').format(mois)}');
      if (mounted && mois == _mois) setState(() => _historique = HistoriqueMois.fromJson(Map<String, dynamic>.from(json as Map)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _chargementMois = false);
    }
  }

  Future<void> _scanner() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await Navigator.of(context).push<ResultatPointage>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (res == null) return;
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(res.action == 'arrivee' ? Icons.login_rounded : Icons.logout_rounded, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(res.message)),
      ]),
    ));
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    if (_jour == null || _historique == null) {
      return _erreur != null
          ? EtatErreur(message: _erreur!, onRetry: _charger)
          : const Center(child: CircularProgressIndicator());
    }
    final h = _historique!;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _CarteAujourdhui(jour: _jour!, onScanner: _scanner),
          if (h.absencesAJustifier > 0) ...[
            const SizedBox(height: 12),
            _AlerteAbsences(nombre: h.absencesAJustifier),
          ],
          const SectionTitle('Historique des présences'),
          _CarteStats(h: h),
          const SizedBox(height: 12),
          _Calendrier(
            mois: _mois,
            historique: h,
            chargement: _chargementMois,
            onPrecedent: () => _changerMois(-1),
            onSuivant: _mois.year == DateTime.now().year && _mois.month == DateTime.now().month ? null : () => _changerMois(1),
          ),
          const SectionTitle('Activité récente'),
          ..._activite(h),
        ],
      ),
    );
  }

  List<Widget> _activite(HistoriqueMois h) {
    final passes = h.jours
        .where((j) => ['present', 'absent', 'justificatif_envoye', 'justifie'].contains(j.statut))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (passes.isEmpty) {
      return [const AppCard(child: Text('Aucune présence ni absence ce mois-ci.'))];
    }
    return [
      for (final j in passes.take(5)) ...[
        _LigneActivite(j: j),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// =====================================================================
// Aujourd'hui
// =====================================================================

class _CarteAujourdhui extends StatelessWidget {
  final Aujourdhui jour;
  final VoidCallback onScanner;
  const _CarteAujourdhui({required this.jour, required this.onScanner});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final p = jour.pointage;
    final date = DateFormat('EEEE d MMMM', 'fr').format(DateTime.now());

    // Ce que le bouton fera, ou pourquoi il est désactivé
    final String? raison = jour.seances.isEmpty
        ? 'Aucune séance de votre parcours aujourd’hui.'
        : p?.complet == true
            ? 'Votre présence du jour est complète.'
            : !jour.pointageOuvert
                ? (jour.seances.any((s) => s.etat == 'a_venir')
                    ? 'Le pointage ouvre à ${jour.seances.firstWhere((s) => s.etat == 'a_venir').ouverture}.'
                    : 'Le pointage des séances du jour est terminé.')
                : null;
    final libelle = p == null ? 'Scanner pour mon arrivée' : 'Scanner pour mon départ';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('AUJOURD’HUI', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(date[0].toUpperCase() + date.substring(1),
                    overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (jour.seances.isEmpty)
            Text('Pas de séance prévue.', style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final s in jour.seances)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('${s.debut} – ${s.fin}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.lecon ?? 'Séance libre',
                          overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    switch (s.etat) {
                      'ouverte' => Tag('Ouvert', fg: st.success, bg: st.successBg),
                      'a_venir' => Tag('À ${s.ouverture}', fg: st.warning, bg: st.warningBg),
                      _ => Tag('Terminé', fg: scheme.onSurfaceVariant, bg: scheme.outlineVariant.withValues(alpha: 0.5)),
                    },
                  ],
                ),
              ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(child: _Heure(label: 'Arrivée', valeur: p?.arrivee, icon: Icons.login_rounded)),
              Expanded(child: _Heure(label: 'Départ', valeur: p?.depart, icon: Icons.logout_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: raison == null ? onScanner : null,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(libelle),
          ),
          if (raison != null) ...[
            const SizedBox(height: 8),
            Text(raison, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ] else ...[
            const SizedBox(height: 8),
            Text('Scannez le QR code affiché par votre formateur.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _Heure extends StatelessWidget {
  final String label;
  final String? valeur;
  final IconData icon;
  const _Heure({required this.label, required this.valeur, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    return Semantics(
      label: '$label : ${valeur ?? 'pas encore enregistrée'}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: valeur != null ? st.successBg : scheme.outlineVariant.withValues(alpha: 0.5),
              child: Icon(icon, size: 18, color: valeur != null ? st.success : scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                Text(valeur ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlerteAbsences extends StatelessWidget {
  final int nombre;
  const _AlerteAbsences({required this.nombre});

  @override
  Widget build(BuildContext context) {
    final st = StatusColors.of(context);
    return AppCard(
      color: st.dangerBg,
      borderColor: Colors.transparent,
      onTap: () => DefaultTabController.of(context).animateTo(1),
      semantique: '$nombre absence(s) à justifier. Ouvrir mes absences.',
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: st.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nombre == 1 ? '1 absence à justifier' : '$nombre absences à justifier',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('Justifier', style: TextStyle(color: st.danger, fontWeight: FontWeight.w800)),
          Icon(Icons.chevron_right_rounded, color: st.danger),
        ],
      ),
    );
  }
}

// =====================================================================
// Historique : statistiques + calendrier
// =====================================================================

class _CarteStats extends StatelessWidget {
  final HistoriqueMois h;
  const _CarteStats({required this.h});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    return AppCard(
      semantique: h.joursSeance == 0
          ? 'Aucune séance passée ce mois-ci'
          : 'Présences ce mois : ${h.presents} sur ${h.joursSeance} jours. Taux d’assiduité ${h.taux} pour cent.',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Présences ce mois', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 4),
                Text(h.joursSeance == 0 ? '—' : '${h.presents} / ${h.joursSeance} jours',
                    style: TextStyle(color: st.success, fontWeight: FontWeight.w800, fontSize: 22)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taux d’assiduité', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              Text(h.taux == null ? '—' : '${h.taux}%',
                  style: TextStyle(color: (h.taux ?? 100) >= 60 ? st.success : st.danger, fontWeight: FontWeight.w800, fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Calendrier extends StatelessWidget {
  final DateTime mois;
  final HistoriqueMois historique;
  final bool chargement;
  final VoidCallback onPrecedent;
  final VoidCallback? onSuivant;

  const _Calendrier({
    required this.mois,
    required this.historique,
    required this.chargement,
    required this.onPrecedent,
    required this.onSuivant,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titre = DateFormat('MMMM yyyy', 'fr').format(mois);
    final premier = DateTime(mois.year, mois.month);
    final decalage = premier.weekday - 1; // lundi = 0
    final debutGrille = premier.subtract(Duration(days: decalage));
    final nbSemaines = ((decalage + DateUtils.getDaysInMonth(mois.year, mois.month)) / 7).ceil();
    final aujourdhui = DateUtils.dateOnly(DateTime.now());

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(titre[0].toUpperCase() + titre.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              if (chargement) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(tooltip: 'Mois précédent', onPressed: onPrecedent, icon: const Icon(Icons.chevron_left_rounded)),
              IconButton(tooltip: 'Mois suivant', onPressed: onSuivant, icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final j in const ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'])
                Expanded(
                  child: Center(
                    child: Text(j, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < nbSemaines; w++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _CaseJour(
                      date: debutGrille.add(Duration(days: w * 7 + d)),
                      dansLeMois: debutGrille.add(Duration(days: w * 7 + d)).month == mois.month,
                      aujourdhui: aujourdhui,
                      jour: historique.jour(debutGrille.add(Duration(days: w * 7 + d))),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          const _Legende(),
        ],
      ),
    );
  }
}

({Color fg, Color bg, bool contour, String label}) _style(BuildContext context, String? statut) {
  final scheme = Theme.of(context).colorScheme;
  final st = StatusColors.of(context);
  return switch (statut) {
    'present' => (fg: st.success, bg: st.successBg, contour: false, label: 'Présent'),
    'absent' => (fg: st.danger, bg: st.dangerBg, contour: false, label: 'Absent'),
    'justificatif_envoye' => (fg: st.warning, bg: st.warningBg, contour: false, label: 'Justificatif envoyé'),
    'justifie' => (fg: scheme.onSurfaceVariant, bg: scheme.outlineVariant.withValues(alpha: 0.6), contour: false, label: 'Absence justifiée'),
    'a_venir' => (fg: scheme.primary, bg: Colors.transparent, contour: true, label: 'Séance à venir'),
    'en_attente' => (fg: scheme.onSurfaceVariant, bg: Colors.transparent, contour: true, label: 'En cours de calcul'),
    _ => (fg: scheme.onSurface, bg: Colors.transparent, contour: false, label: ''),
  };
}

class _CaseJour extends StatelessWidget {
  final DateTime date, aujourdhui;
  final bool dansLeMois;
  final JourCalendrier? jour;
  const _CaseJour({required this.date, required this.dansLeMois, required this.aujourdhui, required this.jour});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _style(context, jour?.statut);
    final estAujourdhui = DateUtils.isSameDay(date, aujourdhui);
    final libelleDate = DateFormat('EEEE d MMMM', 'fr').format(date);

    final rond = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dansLeMois ? s.bg : Colors.transparent,
        border: estAujourdhui
            ? Border.all(color: scheme.secondary, width: 2)
            : (s.contour && dansLeMois ? Border.all(color: s.fg.withValues(alpha: 0.6), width: 1.4) : null),
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontWeight: jour != null || estAujourdhui ? FontWeight.w800 : FontWeight.w500,
          color: !dansLeMois ? scheme.onSurfaceVariant.withValues(alpha: 0.4) : (jour != null ? s.fg : scheme.onSurface),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Semantics(
          button: jour != null && dansLeMois,
          label: '$libelleDate${jour != null ? ', ${s.label}' : ''}${estAujourdhui ? ', aujourd’hui' : ''}',
          child: ExcludeSemantics(
            child: jour == null || !dansLeMois
                ? rond
                : InkWell(customBorder: const CircleBorder(), onTap: () => _details(context, s.label), child: rond),
          ),
        ),
      ),
    );
  }

  void _details(BuildContext context, String label) {
    final j = jour!;
    final texte = DateFormat('EEEE d MMMM', 'fr').format(j.date);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texte[0].toUpperCase() + texte.substring(1), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Builder(builder: (c) {
                final s = _style(c, j.statut);
                return Tag(label, fg: s.fg, bg: s.contour ? Theme.of(c).colorScheme.surface : s.bg);
              }),
              const SizedBox(height: 14),
              if (j.arrivee != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.login_rounded),
                  title: Text('Arrivée ${j.arrivee}${j.depart != null ? ' · départ ${j.depart}' : ''}'),
                ),
              for (final s in j.seances)
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text('Séance $s')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende();

  @override
  Widget build(BuildContext context) {
    Widget item(String statut) {
      final s = _style(context, statut);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.contour ? Colors.transparent : s.bg,
              border: Border.all(color: s.fg.withValues(alpha: s.contour ? 0.7 : 0.35)),
            ),
          ),
          const SizedBox(width: 5),
          Text(s.label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [item('present'), item('absent'), item('justificatif_envoye'), item('justifie'), item('a_venir')],
    );
  }
}

class _LigneActivite extends StatelessWidget {
  final JourCalendrier j;
  const _LigneActivite({required this.j});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _style(context, j.statut);
    final date = DateFormat('EEEE d MMMM', 'fr').format(j.date);

    String detail;
    if (j.arrivee != null) {
      detail = '${j.arrivee} – ${j.depart ?? '…'}';
      if (j.depart != null) {
        final a = j.arrivee!.split(':').map(int.parse).toList();
        final d = j.depart!.split(':').map(int.parse).toList();
        final minutes = (d[0] * 60 + d[1]) - (a[0] * 60 + a[1]);
        if (minutes > 0) detail += ' (${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')})';
      }
    } else {
      detail = s.label;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semantique: '$date, ${s.label}, $detail',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date[0].toUpperCase() + date.substring(1), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          Tag(switch (j.statut) { 'present' => 'Présent', 'absent' => 'Absent', 'justificatif_envoye' => 'Envoyé', _ => 'Justifié' },
              fg: s.fg, bg: s.bg),
        ],
      ),
    );
  }
}
