/// Données de l'écran d'accueil bénéficiaire (GET /mon-accueil).
class Accueil {
  final String nom;
  final String? photoUrl;
  final String? fablab;
  final String? parcours;
  final Progression? progression;
  final PresencesStats presences;
  final ProchaineSeance? prochaineSeance;
  final int devoirsAFaire;
  final List<DevoirAFaire> devoirs;
  final int absencesAJustifier;
  final int messagesNonLus;
  final List<Activite> activite;

  Accueil({
    required this.nom,
    required this.photoUrl,
    required this.fablab,
    required this.parcours,
    required this.progression,
    required this.presences,
    required this.prochaineSeance,
    required this.devoirsAFaire,
    required this.devoirs,
    required this.absencesAJustifier,
    required this.messagesNonLus,
    required this.activite,
  });

  String get prenom {
    final parts = nom.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }

  factory Accueil.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    final devoirs = m(j['devoirs']) ?? const {};
    return Accueil(
      nom: (m(j['utilisateur'])?['name'] ?? '').toString(),
      photoUrl: m(j['utilisateur'])?['photo_url']?.toString(),
      fablab: m(j['etablissement'])?['nom']?.toString(),
      parcours: m(j['parcours'])?['nom']?.toString(),
      progression: m(j['progression']) == null ? null : Progression.fromJson(m(j['progression'])!),
      presences: PresencesStats.fromJson(m(j['presences']) ?? const {}),
      prochaineSeance: m(j['prochaine_seance']) == null ? null : ProchaineSeance.fromJson(m(j['prochaine_seance'])!),
      devoirsAFaire: _int(devoirs['a_faire']) ?? 0,
      devoirs: [for (final d in (devoirs['liste'] as List? ?? const [])) DevoirAFaire.fromJson(Map<String, dynamic>.from(d))],
      absencesAJustifier: _int(j['absences_a_justifier']) ?? 0,
      messagesNonLus: _int(j['messages_non_lus']) ?? 0,
      activite: [for (final a in (j['activite'] as List? ?? const [])) Activite.fromJson(Map<String, dynamic>.from(a))],
    );
  }
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class Progression {
  final int chapitresTotal, chapitresTermines, leconsTotal, leconsTerminees;
  final int? pourcentage;
  Progression(this.chapitresTotal, this.chapitresTermines, this.leconsTotal, this.leconsTerminees, this.pourcentage);

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
        _int(j['chapitres_total']) ?? 0,
        _int(j['chapitres_termines']) ?? 0,
        _int(j['lecons_total']) ?? 0,
        _int(j['lecons_terminees']) ?? 0,
        _int(j['pourcentage']),
      );
}

class PresencesStats {
  final int moisPresents, moisJoursSeance, total;
  final int? moisTaux;
  final bool seanceAujourdhui;
  final String? arriveeAujourdhui, departAujourdhui;

  PresencesStats({
    required this.moisPresents,
    required this.moisJoursSeance,
    required this.moisTaux,
    required this.total,
    required this.seanceAujourdhui,
    required this.arriveeAujourdhui,
    required this.departAujourdhui,
  });

  factory PresencesStats.fromJson(Map<String, dynamic> j) {
    final a = j['aujourdhui'] is Map ? Map<String, dynamic>.from(j['aujourdhui']) : const <String, dynamic>{};
    return PresencesStats(
      moisPresents: _int(j['mois_presents']) ?? 0,
      moisJoursSeance: _int(j['mois_jours_seance']) ?? 0,
      moisTaux: _int(j['mois_taux']),
      total: _int(j['total']) ?? 0,
      seanceAujourdhui: a['seance_prevue'] == true,
      arriveeAujourdhui: a['heure_arrivee']?.toString(),
      departAujourdhui: a['heure_depart']?.toString(),
    );
  }
}

class ProchaineSeance {
  final DateTime? date;
  final String debut, fin;
  final String? lecon;
  final bool enCours;
  ProchaineSeance(this.date, this.debut, this.fin, this.lecon, this.enCours);

  factory ProchaineSeance.fromJson(Map<String, dynamic> j) => ProchaineSeance(
        DateTime.tryParse('${j['date']}'),
        '${j['heure_debut'] ?? ''}',
        '${j['heure_fin'] ?? ''}',
        j['lecon']?.toString(),
        j['en_cours'] == true,
      );
}

class DevoirAFaire {
  final int id;
  final String titre, type;
  final bool ouvert;
  final DateTime? dateLimite;
  DevoirAFaire(this.id, this.titre, this.type, this.ouvert, this.dateLimite);

  factory DevoirAFaire.fromJson(Map<String, dynamic> j) => DevoirAFaire(
        _int(j['id']) ?? 0,
        '${j['titre'] ?? ''}',
        '${j['type'] ?? ''}',
        j['ouvert'] == true,
        _date(j['date_limite']),
      );
}

class Activite {
  final String type, titre, detail, ton;
  final DateTime? date;
  Activite(this.type, this.titre, this.detail, this.ton, this.date);

  factory Activite.fromJson(Map<String, dynamic> j) => Activite(
        '${j['type'] ?? ''}',
        '${j['titre'] ?? ''}',
        '${j['detail'] ?? ''}',
        '${j['ton'] ?? 'neutre'}',
        _date(j['date']),
      );
}
