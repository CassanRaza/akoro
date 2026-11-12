import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'beneficiaire/accueil_screen.dart' show Onglet;

/// Cloche de l'en-tête : badge = avis non lus + messages non lus.
class BoutonNotifications extends StatelessWidget {
  const BoutonNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final total = n.total;
    return IconButton(
      tooltip: total == 0 ? 'Notifications' : 'Notifications, $total nouvelle(s)',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: Badge(
        isLabelVisible: total > 0,
        label: Text(total > 99 ? '99+' : '$total'),
        backgroundColor: scheme.secondary,
        child: Icon(total > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Identifiants non lus à l'ouverture : ils restent mis en avant pendant la consultation.
  Set<String> _nouveaux = const {};

  @override
  void initState() {
    super.initState();
    final n = context.read<NotificationsProvider>();
    _nouveaux = {for (final a in n.avis) if (!a.lu) a.id};
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await n.charger();
      if (!mounted) return;
      setState(() => _nouveaux = {..._nouveaux, for (final a in n.avis) if (!a.lu) a.id});
      n.marquerLues();
    });
  }

  void _ouvrir(void Function()? action) {
    Navigator.of(context).pop();
    action?.call();
  }

  void _ouvrirAvis(Avis a) {
    final n = context.read<NotificationsProvider>();
    if (a.lien != null && n.ouvrirLien != null) {
      _ouvrir(() => n.ouvrirLien!(a.lien!));
      return;
    }
    switch (a.type) {
      case 'devoir_programme' || 'devoir_corrige':
        _ouvrir(() => n.ouvrirOnglet?.call(Onglet.devoirs));
      case 'absence_traitee':
        _ouvrir(n.ouvrirAbsences);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: const [ThemeToggleButton()]),
      body: RefreshIndicator(
        onRefresh: n.charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (n.messagesNonLus > 0) ...[
              AppCard(
                onTap: () => _ouvrir(() => n.ouvrirOnglet?.call(Onglet.discussion)),
                semantique: '${n.messagesNonLus} message(s) non lu(s). Ouvrir la discussion',
                color: scheme.primaryContainer,
                borderColor: scheme.primary.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: scheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        n.messagesNonLus == 1 ? '1 message non lu' : '${n.messagesNonLus} messages non lus',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!n.charge)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            else if (n.avis.isEmpty)
              EtatVide(
                icon: Icons.notifications_none_rounded,
                titre: n.erreur != null ? 'Notifications indisponibles' : 'Aucune notification',
                texte: n.erreur ??
                    (n.ouvrirLien != null
                        ? 'Les justificatifs à valider, rendus à corriger, inscriptions, échéances et séances proches apparaîtront ici.'
                        : 'Vous serez prévenu ici des nouveaux devoirs, des corrections et des réponses à vos justificatifs.'),
              )
            else
              for (final a in n.avis) ...[
                _LigneAvis(a: a, nouveau: _nouveaux.contains(a.id), onTap: () => _ouvrirAvis(a), st: st),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _LigneAvis extends StatelessWidget {
  final Avis a;
  final bool nouveau;
  final VoidCallback onTap;
  final StatusColors st;
  const _LigneAvis({required this.a, required this.nouveau, required this.onTap, required this.st});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icone, Color fg, Color bg) = switch (a.type) {
      'devoir_programme' => (Icons.assignment_outlined, st.warning, st.warningBg),
      'devoir_corrige' => (Icons.grading_outlined, st.success, st.successBg),
      'absence_traitee' => (Icons.event_available_outlined, st.danger, st.dangerBg),
      // Alertes de l'équipe (mêmes types que la cloche du web)
      'justificatif' => (Icons.description_outlined, st.warning, st.warningBg),
      'correction' => (Icons.grading_outlined, st.warning, st.warningBg),
      'inscription' => (Icons.person_add_alt_outlined, scheme.primary, scheme.primaryContainer),
      'echeance' => (Icons.schedule, st.warning, st.warningBg),
      'echu' => (Icons.alarm_off, st.danger, st.dangerBg),
      'seance' => (Icons.event_outlined, scheme.primary, scheme.primaryContainer),
      _ => (Icons.info_outline, scheme.primary, scheme.primaryContainer),
    };
    final quand = a.date == null ? '' : DateFormat('d MMM à HH:mm', 'fr').format(a.date!);

    return AppCard(
      onTap: onTap,
      semantique: '${nouveau ? 'Nouveau. ' : ''}${a.titre}. ${a.message}. $quand',
      borderColor: nouveau ? fg.withValues(alpha: 0.6) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icone, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(a.titre, style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (nouveau) Tag('Nouveau', fg: Colors.white, bg: scheme.secondary),
                  ],
                ),
                const SizedBox(height: 3),
                Text(a.message, style: const TextStyle(height: 1.4)),
                if (quand.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(quand, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
