import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Erreurs de validation Laravel par champ : { 'email': 'Cet email est déjà utilisé.' }
  final Map<String, String> fieldErrors;

  ApiException(this.message, [this.statusCode, this.fieldErrors = const {}]);

  @override
  String toString() => message;
}

/// Fichier joint à une requête multipart (photo de profil…).
class ApiFile {
  final String field;
  final String filename;
  final List<int> bytes;
  ApiFile(this.field, this.filename, this.bytes);
}

class ApiService {
  String? token;
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
        () => _client.post(_uri(path),
            headers: _headers, body: jsonEncode(body ?? <String, dynamic>{})),
      );

  /// POST multipart (formulaire avec fichier).
  Future<dynamic> postMultipart(String path, Map<String, String> fields, {ApiFile? file}) =>
      _send(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers['Accept'] = 'application/json'
          ..fields.addAll(fields);
        if (token != null) req.headers['Authorization'] = 'Bearer $token';
        if (file != null) {
          req.files.add(http.MultipartFile.fromBytes(file.field, file.bytes, filename: file.filename));
        }
        return http.Response.fromStream(await _client.send(req));
      }, timeout: const Duration(seconds: 40));

  Future<dynamic> _send(Future<http.Response> Function() request,
      {Duration timeout = const Duration(seconds: 15)}) async {
    http.Response res;
    try {
      res = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas. Vérifiez votre connexion.');
    } catch (_) {
      throw ApiException('Impossible de joindre le serveur. Vérifiez votre connexion Internet.');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    throw ApiException(_extraireMessage(data, res.statusCode), res.statusCode, _extraireChamps(data));
  }

  Map<String, String> _extraireChamps(dynamic data) {
    if (data is! Map || data['errors'] is! Map) return const {};
    final out = <String, String>{};
    (data['errors'] as Map).forEach((k, v) {
      if (v is List && v.isNotEmpty) out[k.toString()] = v.first.toString();
    });
    return out;
  }

  /// Laravel renvoie { message, errors: { champ: [..] } } en cas d'erreur.
  String _extraireMessage(dynamic data, int status) {
    if (status == 429) return 'Trop de tentatives. Réessayez dans une minute.';
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    if (status == 401) return 'Session expirée, reconnectez-vous.';
    if (status == 403) return 'Accès refusé.';
    return 'Erreur serveur ($status).';
  }
}
