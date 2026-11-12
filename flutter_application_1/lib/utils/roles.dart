/// Rôles AKORO (identiques à app/Support/Roles.php et au web).
class Roles {
  Roles._();

  static const beneficiaire = 'beneficiaire';

  static const labels = {
    'beneficiaire': 'Bénéficiaire',
    'formateur': 'Formateur',
    'gerant': 'Gérant(e)',
    'fabmanager': 'Manager',
    'admin_global': 'Super Admin',
  };

  /// Rôles qu'un membre de l'équipe peut demander à l'inscription (validés par le Super Admin).
  static const choisissables = ['formateur', 'gerant', 'fabmanager'];

  static const descriptions = {
    'formateur': 'Anime les séances et suit les apprenants',
    'gerant': 'Gère l’organisation du FabLab',
    'fabmanager': 'Responsable du FabLab',
  };

  static const _complets = ['fabmanager', 'admin_global'];

  static bool isAdmin(String? role) => role != null && role != beneficiaire && labels.containsKey(role);

  // Mêmes droits que le web (permissions.js) ; l'API les impose aussi.
  // Le formateur et le gérant gèrent leçons, séances et devoirs, mais pas ce qui suit.
  static bool peutGererParcours(String? role) => _complets.contains(role);
  static bool peutGererBeneficiaires(String? role) => _complets.contains(role);
  static bool peutTraiterAbsences(String? role) => _complets.contains(role);

  static String label(String? role) => labels[role] ?? (role ?? '');
}
