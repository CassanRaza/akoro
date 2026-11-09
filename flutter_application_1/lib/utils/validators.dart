import 'package:flutter/services.dart';

/// Règles de saisie identiques à l'interface web (akoro-admin/src/utils/validators.js)
/// et au serveur (app/Support/Rules.php) : mêmes caractères autorisés, mêmes messages.
class Validators {
  Validators._();

  static final _name = RegExp(r"^\p{L}+(?:[ '’-]\p{L}+)*$", unicode: true);
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _password = RegExp(r'^(?=.*\p{L})(?=.*\p{N})\S+$', unicode: true);
  static final _phone = RegExp(r'^\+?\d[\d ]*\d$');
  static final _address = RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} ,.'’/()°-]*$", unicode: true);

  // ---------- Contrôles (null = valide) ----------

  static String? name(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Le nom et prénoms sont obligatoires.';
    if (value.length < 2) return 'Le nom est trop court.';
    if (!_name.hasMatch(value)) return 'Utilisez uniquement des lettres, espaces, tirets ou apostrophes.';
    return null;
  }

  static String? email(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return "L'adresse email est obligatoire.";
    if (!value.contains('@')) return "L'adresse email doit contenir @.";
    if (!_email.hasMatch(value)) return 'Adresse email invalide (exemple : nom@domaine.mg).';
    return null;
  }

  static String? phone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Le numéro de téléphone est obligatoire.';
    if (!_phone.hasMatch(value)) return 'Numéro invalide (chiffres et espaces, + possible au début).';
    final digits = value.replaceAll(RegExp(r'\D'), '').length;
    if (digits < 9 || digits > 15) return 'Le numéro doit contenir entre 9 et 15 chiffres.';
    return null;
  }

  static String? address(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "L'adresse est obligatoire.";
    if (value.length < 5) return "L'adresse est trop courte (5 caractères minimum).";
    if (!_address.hasMatch(value)) return "L'adresse contient des caractères non autorisés.";
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Le mot de passe est obligatoire.';
    if (value.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
    if (!_password.hasMatch(value)) return 'Il faut au moins une lettre et un chiffre, sans espace.';
    return null;
  }

  static String? loginPassword(String? v) =>
      (v ?? '').isEmpty ? 'Le mot de passe est obligatoire.' : null;

  static String? confirm(String password, String? confirm) {
    if ((confirm ?? '').isEmpty) return 'Veuillez confirmer le mot de passe.';
    if (confirm != password) return 'Les mots de passe ne correspondent pas.';
    return null;
  }

  // ---------- Filtres pendant la saisie (les caractères interdits ne s'écrivent pas) ----------

  static String _cleanSpaces(String v) =>
      v.replaceAll(RegExp(r'\s{2,}'), ' ').replaceFirst(RegExp(r'^\s+'), '');

  static final nameInput = _Filter(
      (v) => _cleanSpaces(v.replaceAll(RegExp(r"[^\p{L} '’-]", unicode: true), '')));
  static final emailInput = _Filter((v) => v.replaceAll(RegExp(r'\s'), '').toLowerCase());
  static final passwordInput = _Filter((v) => v.replaceAll(RegExp(r'\s'), ''));
  // Chiffres et espaces, un seul + permis (au début)
  static final phoneInput = _Filter((v) {
    final kept = v.replaceAll(RegExp(r'[^\d+ ]'), '');
    final plusFirst = kept.startsWith('+');
    return _cleanSpaces((plusFirst ? '+' : '') + kept.replaceAll('+', ''));
  });
  static final addressInput = _Filter((v) =>
      _cleanSpaces(v.replaceAll(RegExp(r"[^\p{L}\p{N} ,.'’/()°-]", unicode: true), '')));
}

/// Applique une fonction de nettoyage au texte saisi en gardant le curseur au bon endroit.
class _Filter extends TextInputFormatter {
  final String Function(String) clean;
  _Filter(this.clean);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = clean(newValue.text);
    if (cleaned == newValue.text) return newValue;
    // Position du curseur : on nettoie aussi la partie avant le curseur
    final offset = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final before = clean(newValue.text.substring(0, offset));
    final cursor = before.length.clamp(0, cleaned.length);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}
