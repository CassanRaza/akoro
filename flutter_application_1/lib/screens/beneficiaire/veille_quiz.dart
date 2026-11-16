import 'dart:async';

import '../../models/formation.dart';
import '../../services/api_service.dart';
import '../../widgets/compte_a_rebours_quiz.dart';

/// Surveille les quiz à venir du bénéficiaire, quel que soit l'onglet ouvert :
///  - 5 minutes avant le début → [onRappel] (« Le quiz commence dans 5 minutes ! ») ;
///  - minuterie à zéro → [onDebut] (« Le quiz commence maintenant ! »).
/// La liste est relue toutes les minutes ; l'heure est vérifiée chaque seconde.
class VeilleQuiz {
  final ApiService api;
  final void Function(QuizResume q, int minutes) onRappel;
  final void Function(QuizResume q) onDebut;

  VeilleQuiz({required this.api, required this.onRappel, required this.onDebut});

  List<QuizResume> _aVenir = const [];
  final _rappeles = <int>{};
  final _demarres = <int>{};
  Timer? _lecture, _horloge;

  void demarrer() {
    _lire();
    _lecture = Timer.periodic(const Duration(minutes: 1), (_) => _lire());
    _horloge = Timer.periodic(const Duration(seconds: 1), (_) => _verifier());
  }

  void arreter() {
    _lecture?.cancel();
    _horloge?.cancel();
  }

  Future<void> _lire() async {
    try {
      final json = await api.get('/mes-quiz');
      _aVenir = [
        for (final q in (json as List))
          QuizResume.fromJson(Map<String, dynamic>.from(q as Map)),
      ].where((q) => q.etat == 'a_venir' && q.dateDebut != null).toList();
      _verifier();
    } catch (_) {
      // Réseau coupé : on garde la dernière liste, nouvel essai dans une minute
    }
  }

  void _verifier() {
    final now = DateTime.now();
    for (final q in _aVenir) {
      final reste = q.dateDebut!.difference(now);
      if (reste <= Duration.zero) {
        if (_demarres.add(q.id)) onDebut(q);
      } else if (reste <= rappelQuiz && _rappeles.add(q.id)) {
        onRappel(q, (reste.inSeconds / 60).ceil().clamp(1, 5));
      }
    }
  }
}
