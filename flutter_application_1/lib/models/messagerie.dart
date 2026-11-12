/// Messagerie (API /conversations, /messages) : mêmes données que la page Discussion du web.
library;

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(dynamic v) => [for (final e in (v is List ? v : const [])) _map(e)];
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

class ConversationResume {
  final int id, nonLus, nbMembres;
  final String type, nom;
  final String? parcours, avatarUrl, dernierContenu, dernierAuteur;
  final bool interlocuteurAdmin, dernierSupprime;
  final DateTime? dernierDate;

  ConversationResume.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        type = '${j['type'] ?? 'privee'}',
        nom = '${j['nom'] ?? 'Conversation'}',
        parcours = j['parcours']?.toString(),
        avatarUrl = j['avatar_url']?.toString(),
        interlocuteurAdmin = j['interlocuteur_admin'] == true,
        nonLus = _int(j['unread_count']),
        nbMembres = (j['membres'] is List) ? (j['membres'] as List).length : 0,
        dernierContenu = _map(j['dernier_message'])['contenu']?.toString(),
        dernierAuteur = _map(j['dernier_message'])['auteur']?.toString(),
        dernierSupprime = _map(j['dernier_message'])['supprime'] == true,
        dernierDate = _date(_map(j['dernier_message'])['created_at']);

  bool get estGroupe => type != 'privee';

  /// Sous-titre de l'en-tête : parcours ou nombre de membres.
  String? get sousTitre => type == 'groupe_parcours' && parcours != null
      ? parcours
      : estGroupe && nbMembres > 0
          ? '$nbMembres membres'
          : null;
}

class Reaction {
  final String emoji;
  final int total;
  final List<String> noms;
  final bool moi;

  Reaction.fromJson(Map<String, dynamic> j)
      : emoji = '${j['emoji'] ?? ''}',
        total = _int(j['total']),
        noms = [for (final n in (j['noms'] is List ? j['noms'] as List : const [])) '$n'],
        moi = j['moi'] == true;
}

class MessageChat {
  final int id, auteurId;
  final String? auteurNom, auteurPhoto, contenu;
  final bool auteurAdmin, supprime, modifie, peutModifier;
  final DateTime createdAt;
  final ({int id, String? auteur, String? extrait, bool supprime})? reponseA;
  final List<Reaction> reactions;

  MessageChat.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        auteurId = _int(j['auteur_id']),
        auteurNom = _map(j['auteur'])['name']?.toString(),
        auteurPhoto = _map(j['auteur'])['photo_url']?.toString(),
        auteurAdmin = _map(j['auteur'])['admin'] == true,
        contenu = j['contenu']?.toString(),
        supprime = j['supprime'] == true,
        modifie = j['modifie'] == true,
        peutModifier = j['peut_modifier'] == true,
        createdAt = _date(j['created_at']) ?? DateTime.now(),
        reponseA = j['reply_to'] is Map
            ? (
                id: _int(_map(j['reply_to'])['id']),
                auteur: _map(j['reply_to'])['auteur']?.toString(),
                extrait: _map(j['reply_to'])['extrait']?.toString(),
                supprime: _map(j['reply_to'])['supprime'] == true,
              )
            : null,
        reactions = [for (final r in _liste(j['reactions'])) Reaction.fromJson(r)];
}

class Lecture {
  final int userId;
  final String nom;
  final DateTime? lu;

  Lecture.fromJson(Map<String, dynamic> j)
      : userId = _int(j['user_id']),
        nom = '${j['name'] ?? ''}',
        lu = _date(j['last_read_at']);
}

class Contact {
  final int id;
  final String nom, detail;
  final String? photoUrl;
  final bool admin;

  Contact.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        nom = '${j['name'] ?? ''}',
        detail = '${j['detail'] ?? ''}',
        photoUrl = j['photo_url']?.toString(),
        admin = j['admin'] == true;
}

/// Échange avec FAB'IA (API /fabia/historique, /fabia/questions).
class EchangeFabia {
  final int id;
  final String question, reponse, source;
  final DateTime? date;

  EchangeFabia.fromJson(Map<String, dynamic> j)
      : id = _int(j['id']),
        question = '${j['question'] ?? ''}',
        reponse = '${j['reponse'] ?? ''}',
        source = '${j['source'] ?? 'ia'}',
        date = _date(j['created_at']);
}
