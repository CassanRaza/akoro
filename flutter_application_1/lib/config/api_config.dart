import 'package:flutter/foundation.dart';

/// URL de l'API Laravel.
/// Surchargeable au lancement :
///   flutter run --dart-define=API_URL=http://192.168.1.10:8000/api
class ApiConfig {
  static const String _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // L'émulateur Android voit la machine hôte via 10.0.2.2
    // (127.0.0.1 désigne l'émulateur lui-même).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Complète un lien relatif renvoyé par l'API (« /api/mobile/files/… ») avec l'adresse du serveur.
  static Uri fichier(String lienRelatif) {
    final base = Uri.parse(baseUrl);
    return base.resolve(lienRelatif);
  }
}
