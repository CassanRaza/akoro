import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/formation.dart';
import '../theme/app_theme.dart';
import 'compte_a_rebours_quiz.dart';
import 'ui.dart';

/// Carte d'une évaluation QCM (détail d'une formation et onglet Quiz).
class CarteQuiz extends StatelessWidget {
  final QuizResume q;
  final VoidCallback onTap;
  /// Affiche la formation liée sous le titre (onglet Quiz).
  final bool avecFormation;
  /// Appelé quand le compte à rebours arrive à zéro (le quiz s'ouvre : recharger la liste).
  final VoidCallback? onOuverture;
  const CarteQuiz({super.key, required this.q, required this.onTap, this.avecFormation = false, this.onOuverture});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final fmt = DateFormat('d MMM à HH:mm', 'fr');

    final (String etat, Color fg, Color bg) = switch (q.etat) {
      'termine' => (q.resultat?.noteLisible ?? 'Terminé', q.resultat?.reussi == true ? st.success : st.danger,
          q.resultat?.reussi == true ? st.successBg : st.dangerBg),
      'en_cours' => ('Reprendre', st.warning, st.warningBg),
      'disponible' => ('Ouvert', st.warning, st.warningBg),
      'a_venir' => ('À venir', scheme.onSurfaceVariant, scheme.outlineVariant.withValues(alpha: 0.5)),
      _ => ('Manqué', scheme.onSurfaceVariant, scheme.outlineVariant.withValues(alpha: 0.5)),
    };

    final details = <String>[
      if (avecFormation && (q.formation ?? '').isNotEmpty) q.formation!,
      '${q.nbQuestions} question${q.nbQuestions > 1 ? 's' : ''}',
      if (q.dureeMinutes != null) '${q.dureeMinutes} min',
      if (q.etat == 'a_venir' && q.dateDebut != null) 'ouvre le ${fmt.format(q.dateDebut!)}',
      if (q.jouable && q.dateLimite != null) 'avant le ${fmt.format(q.dateLimite!)}',
    ];

    return AppCard(
      onTap: q.jouable || q.etat == 'termine' ? onTap : null,
      semantique: 'Quiz ${q.titre}, $etat, ${details.join(', ')}',
      color: q.jouable ? st.warningBg : null,
      borderColor: q.jouable ? st.warning.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Icon(Icons.quiz_outlined, color: q.jouable ? st.warning : scheme.onSurfaceVariant, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                // 5 minutes avant le début : compte à rebours (rouge clignotant la dernière minute)
                if (q.etat == 'a_venir' && q.dateDebut != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CompteAReboursQuiz(debut: q.dateDebut!, onFini: onOuverture),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tag(etat, fg: fg, bg: bg),
        ],
      ),
    );
  }
}
