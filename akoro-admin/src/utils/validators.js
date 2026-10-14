// Caractères autorisés
export const NAME_REGEX = /^\p{L}+(?:[ '’-]\p{L}+)*$/u;
export const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const PASSWORD_REGEX = /^(?=.*\p{L})(?=.*\p{N})\S+$/u;
export const LABEL_REGEX = /^[\p{L}\p{N}][\p{L}\p{N} '’&.()-]*$/u;
export const PHONE_REGEX = /^\+?\d[\d ]*\d$/;
export const ADDRESS_REGEX = /^[\p{L}\p{N}][\p{L}\p{N} ,.'’\/()°-]*$/u;

// Formats de fichiers acceptés pour les documents d'une leçon
export const FICHIERS_AUTORISES = [
  'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt',
  'ppt', 'pptx', 'odp',
  'xls', 'xlsx', 'ods', 'csv',
  'jpg', 'jpeg', 'png', 'webp', 'gif',
  'zip',
  'stl', 'dxf', 'svg', 'ino',
];
export const ACCEPT_FICHIERS = FICHIERS_AUTORISES.map((e) => `.${e}`).join(',');

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Filtres appliqués PENDANT la saisie (les caractères interdits ne s'écrivent pas)
const cleanSpaces = (v) => v.replace(/\s{2,}/g, ' ').replace(/^\s+/, '');

export const typeName = (v) => cleanSpaces(v.replace(/[^\p{L} '’-]/gu, ''));
export const typeLabel = (v) => cleanSpaces(v.replace(/[^\p{L}\p{N} '’&.()-]/gu, ''));
export const typeSearch = (v) => cleanSpaces(v.replace(/[^\p{L}\p{N} @._'’+-]/gu, ''));
export const typeEmail = (v) => v.replace(/\s/g, '').toLowerCase();
export const typePassword = (v) => v.replace(/\s/g, '');
// Téléphone : chiffres et espaces, un seul + permis (au début)
export const typePhone = (v) => cleanSpaces(v.replace(/[^\d+ ]/g, '').replace(/(?!^)\+/g, ''));
export const typeAddress = (v) => cleanSpaces(v.replace(/[^\p{L}\p{N} ,.'’\/()°-]/gu, ''));

// Contrôles à la soumission (renvoient un message, ou '' si tout est bon)
export const checkName = (v) => {
  const value = v.trim();
  if (!value) return 'Le nom et prénoms sont obligatoires.';
  if (value.length < 2) return 'Le nom est trop court.';
  if (!NAME_REGEX.test(value)) return 'Utilisez uniquement des lettres, espaces, tirets ou apostrophes.';
  return '';
};

export const checkEmail = (v) => {
  if (!v) return "L'adresse email est obligatoire.";
  if (!v.includes('@')) return "L'adresse email doit contenir @.";
  if (!EMAIL_REGEX.test(v)) return 'Adresse email invalide (exemple : nom@domaine.mg).';
  return '';
};

export const checkPhone = (v) => {
  const value = v.trim();
  if (!value) return 'Le numéro de téléphone est obligatoire.';
  if (!PHONE_REGEX.test(value)) return 'Numéro invalide (chiffres et espaces, + possible au début).';
  const digits = value.replace(/\D/g, '').length;
  if (digits < 9 || digits > 15) return 'Le numéro doit contenir entre 9 et 15 chiffres.';
  return '';
};

export const checkAddress = (v) => {
  const value = v.trim();
  if (!value) return "L'adresse est obligatoire.";
  if (value.length < 5) return "L'adresse est trop courte (5 caractères minimum).";
  if (!ADDRESS_REGEX.test(value)) return "L'adresse contient des caractères non autorisés.";
  return '';
};

export const checkRole = (v) => (v ? '' : 'Veuillez choisir un rôle.');

export const checkPassword = (v) => {
  if (!v) return 'Le mot de passe est obligatoire.';
  if (v.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
  if (!PASSWORD_REGEX.test(v)) return 'Il faut au moins une lettre et un chiffre, sans espace.';
  return '';
};

export const checkConfirm = (password, confirm) => {
  if (!confirm) return 'Veuillez confirmer le mot de passe.';
  if (confirm !== password) return 'Les mots de passe ne correspondent pas.';
  return '';
};

// Nom de parcours, titre de leçon... (subject = ce qu'on nomme, pour le message d'erreur)
export const checkLabel = (v, subject = 'Le nom du parcours') => {
  const value = v.trim();
  if (!value) return `${subject} est obligatoire.`;
  if (value.length < 2) return `${subject} est trop court.`;
  if (!LABEL_REGEX.test(value)) return `${subject} contient des caractères non autorisés.`;
  return '';
};

// Photo de profil : type et taille (à appeler seulement si un fichier est choisi)
export const checkImage = (file, maxMo = 2) => {
  if (!file) return 'Veuillez choisir une image.';
  if (!IMAGE_TYPES.includes(file.type)) return 'Formats acceptés : JPG, PNG ou WEBP.';
  if (file.size > maxMo * 1024 * 1024) return `La photo est trop volumineuse (${maxMo} Mo maximum).`;
  return '';
};

// Document de leçon : format et taille
export const checkFichier = (file, maxMo = 20) => {
  if (!file) return 'Veuillez choisir un fichier.';
  const extension = file.name.split('.').pop().toLowerCase();
  if (!FICHIERS_AUTORISES.includes(extension)) {
    return 'Format non autorisé. Formats acceptés : Word, PowerPoint, Excel, PDF, images, ZIP, STL, DXF, SVG, INO.';
  }
  if (file.size > maxMo * 1024 * 1024) return `Le fichier est trop volumineux (${maxMo} Mo maximum).`;
  return '';
};

export const formatSize = (bytes) => {
  if (bytes < 1024) return `${bytes} o`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} Ko`;
  return `${(bytes / 1024 / 1024).toFixed(1)} Mo`;
};

// Date du jour au format AAAA-MM-JJ (heure locale)
export const todayString = () => {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// Séance : date non passée, heure de fin après l'heure de début
export const checkSeance = ({ date, debut, fin }) => {
  const errors = { date: '', debut: '', fin: '' };

  if (!date) errors.date = 'La date est obligatoire.';
  else if (date < todayString()) errors.date = 'La date ne peut pas être dans le passé.';

  if (!debut) errors.debut = "L'heure de début est obligatoire.";

  if (!fin) errors.fin = "L'heure de fin est obligatoire.";
  else if (debut && fin <= debut) errors.fin = "L'heure de fin doit être après l'heure de début.";

  return errors;
};