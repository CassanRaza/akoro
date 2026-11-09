import { useEffect, useSyncExternalStore } from 'react';
import api from './api';

// Données de la cloche et de l'icône messagerie, partagées entre toutes les pages.
// Un seul appel /notifications au plus toutes les 30 s, même si l'on change de page.

const CACHE_MS = 30 * 1000;
const POLL_MS = 60 * 1000;
const SEEN_KEY = 'akoro_notif_vues';

let state = { data: null, loading: false, at: 0 };
const listeners = new Set();

const emit = (patch) => {
  state = { ...state, ...patch };
  listeners.forEach((l) => l());
};

export function refreshNotifications(force = false) {
  if (state.loading) return;
  if (!force && Date.now() - state.at < CACHE_MS) return;
  if (!localStorage.getItem('akoro_token')) return;

  emit({ loading: true });
  api.get('/notifications')
    .then((res) => emit({ data: res.data, loading: false, at: Date.now() }))
    .catch(() => emit({ loading: false, at: Date.now() }));
}

const subscribe = (l) => {
  listeners.add(l);
  return () => listeners.delete(l);
};

export function useNotifications() {
  const snapshot = useSyncExternalStore(subscribe, () => state);

  useEffect(() => {
    refreshNotifications();
    const timer = setInterval(() => {
      if (!document.hidden) refreshNotifications(true);
    }, POLL_MS);
    const onVisible = () => !document.hidden && refreshNotifications();
    const onForce = () => refreshNotifications(true);
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('akoro:notifications-refresh', onForce);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
      window.removeEventListener('akoro:notifications-refresh', onForce);
    };
  }, []);

  return snapshot;
}

// ---------- Alertes déjà vues (propre à ce navigateur) ----------
export function getSeen() {
  try {
    return new Set(JSON.parse(localStorage.getItem(SEEN_KEY) || '[]'));
  } catch {
    return new Set();
  }
}

export function markSeen(ids) {
  try {
    // On ne garde que les identifiants encore d'actualité
    localStorage.setItem(SEEN_KEY, JSON.stringify([...new Set(ids)].slice(-200)));
  } catch {
    // stockage indisponible : la pastille réapparaîtra, sans gravité
  }
}
