import axios from 'axios';

const api = axios.create({
  baseURL: 'http://127.0.0.1:8000/api',
});

// Ajoute automatiquement le token à chaque requête, s'il existe
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('akoro_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Session expirée ou compte désactivé : retour à la page de connexion
api.interceptors.response.use(
  (response) => {
    // Une modification (ajout, mise à jour, suppression…) rend les copies en cache périmées
    if (response.config.method && response.config.method !== 'get') clearApiCache();
    return response;
  },
  (error) => {
    const onPublicPage = ['/login', '/register'].includes(window.location.pathname);

    if (error.response?.status === 401 && !onPublicPage) {
      clearApiCache();
      localStorage.removeItem('akoro_token');
      localStorage.removeItem('akoro_user');
      localStorage.removeItem('akoro_user_at');
      window.location.href = '/login';
    }

    return Promise.reject(error);
  }
);

export default api;

// ======================================================================
// Cache des lectures : affichage instantané à l'ouverture d'une page
// ----------------------------------------------------------------------
// La dernière réponse de chaque GET est gardée (mémoire + sessionStorage).
// À l'ouverture d'une page, on l'affiche tout de suite, puis on la remplace
// par la réponse fraîche du serveur dès qu'elle arrive.
// ======================================================================

const STORAGE_KEY = 'akoro_api_cache';
// Les liens des photos expirent au bout d'1 h : on n'affiche jamais une copie plus vieille que 30 min
const MAX_AGE_MS = 30 * 60 * 1000;
// Copie toute récente (ex. préchargée au survol du lien) : inutile de redemander au serveur
const FRESH_MS = 5 * 1000;
const MAX_ENTRIES = 60;

const currentToken = () => localStorage.getItem('akoro_token') || '';

let entries = readStorage();
// Change à chaque vidage : une réponse partie avant une modification n'est pas remise en cache
let generation = 0;
const inflight = new Map();

function readStorage() {
  try {
    const saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || 'null');
    if (saved && saved.token === currentToken()) return saved.entries || {};
  } catch {
    // stockage indisponible ou illisible : on repart de zéro
  }
  return {};
}

function writeStorage() {
  try {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ token: currentToken(), entries }));
  } catch {
    // stockage plein ou bloqué : le cache reste en mémoire
  }
}

const cleanParams = (params = {}) =>
  Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== null && params[k] !== '')
    .sort()
    .map((k) => [k, String(params[k])]);

const keyOf = (url, config = {}) => `${currentToken().slice(-12)}|${url}|${JSON.stringify(cleanParams(config.params))}`;

function readEntry(key) {
  const entry = entries[key];
  if (!entry || Date.now() - entry.at > MAX_AGE_MS) return undefined;
  return entry;
}

function saveEntry(key, data) {
  entries[key] = { data, at: Date.now() };
  const keys = Object.keys(entries);
  if (keys.length > MAX_ENTRIES) {
    keys
      .sort((a, b) => entries[a].at - entries[b].at)
      .slice(0, keys.length - MAX_ENTRIES)
      .forEach((k) => delete entries[k]);
  }
  writeStorage();
}

/** Vide tout le cache (après une modification, une connexion ou une déconnexion). */
export function clearApiCache() {
  entries = {};
  generation += 1;
  inflight.clear();
  try {
    sessionStorage.removeItem(STORAGE_KEY);
  } catch {
    // rien à faire
  }
}

/** GET mis en cache, et partagé si la même requête est déjà en cours. */
export function fetchCached(url, config = {}) {
  const key = keyOf(url, config);
  if (inflight.has(key)) return inflight.get(key);

  const gen = generation;
  const request = api.get(url, config)
    .then((res) => {
      if (gen === generation) saveEntry(key, res.data);
      return res;
    })
    .finally(() => {
      if (inflight.get(key) === request) inflight.delete(key);
    });

  inflight.set(key, request);
  return request;
}

/**
 * Affiche d'abord la copie en cache (si elle existe), puis la réponse fraîche.
 * `apply(data)` est appelé une ou deux fois. Renvoie la promesse de la réponse fraîche.
 */
export function swrGet(url, config = {}, apply) {
  const cached = readEntry(keyOf(url, config));
  if (cached && apply) apply(cached.data);
  if (cached && Date.now() - cached.at < FRESH_MS) return Promise.resolve({ data: cached.data });

  return fetchCached(url, config).then((res) => {
    if (apply) apply(res.data);
    return res;
  });
}

/** Précharge une page avant que l'utilisateur ne clique (survol d'un lien). */
export function prefetch(url, config = {}) {
  const cached = readEntry(keyOf(url, config));
  if (cached && Date.now() - cached.at < FRESH_MS) return;
  fetchCached(url, config).catch(() => {});
}
