import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'auth_provider.dart';

/// Avis de la cloche (devoir programmé ou corrigé, justificatif traité…).
class Avis {
  final String id, type, titre, message;
  final int? devoirId;
  final bool lu;
  final DateTime? date;
  /// Équipe : page web correspondante (« /absences », « /devoirs/12 »…), ouverte dans l'application.
  final String? lien;

  const Avis(this.id, this.type, this.titre, this.message, this.devoirId, this.lu, this.date, [this.lien]);

  factory Avis.fromJson(Map<String, dynamic> j) => Avis(
        '${j['id']}',
        '${j['type'] ?? 'info'}',
        '${j['titre'] ?? 'Information'}',
        '${j['message'] ?? ''}',
        j['devoir_id'] is num ? (j['devoir_id'] as num).toInt() : null,
        j['lu'] == true,
        j['date'] == null ? null : DateTime.tryParse('${j['date']}')?.toLocal(),
      );

  Avis get commeLu => Avis(id, type, titre, message, devoirId, true, date, lien);
}

/// Compteur global de la cloche : avis non lus + messages non lus, actualisé toutes les 30 s.
class NotificationsProvider extends ChangeNotifier {
  final AuthProvider auth;
  NotificationsProvider(this.auth);

  List<Avis> avis = const [];
  int avisNonLus = 0;
  int messagesNonLus = 0;
  bool charge = false;
  String? erreur;
  Timer? _timer;

  /// Navigation fournie par l'écran principal (onglets, page Présences, liens de l'équipe).
  void Function(int onglet)? ouvrirOnglet;
  void Function()? ouvrirAbsences;
  void Function(String lien)? ouvrirLien;

  static const _kVues = 'akoro_alertes_vues';

  int get total => avisNonLus + messagesNonLus;

  void demarrer() {
    _timer?.cancel();
    charger();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => charger());
  }

  void arreter() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> charger() async {
    if (!auth.isAuthenticated) return;
    if (!auth.isBeneficiaire) return _chargerEquipe();
    try {
      final json = await auth.api.get('/mes-notifications');
      final m = Map<String, dynamic>.from(json as Map);
      avis = [for (final a in (m['notifications'] as List? ?? const [])) Avis.fromJson(Map<String, dynamic>.from(a as Map))];
      avisNonLus = (m['non_lues'] as num?)?.toInt() ?? 0;
      messagesNonLus = (m['messages_non_lus'] as num?)?.toInt() ?? 0;
      erreur = null;
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (_) {
      erreur = 'Notifications indisponibles.';
    }
    charge = true;
    notifyListeners();
  }

  /// Équipe : mêmes alertes que la cloche du web (/notifications) ; « vu » mémorisé sur l'appareil, comme le web.
  Future<void> _chargerEquipe() async {
    try {
      final m = Map<String, dynamic>.from(await auth.api.get('/notifications') as Map);
      final vues = (await SharedPreferences.getInstance()).getStringList(_kVues)?.toSet() ?? <String>{};
      avis = [
        for (final a in (m['alertes'] as List? ?? const []))
          Avis(
            '${(a as Map)['id']}',
            '${a['type'] ?? 'info'}',
            '${a['titre'] ?? 'Alerte'}',
            '${a['texte'] ?? ''}',
            null,
            vues.contains('${a['id']}'),
            a['date'] == null ? null : DateTime.tryParse('${a['date']}')?.toLocal(),
            a['lien']?.toString(),
          ),
      ]..sort((x, y) => (y.date ?? DateTime(2000)).compareTo(x.date ?? DateTime(2000)));
      avisNonLus = avis.where((a) => !a.lu).length;
      messagesNonLus = ((m['messagerie'] as Map?)?['non_lues'] as num?)?.toInt() ?? 0;
      erreur = null;
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (_) {
      erreur = 'Notifications indisponibles.';
    }
    charge = true;
    notifyListeners();
  }

  /// À l'ouverture de la liste : tout est marqué comme lu (côté serveur aussi).
  Future<void> marquerLues() async {
    if (avisNonLus == 0) return;
    avis = [for (final a in avis) a.commeLu];
    avisNonLus = 0;
    notifyListeners();
    try {
      if (auth.isBeneficiaire) {
        await auth.api.post('/mes-notifications/lues');
      } else {
        final prefs = await SharedPreferences.getInstance();
        // On ne garde que les identifiants encore affichés, pour que la liste ne grossisse pas
        await prefs.setStringList(_kVues, [for (final a in avis) a.id]);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    arreter();
    super.dispose();
  }
}
