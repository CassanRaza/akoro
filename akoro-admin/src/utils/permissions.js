export const ROLE_LABELS = {
  beneficiaire: 'Bénéficiaire',
  formateur: 'Formateur',
  gerant: 'Gérant(e)',
  fabmanager: 'Manager',
  admin_global: 'Super Admin',
};

export const ROLE_DESCRIPTIONS = {
  formateur: 'Gère les leçons, les séances et les devoirs. Consulte les fiches des bénéficiaires et les absences sans pouvoir les modifier. Ne peut ni ajouter, ni modifier, ni supprimer un parcours.',
  gerant: 'Gère les leçons, les séances et les devoirs. Consulte les fiches des bénéficiaires et les absences sans pouvoir les modifier. Ne peut ni ajouter, ni modifier, ni supprimer un parcours.',
  fabmanager: 'Accès complet. Seul le Super Admin peut désactiver un compte administrateur.',
};

export const ADMIN_ROLES = ['formateur', 'gerant', 'fabmanager', 'admin_global'];

// Rôles attribuables à un nouvel admin (le Super Admin est créé à la main)
export const CHOIX_ROLES = ['formateur', 'gerant', 'fabmanager'];

const COMPLETS = ['fabmanager', 'admin_global'];

export const getStoredUser = () => {
  try {
    return JSON.parse(localStorage.getItem('akoro_user') || 'null');
  } catch {
    return null;
  }
};

// Ce que chaque rôle a le droit de voir (l'API applique les mêmes règles)
export const can = {
  isAdmin: (role) => ADMIN_ROLES.includes(role),
  dashboard: (role) => COMPLETS.includes(role),
  beneficiaireDetail: (role) => ADMIN_ROLES.includes(role),
  manageFabia: (role) => COMPLETS.includes(role),
  manageParcours: (role) => COMPLETS.includes(role),
  manageBeneficiaires: (role) => COMPLETS.includes(role),
  manageAbsences: (role) => COMPLETS.includes(role),
  manageAdmins: (role) => role === 'admin_global',
};

export const roleLabel = (role) => ROLE_LABELS[role] || role || '';

// Page d'accueil selon le rôle
export const homePath = (role) => (can.dashboard(role) ? '/dashboard' : '/parcours');