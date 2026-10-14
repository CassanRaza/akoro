export const ROLE_LABELS = {
  beneficiaire: 'Bénéficiaire',
  formateur: 'Formateur',
  gerant: 'Gérant(e)',
  fabmanager: 'Manager',
  admin_global: 'Super Admin',
};

export const ROLE_DESCRIPTIONS = {
  formateur: 'Accès à toutes les pages sauf le tableau de bord et les fiches détaillées des bénéficiaires.',
  gerant: 'Accès à toutes les pages sauf le tableau de bord et les fiches détaillées des bénéficiaires.',
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
  beneficiaireDetail: (role) => COMPLETS.includes(role),
  manageAdmins: (role) => role === 'admin_global',
};

export const roleLabel = (role) => ROLE_LABELS[role] || role || '';

// Page d'accueil selon le rôle
export const homePath = (role) => (can.dashboard(role) ? '/dashboard' : '/parcours');