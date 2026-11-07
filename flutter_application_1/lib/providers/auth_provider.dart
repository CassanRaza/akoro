import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _kToken = 'akoro_token';
  static const _kUser = 'akoro_user';

  final ApiService api;

  /// true tant que la session enregistrée n'a pas été relue.
  bool loading = true;
  bool submitting = false;
  Map<String, dynamic>? user;
  String? error;

  AuthProvider({ApiService? api}) : api = api ?? ApiService();

  bool get isAuthenticated => api.token != null && user != null;
  String get userName => (user?['name'] ?? '').toString();

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
        // Vérifie que le token est toujours valide
        try {
          final fresh = await api.get('/user');
          if (fresh is Map) user = Map<String, dynamic>.from(fresh);
        } on ApiException catch (e) {
          if (e.statusCode == 401) await _clear(prefs);
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

  Future<bool> login(String email, String password) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final data = await api
          .post('/login', {'email': email.trim(), 'password': password});
      final u = Map<String, dynamic>.from(data['user'] as Map);
      if (u['role'] != 'beneficiaire') {
        throw ApiException(
            "Cette application est réservée aux bénéficiaires. Utilisez l'interface web d'administration.");
      }
      api.token = data['token'] as String;
      user = u;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, api.token!);
      await prefs.setString(_kUser, jsonEncode(user));
      return true;
    } catch (e) {
      api.token = null;
      user = null;
      error = e is ApiException ? e.message : 'Erreur inattendue : $e';
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    notifyListeners();
  }

  Future<void> _clear(SharedPreferences prefs) async {
    api.token = null;
    user = null;
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}
