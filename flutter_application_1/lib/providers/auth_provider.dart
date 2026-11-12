import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/roles.dart';

/// FabLab proposé à l'inscription d'un bénéficiaire, avec ses parcours.
class EtablissementOption {
  final int id;
  final String nom;
  final String? adresse;
  final List<({int id, String nom})> parcours;

  EtablissementOption(this.id, this.nom, this.adresse, this.parcours);

  factory EtablissementOption.fromJson(Map<String, dynamic> j) => EtablissementOption(
        (j['id'] as num).toInt(),
        j['nom'].toString(),
        j['adresse']?.toString(),
        [
          for (final p in (j['parcours'] as List? ?? const []))
            (id: (p['id'] as num).toInt(), nom: p['nom'].toString()),
        ],
      );
}

/// Données saisies dans le formulaire d'inscription.
class Inscription {
  final String nom, email, telephone, adresse, password;
  final String? role; // équipe uniquement
  final int? etablissementId, parcoursId; // bénéficiaire uniquement
  final ApiFile? photo;

  Inscription({
    required this.nom,
    required this.email,
    required this.telephone,
    required this.adresse,
    required this.password,
    this.role,
    this.etablissementId,
    this.parcoursId,
    this.photo,
  });

  Map<String, String> get champs => {
        'nom': nom.trim(),
        'email': email,
        'telephone': telephone.trim(),
        'adresse': adresse.trim(),
        'password': password,
        'password_confirmation': password,
        'role': ?role,
        if (etablissementId != null) 'etablissement_id': '$etablissementId',
        if (parcoursId != null) 'parcours_id': '$parcoursId',
      };
}

class AuthProvider extends ChangeNotifier {
  static const _kToken = 'akoro_token';
  static const _kUser = 'akoro_user';

  final ApiService api;

  /// true tant que la session enregistrée n'a pas été relue.
  bool loading = true;
  bool submitting = false;
  Map<String, dynamic>? user;

  /// Message général (réseau, compte en attente…) et erreurs par champ venant du serveur.
  String? error;
  Map<String, String> fieldErrors = const {};

  AuthProvider({ApiService? api}) : api = api ?? ApiService();

  bool get isAuthenticated => api.token != null && user != null;
  String get userName => (user?['name'] ?? '').toString();
  String? get role => user?['role']?.toString();
  bool get isBeneficiaire => role == Roles.beneficiaire;

  void clearErrors() {
    if (error == null && fieldErrors.isEmpty) return;
    error = null;
    fieldErrors = const {};
    notifyListeners();
  }

  void clearFieldError(String field) {
    if (!fieldErrors.containsKey(field)) return;
    fieldErrors = Map.of(fieldErrors)..remove(field);
    notifyListeners();
  }

  /// Recharge la session enregistrée. Appelée depuis main() et non dans le
  /// constructeur, pour que les tests puissent s'en passer.
  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      final rawUser = prefs.getString(_kUser);
      if (token != null && rawUser != null) {
        api.token = token;
        user = Map<String, dynamic>.from(jsonDecode(rawUser) as Map);
        // Vérifie que le token est toujours valide (compte désactivé = token révoqué)
        try {
          final fresh = await api.get('/user');
          if (fresh is Map) {
            user = Map<String, dynamic>.from(fresh);
            await prefs.setString(_kUser, jsonEncode(user));
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) await _clear(prefs);
        }
      }
    } catch (_) {
      // Session illisible : on repart de zéro
      api.token = null;
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  /// Connexion : bénéficiaires ET membres de l'équipe (mêmes règles que le web).
  Future<bool> login(String email, String password) => _run(() async {
        final data = await api.post('/login', {'email': email.trim(), 'password': password});
        await _ouvrirSession(data);
        return true;
      });

  /// Inscription (bénéficiaire ou équipe) : le compte reste EN ATTENTE jusqu'à sa validation
  /// par le Super Admin sur le web. Pas de connexion automatique.
  /// Renvoie le message du serveur, ou null en cas d'échec (erreurs dans [error] / [fieldErrors]).
  Future<String?> inscrire(Inscription f, {required bool equipe}) async {
    String? message;
    final ok = await _run(() async {
      final data = await api.postMultipart(equipe ? '/admin/register' : '/register', f.champs, file: f.photo);
      message = (data is Map ? data['message']?.toString() : null) ??
          'Inscription envoyée. Le Super Admin doit valider votre compte avant votre première connexion.';
      return true;
    });
    return ok ? message : null;
  }

  /// FabLabs et parcours proposés à l'inscription d'un bénéficiaire.
  Future<List<EtablissementOption>> optionsInscription() async {
    final data = await api.get('/inscription/options');
    return [
      for (final e in (data as List)) EtablissementOption.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  /// Remplace l'utilisateur en mémoire et dans la session enregistrée (profil ou photo modifiés).
  Future<void> majUtilisateur(dynamic data) async {
    if (data is! Map) return;
    user = Map<String, dynamic>.from(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    notifyListeners();
  }

  // ---------- Interne ----------

  Future<bool> _run(Future<bool> Function() action) async {
    submitting = true;
    error = null;
    fieldErrors = const {};
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (e) {
      api.token = null;
      user = null;
      fieldErrors = e.fieldErrors;
      // Les erreurs de champ s'affichent sous les champs ; le message général sinon
      error = e.fieldErrors.isEmpty ? e.message : null;
      return false;
    } catch (e) {
      api.token = null;
      user = null;
      error = 'Erreur inattendue. Réessayez.';
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> _ouvrirSession(dynamic data) async {
    api.token = data['token'] as String;
    user = Map<String, dynamic>.from(data['user'] as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, api.token!);
    await prefs.setString(_kUser, jsonEncode(user));
  }

  Future<void> _clear(SharedPreferences prefs) async {
    api.token = null;
    user = null;
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}
