import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/accueil.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/ui.dart';

/// Onglets de la barre du bas (même ordre que BeneficiaireShell).
class Onglet {
  static const accueil = 0, formations = 1, devoirs = 2, discussion = 3, assistant = 4;
}

/// Accueil du bénéficiaire : statistiques, prochaine séance, raccourcis, activité récente.
class AccueilScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  final void Function({bool absences}) onOpenPresences;

  const AccueilScreen({super.key, required this.onOpenTab, required this.onOpenPresences});

  @override
  State<AccueilScreen> createState() => AccueilScreenState();
}

class AccueilScreenState extends State<AccueilScreen> {
  Accueil? _data;
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  /// Rechargé aussi au retour sur l'onglet et après un pointage.
  Future<void> recharger() async {
    setState(() {
      _chargement = _data == null;
      _erreur = null;
    });
    try {
      final json = await context.read<AuthProvider>().api.get('/mon-accueil');
      if (!mounted) return;
      setState(() => _data = Accueil.fromJson(Map<String, dynamic>.from(json as Map)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final auth = context.watch<AuthProvider>();
    final prenom = d?.prenom ?? auth.userName.trim().split(RegExp(r'\s+')).last;

    return RefreshIndicator(
      onRefresh: recharger,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          PageHeader(
            fablab: d?.fablab,
            photoUrl: d?.photoUrl,
            title: 'Bonjour, $prenom !',
            subtitle: d == null
                ? null
                : d.parcours != null
                    ? 'Parcours : ${d.parcours}'
                    : 'Aucun parcours attribué pour le moment',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _chargement
                ? const _Chargement()
                : d == null
                    ? _Erreur(message: _erreur ?? 'Impossible de charger l’accueil.', onRetry: recharger)
                    : _Contenu(
                        d: d,
                        erreurRafraichissement: _erreur,
                        onOpenTab: widget.onOpenTab,
                        onOpenPresences: widget.onOpenPresences,
                      ),
          ),
        ],
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  final Accueil d;
  final String? erreurRafraichissement;
  final ValueChanged<int> onOpenTab;
  final void Function({bool absences}) onOpenPresences;

  const _Contenu({
    required this.d,
    required this.erreurRafraichissement,
    required this.onOpenTab,
    required this.onOpenPresences,
  });

  @override
  Widget build(BuildContext context) {
    final status = StatusColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (erreurRafraichissement != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Alerte(
              icon: Icons.wifi_off_rounded,
              texte: 'Données peut-être pas à jour : $erreurRafraichissement',
              fg: status.warning,
              bg: status.warningBg,
            ),
          ),

        // ---------- À faire maintenant ----------
        if (d.absencesAJustifier > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Alerte(
              icon: Icons.event_busy_outlined,
              texte: d.absencesAJustifier == 1
                  ? '1 absence à justifier'
                  : '${d.absencesAJustifier} absences à justifier',
              action: 'Justifier',
              onTap: () => onOpenPresences(absences: true),
              fg: status.danger,
              bg: status.dangerBg,
            ),
          ),
        if (d.presences.seanceAujourdhui)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _PointageDuJour(p: d.presences, onTap: () => onOpenPresences()),
          ),

        // ---------- Statistiques ----------
        const SectionTitle('Mes statistiques'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _CarteProgression(p: d.progression, onTap: () => onOpenTab(Onglet.formations))),
              const SizedBox(width: 12),
              Expanded(child: _CartePresences(p: d.presences, onTap: () => onOpenPresences())),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CarteProchaineSeance(s: d.prochaineSeance, aParcours: d.parcours != null),
        if (d.devoirsAFaire > 0) ...[
          const SizedBox(height: 12),
          _CarteDevoirs(total: d.devoirsAFaire, devoirs: d.devoirs, onTap: () => onOpenTab(Onglet.devoirs)),
        ],

        // ---------- Raccourcis ----------
        const SectionTitle('Raccourcis'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.1,
          children: [
            _Raccourci(icon: Icons.workspace_premium_outlined, label: 'Mes cours', onTap: () => onOpenTab(Onglet.formations)),
            _Raccourci(icon: Icons.calendar_month_outlined, label: 'Présence', onTap: () => onOpenPresences()),
            _Raccourci(
              icon: Icons.chat_bubble_outline,
              label: 'Messagerie',
              badge: d.messagesNonLus,
              onTap: () => onOpenTab(Onglet.discussion),
            ),
            _Raccourci(
              icon: Icons.auto_awesome_outlined,
              label: 'Assistant IA',
              highlighted: true,
              onTap: () => onOpenTab(Onglet.assistant),
            ),
          ],
        ),

        // ---------- Activité récente ----------
        const SectionTitle('Activité récente'),
        if (d.activite.isEmpty)
          const _Vide('Votre activité (présences, quiz, devoirs) apparaîtra ici.')
        else
          for (final a in d.activite) ...[
            _LigneActivite(a: a),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

// =====================================================================
// Cartes
// =====================================================================

class _Carte extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semantique;
  final EdgeInsets padding;
  const _Carte({required this.child, this.onTap, this.semantique, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => AppCard(onTap: onTap, semantique: semantique, padding: padding, child: child);
}

class _Pastille extends StatelessWidget {
  final IconData icon;
  final Color fg, bg;
  const _Pastille(this.icon, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: fg, size: 22),
      );
}

class _CarteProgression extends StatelessWidget {
  final Progression? p;
  final VoidCallback onTap;
  const _CarteProgression({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = StatusColors.of(context);
    final pct = p?.pourcentage;
    final etat = pct == null ? 'À VENIR' : (pct >= 100 ? 'TERMINÉ' : 'EN COURS');

    return _Carte(
      onTap: onTap,
      semantique: pct == null
          ? 'Progression : aucun chapitre dans le parcours'
          : 'Progression du parcours : $pct pour cent, ${p!.chapitresTermines} chapitres sur ${p!.chapitresTotal}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pastille(Icons.workspace_premium_outlined, s.success, s.successBg),
                const Spacer(),
                Flexible(
                  child: Text(etat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: s.success, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(pct == null ? '—' : '$pct%',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 6),
            Text('Progression du parcours', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (pct ?? 0) / 100,
                minHeight: 6,
                backgroundColor: scheme.outlineVariant,
                color: s.success,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              p == null || p!.chapitresTotal == 0
                  ? 'Aucun chapitre pour l’instant'
                  : '${p!.chapitresTermines} / ${p!.chapitresTotal} chapitres terminés',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartePresences extends StatelessWidget {
  final PresencesStats p;
  final VoidCallback onTap;
  const _CartePresences({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = StatusColors.of(context);
    final taux = p.moisTaux;
    final (etat, couleur) = taux == null
        ? ('CE MOIS', scheme.onSurfaceVariant)
        : taux >= 80
            ? ('ASSIDU', s.warning)
            : taux >= 60
                ? ('RÉGULIER', s.success)
                : ('À AMÉLIORER', s.danger);

    return _Carte(
      onTap: onTap,
      semantique: taux == null
          ? 'Présences : aucune séance passée ce mois-ci'
          : 'Présences ce mois : ${p.moisPresents} sur ${p.moisJoursSeance} jours de séance, $taux pour cent',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pastille(Icons.fact_check_outlined, s.warning, s.warningBg),
                const Spacer(),
                Flexible(
                  child: Text(etat,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              p.moisJoursSeance == 0 ? '—' : '${p.moisPresents}/${p.moisJoursSeance}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1),
            ),
            const SizedBox(height: 6),
            Text('Présences ce mois', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (taux ?? 0) / 100,
                minHeight: 6,
                backgroundColor: scheme.outlineVariant,
                color: s.warning,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              taux == null ? 'Aucune séance passée ce mois' : 'Assiduité : $taux %',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteProchaineSeance extends StatelessWidget {
  final ProchaineSeance? s;
  final bool aParcours;
  const _CarteProchaineSeance({required this.s, required this.aParcours});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);

    String titre;
    String detail;
    if (s == null) {
      titre = 'Aucune séance planifiée';
      detail = aParcours
          ? 'Les prochaines séances de votre parcours apparaîtront ici.'
          : 'Un parcours doit d’abord vous être attribué par l’équipe.';
    } else {
      titre = s!.enCours ? 'Séance en cours' : 'Prochaine séance';
      final jour = s!.date == null ? '' : _jourRelatif(s!.date!);
      detail = '$jour · ${s!.debut} – ${s!.fin}${s!.lecon != null ? '\n${s!.lecon}' : ''}';
    }

    return _Carte(
      semantique: '$titre. ${detail.replaceAll('\n', ', ')}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: st.successBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(s?.enCours == true ? Icons.play_circle_outline : Icons.event_outlined, color: st.success, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      if (s?.enCours == true) ...[
                        const SizedBox(width: 8),
                        _Badge('MAINTENANT', st.warning, st.warningBg),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteDevoirs extends StatelessWidget {
  final int total;
  final List<DevoirAFaire> devoirs;
  final VoidCallback onTap;
  const _CarteDevoirs({required this.total, required this.devoirs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final maintenant = DateTime.now();

    return _Carte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pastille(Icons.assignment_outlined, st.warning, st.warningBg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  total == 1 ? '1 devoir à faire' : '$total devoirs à faire',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final dv in devoirs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(dv.type == 'qcm' ? Icons.quiz_outlined : Icons.upload_file_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(dv.titre, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  if (dv.dateLimite != null)
                    dv.dateLimite!.isBefore(maintenant)
                        ? _Badge('ÉCHU', st.danger, st.dangerBg)
                        : Text('avant le ${DateFormat('d MMM, HH:mm', 'fr').format(dv.dateLimite!)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          if (total > devoirs.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('+ ${total - devoirs.length} autre(s)',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

class _PointageDuJour extends StatelessWidget {
  final PresencesStats p;
  final VoidCallback onTap;
  const _PointageDuJour({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = StatusColors.of(context);
    final (texte, action, fg, bg) = p.arriveeAujourdhui == null
        ? ('Séance aujourd’hui : scannez le QR de la séance à votre arrivée.', 'Scanner', st.warning, st.warningBg)
        : p.departAujourdhui == null
            ? ('Arrivée enregistrée à ${p.arriveeAujourdhui}. Scannez à nouveau le QR en partant.', 'Scanner', st.success, st.successBg)
            : ('Journée pointée : ${p.arriveeAujourdhui} – ${p.departAujourdhui}.', 'Voir', st.success, st.successBg);
    return _Alerte(icon: Icons.qr_code_scanner_rounded, texte: texte, action: action, onTap: onTap, fg: fg, bg: bg);
  }
}

class _Alerte extends StatelessWidget {
  final IconData icon;
  final String texte;
  final String? action;
  final VoidCallback? onTap;
  final Color fg, bg;

  const _Alerte({required this.icon, required this.texte, required this.fg, required this.bg, this.action, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        button: onTap != null,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(texte,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  ),
                  if (action != null)
                    TextButton(
                      onPressed: onTap,
                      style: TextButton.styleFrom(foregroundColor: fg),
                      child: Text(action!),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Raccourci extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final int badge;

  const _Raccourci({required this.icon, required this.label, required this.onTap, this.highlighted = false, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge message(s) non lu(s)' : label,
      child: Material(
        color: highlighted ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: highlighted ? scheme.primary : scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Badge(
                    isLabelVisible: badge > 0,
                    label: Text(badge > 99 ? '99+' : '$badge'),
                    backgroundColor: scheme.secondary,
                    child: Icon(icon, color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: highlighted ? scheme.onPrimaryContainer : scheme.onSurface,
                        )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LigneActivite extends StatelessWidget {
  final Activite a;
  const _LigneActivite({required this.a});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final couleur = switch (a.ton) {
      'succes' => st.success,
      'alerte' => st.danger,
      'attention' => st.warning,
      _ => scheme.onSurfaceVariant,
    };

    return _Carte(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semantique: '${a.titre}. ${a.detail}. ${a.date == null ? '' : _ilYa(a.date!)}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [a.detail, if (a.date != null) _ilYa(a.date!)].where((t) => t.isNotEmpty).join(' • '),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String texte;
  final Color fg, bg;
  const _Badge(this.texte, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(texte, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
      );
}

class _Vide extends StatelessWidget {
  final String texte;
  const _Vide(this.texte);

  @override
  Widget build(BuildContext context) => _Carte(
        child: Row(
          children: [
            Icon(Icons.history, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(texte, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ],
        ),
      );
}

// =====================================================================
// États chargement / erreur
// =====================================================================

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6);
    Widget bloc(double h) => Container(height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)));
    return Semantics(
      label: 'Chargement de l’accueil',
      child: Column(
        children: [
          const SizedBox(height: 40),
          Row(children: [Expanded(child: bloc(170)), const SizedBox(width: 12), Expanded(child: bloc(170))]),
          const SizedBox(height: 12),
          bloc(84),
          const SizedBox(height: 32),
          bloc(110),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _Erreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ],
        ),
      );
}

// =====================================================================
// Dates en français
// =====================================================================

String _jourRelatif(DateTime date) {
  final now = DateTime.now();
  final j = DateTime(date.year, date.month, date.day);
  final diff = j.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Demain';
  final texte = DateFormat('EEEE d MMMM', 'fr').format(date);
  return texte[0].toUpperCase() + texte.substring(1);
}

String _ilYa(DateTime date) {
  final d = DateTime.now().difference(date);
  if (d.isNegative || d.inMinutes < 1) return 'à l’instant';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays == 1) return 'hier';
  if (d.inDays < 7) return 'il y a ${d.inDays} jours';
  return 'le ${DateFormat('d MMM', 'fr').format(date)}';
}
