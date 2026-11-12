/// Formations (leçons), chapitres (documents) et quiz (devoirs QCM) — API /mes-formations, /mes-quiz.
library;

int _int(dynamic v, [int defaut = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? defaut;
int? _intOuNull(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(dynamic v) => [for (final e in (v is List ? v : const [])) _map(e)];

/// Statut d'avancement : vide | a_commencer | en_cours | termine
class Avancement {
  final int total, termines, pourcentage;
  final String statut;
  const Avancement(this.total, this.termines, this.pourcentage, this.statut);

  factory Avancement.fromJson(Map<String, dynamic> j) => Avancement(
        _int(j['chapitres_total']),
        _int(j['chapitres_termines']),
        _int(j['pourcentage']),
        '${j['statut'] ?? 'a_commencer'}',
      );

  bool get termine => statut == 'termine';
  bool get enCours => statut == 'en_cours';
}

class FormationResume {
  final int id;
  final String titre;
  final String? description;
  final int parcoursId;
  final String parcours;
  final bool accessible;
  final Avancement avancement;
  final int quizOuverts;

  FormationResume.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        titre = '${j['titre'] ?? ''}',
        description = j['description']?.toString(),
        parcoursId = _int(_map(j['parcours'])['id']),
        parcours = '${_map(j['parcours'])['nom'] ?? ''}',
        accessible = j['accessible'] == true,
        avancement = Avancement.fromJson(j),
        quizOuverts = _int(j['quiz_ouverts']);
}

class Chapitre {
  final int id, numero, taille;
  final String titre, type, nomFichier, url, downloadUrl;
  final bool termine, accessible;

  Chapitre.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        numero = _int(j['numero'], 1),
        titre = '${j['titre'] ?? ''}',
        type = '${j['type'] ?? ''}'.toLowerCase(),
        nomFichier = '${j['nom_fichier'] ?? ''}',
        taille = _int(j['taille']),
        url = '${j['url'] ?? ''}',
        downloadUrl = '${j['download_url'] ?? ''}',
        termine = j['termine'] == true,
        accessible = j['accessible'] == true;

  bool get estImage => const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(type);

  String get tailleLisible {
    if (taille <= 0) return '';
    if (taille < 1024 * 1024) return '${(taille / 1024).ceil()} Ko';
    return '${(taille / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}

class FormationDetail {
  final int id;
  final String titre;
  final String? description;
  final String parcours;
  final List<Chapitre> chapitres;
  final Avancement avancement;
  final List<QuizResume> quiz;

  FormationDetail.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        titre = '${j['titre'] ?? ''}',
        description = j['description']?.toString(),
        parcours = '${_map(j['parcours'])['nom'] ?? ''}',
        chapitres = [for (final c in _liste(j['chapitres'])) Chapitre.fromJson(c)],
        avancement = Avancement.fromJson(j),
        quiz = [for (final q in _liste(j['quiz'])) QuizResume.fromJson(q)];

  /// Chapitre à reprendre : le premier non terminé et accessible.
  Chapitre? get chapitreSuivant =>
      chapitres.where((c) => !c.termine && c.accessible).firstOrNull;
}

class ResultatQuiz {
  final int score, scoreMax;
  final int? pourcentage;
  final double? note;
  final bool reussi;

  ResultatQuiz.fromJson(Map<String, dynamic> j)
      : score = _int(j['score']),
        scoreMax = _int(j['score_max']),
        pourcentage = _intOuNull(j['pourcentage']),
        note = j['note'] is num ? (j['note'] as num).toDouble() : double.tryParse('${j['note']}'),
        reussi = j['reussi'] == true;

  String get noteLisible => note == null ? '—' : '${note!.toStringAsFixed(note! % 1 == 0 ? 0 : 1).replaceAll('.', ',')}/20';
}

/// etat : a_venir | disponible | en_cours | termine | manque
class QuizResume {
  final int id, nbQuestions;
  final String titre, etat;
  final String? description;
  /// Formation (leçon) liée : renseignée dans la liste de l'onglet Quiz.
  final String? formation;
  final int? dureeMinutes;
  final DateTime? dateDebut, dateLimite;
  final ResultatQuiz? resultat;

  QuizResume.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        titre = '${j['titre'] ?? ''}',
        description = j['description']?.toString(),
        formation = j['formation']?.toString(),
        nbQuestions = _int(j['nb_questions']),
        dureeMinutes = _intOuNull(j['duree_minutes']),
        dateDebut = _date(j['date_debut']),
        dateLimite = _date(j['date_limite']),
        etat = '${j['etat'] ?? 'manque'}',
        resultat = j['resultat'] is Map ? ResultatQuiz.fromJson(_map(j['resultat'])) : null;

  bool get jouable => etat == 'disponible' || etat == 'en_cours';
}

class QuestionQuiz {
  final int id, points;
  final String enonce;
  final List<({int id, String texte})> choix;
  int? reponseChoixId;

  QuestionQuiz.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        points = _int(j['points'], 1),
        enonce = '${j['enonce'] ?? ''}',
        choix = [for (final c in _liste(j['choix'])) (id: _int(c['id']), texte: '${c['texte'] ?? ''}')],
        reponseChoixId = _intOuNull(j['reponse_choix_id']);
}

/// Question d'entraînement (POST /entrainement) : la bonne réponse est connue du téléphone,
/// car rien n'est noté ni enregistré.
class QuestionEntrainement {
  final String enonce;
  final List<({String texte, bool correct})> choix;

  QuestionEntrainement.fromJson(Map<String, dynamic> j)
      : enonce = '${j['enonce'] ?? ''}',
        choix = [for (final c in _liste(j['choix'])) (texte: '${c['texte'] ?? ''}', correct: c['est_correct'] == true)];

  int get indexCorrect => choix.indexWhere((c) => c.correct);
}

/// Réponse de GET /mes-quiz/{id} : quiz en cours (questions) ou déjà terminé (résultat).
class SessionQuiz {
  final QuizResume quiz;
  final bool termine;
  final DateTime? echeance;
  final List<QuestionQuiz> questions;
  final ResultatQuiz? resultat;

  SessionQuiz.fromJson(Map<String, dynamic> j)
      : quiz = QuizResume.fromJson(_map(j['quiz'])),
        termine = j['termine'] == true,
        echeance = _date(j['echeance']),
        questions = [for (final q in _liste(j['questions'])) QuestionQuiz.fromJson(q)],
        resultat = j['resultat'] is Map ? ResultatQuiz.fromJson(_map(j['resultat'])) : null;
}
