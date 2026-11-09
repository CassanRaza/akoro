/// Présence par QR code — API /presences/aujourdhui, /presences/scanner, /mes-presences.
library;

int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(dynamic v) => [for (final e in (v is List ? v : const [])) _map(e)];

class PointageJour {
  final String arrivee;
  final String? depart;
  final String? seance; // « 08:30 – 12:00 · Leçon »

  PointageJour.fromJson(Map<String, dynamic> j)
      : arrivee = '${j['heure_arrivee'] ?? ''}',
        depart = j['heure_depart']?.toString(),
        seance = j['seance'] is Map
            ? [
                '${_map(j['seance'])['heure_debut']} – ${_map(j['seance'])['heure_fin']}',
                if (_map(j['seance'])['lecon'] != null) '${_map(j['seance'])['lecon']}',
              ].join(' · ')
            : null;

  bool get complet => depart != null;
}

/// etat : a_venir | ouverte | terminee
class SeanceDuJour {
  final int id;
  final String debut, fin, etat, ouverture, fermeture;
  final String? lecon;

  SeanceDuJour.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        debut = '${j['heure_debut'] ?? ''}',
        fin = '${j['heure_fin'] ?? ''}',
        lecon = j['lecon']?.toString(),
        etat = '${j['etat'] ?? 'a_venir'}',
        ouverture = '${j['ouverture'] ?? ''}',
        fermeture = '${j['fermeture'] ?? ''}';
}

class Aujourdhui {
  final PointageJour? pointage;
  final List<SeanceDuJour> seances;

  Aujourdhui.fromJson(Map<String, dynamic> j)
      : pointage = j['presence'] is Map ? PointageJour.fromJson(_map(j['presence'])) : null,
        seances = [for (final s in _liste(j['seances'])) SeanceDuJour.fromJson(s)];

  bool get pointageOuvert => seances.any((s) => s.etat == 'ouverte');
}

/// statut : present | absent | justificatif_envoye | justifie | a_venir | en_attente
class JourCalendrier {
  final DateTime date;
  final String statut;
  final String? arrivee, depart;
  final List<String> seances;

  JourCalendrier.fromJson(Map<String, dynamic> j)
      : date = DateTime.parse('${j['date']}'),
        statut = '${j['statut'] ?? ''}',
        arrivee = j['arrivee']?.toString(),
        depart = j['depart']?.toString(),
        seances = [for (final s in (j['seances'] as List? ?? const [])) '$s'];
}

class HistoriqueMois {
  final DateTime mois;
  final List<JourCalendrier> jours;
  final int presents, joursSeance, absencesAJustifier;
  final int? taux;

  HistoriqueMois.fromJson(Map<String, dynamic> j)
      : mois = DateTime.parse('${j['mois']}-01'),
        jours = [for (final d in _liste(j['jours'])) JourCalendrier.fromJson(d)],
        presents = _int(_map(j['stats'])['presents']),
        joursSeance = _int(_map(j['stats'])['jours_seance']),
        taux = _map(j['stats'])['taux'] is num ? (_map(j['stats'])['taux'] as num).toInt() : null,
        absencesAJustifier = _int(_map(j['stats'])['absences_a_justifier']);

  JourCalendrier? jour(DateTime d) =>
      jours.where((j) => j.date.year == d.year && j.date.month == d.month && j.date.day == d.day).firstOrNull;
}
