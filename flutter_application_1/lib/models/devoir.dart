/// Devoirs à rendre (PDF ou photo) — API /mes-rendus.
library;

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class MonRendu {
  final String? nomFichier;
  final DateTime? dateSoumission;
  final double? note;
  final String? commentaire;

  MonRendu.fromJson(Map<String, dynamic> j)
      : nomFichier = j['nom_fichier']?.toString(),
        dateSoumission = _date(j['date_soumission']),
        note = j['note'] is num ? (j['note'] as num).toDouble() : double.tryParse('${j['note'] ?? ''}'),
        commentaire = j['commentaire']?.toString();

  String get noteLisible =>
      note == null ? '—' : '${note!.toStringAsFixed(note! % 1 == 0 ? 0 : 1).replaceAll('.', ',')}/20';
}

/// etat : a_rendre | rendu | corrige | manque
class DevoirRendu {
  final int id;
  final String titre, etat;
  final String? formation, description, consigneUrl, fichierUrl;
  final DateTime? dateLimite;
  final bool peutDeposer, aConsigne;
  final MonRendu? rendu;

  DevoirRendu.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        titre = '${j['titre'] ?? ''}',
        etat = '${j['etat'] ?? 'a_rendre'}',
        formation = j['formation']?.toString(),
        description = j['description']?.toString(),
        consigneUrl = j['consigne_url']?.toString(),
        fichierUrl = j['fichier_url']?.toString(),
        dateLimite = _date(j['date_limite']),
        peutDeposer = j['peut_deposer'] == true,
        aConsigne = j['a_consigne'] == true,
        rendu = j['soumission'] is Map ? MonRendu.fromJson(Map<String, dynamic>.from(j['soumission'] as Map)) : null;

  bool get aFaire => etat == 'a_rendre';
}
