import { prefetch } from './api';
import { todayString } from '../utils/validators';

// Données à précharger pour chaque page, avec exactement les mêmes filtres
// que la page utilise à son ouverture (sinon la copie ne serait pas retrouvée).
const ROUTES = [
  [/^\/dashboard$/, () => [['/dashboard', { params: { periode: 'semaine' } }]]],
  [/^\/beneficiaires$/, () => [['/beneficiaires', { params: { page: 1 } }], ['/parcours']]],
  [/^\/beneficiaires\/(\d+)$/, (id) => [[`/beneficiaires/${id}`]]],
  [/^\/parcours$/, () => [['/parcours']]],
  [/^\/parcours\/(\d+)$/, (id) => [[`/parcours/${id}`], [`/parcours/${id}/lecons`], [`/parcours/${id}/seances`]]],
  [/^\/absences$/, () => {
    const today = todayString();
    return [
      ['/absences', { params: { date_debut: `${today.slice(0, 7)}-01`, date_fin: today, page: 1 } }],
      ['/parcours'],
    ];
  }],
  [/^\/devoirs$/, () => [['/devoirs', { params: { page: 1 } }], ['/parcours']]],
  [/^\/devoirs\/(\d+)$/, (id) => [[`/devoirs/${id}`]]],
  [/^\/administrateurs$/, () => [['/administrateurs']]],
  [/^\/administrateurs\/(\d+)$/, (id) => [[`/administrateurs/${id}`]]],
  [/^\/discussion$/, () => [['/conversations'], ['/parcours']]],
  [/^\/fabia$/, () => [['/fabia/connaissances']]],
];

export function prefetchPath(pathname) {
  for (const [pattern, requests] of ROUTES) {
    const match = pathname.match(pattern);
    if (match) {
      requests(match[1]).forEach(([url, config]) => prefetch(url, config));
      return;
    }
  }
}

/**
 * Survol (ou focus clavier) d'un lien interne pendant 80 ms : on charge déjà
 * les données de la page visée. Au clic, elle s'affiche instantanément.
 */
export function installLinkPrefetch(root = document) {
  let timer = null;
  let current = null;

  const linkFrom = (target) => {
    const a = target?.closest?.('a[href]');
    if (!a || a.target === '_blank' || a.origin !== window.location.origin) return null;
    return a;
  };

  const onEnter = (e) => {
    const a = linkFrom(e.target);
    if (!a || a === current) return;
    current = a;
    clearTimeout(timer);
    const path = a.pathname;
    if (path === window.location.pathname) return;
    timer = setTimeout(() => prefetchPath(path), 80);
  };

  const onLeave = (e) => {
    const a = linkFrom(e.target);
    if (a && a === current && !a.contains(e.relatedTarget)) {
      clearTimeout(timer);
      current = null;
    }
  };

  // Sur écran tactile, le doigt touche le lien juste avant le clic : on démarre aussitôt
  const onTouch = (e) => {
    const a = linkFrom(e.target);
    if (a && a.pathname !== window.location.pathname) prefetchPath(a.pathname);
  };

  root.addEventListener('pointerover', onEnter);
  root.addEventListener('pointerout', onLeave);
  root.addEventListener('focusin', onEnter);
  root.addEventListener('touchstart', onTouch, { passive: true });

  return () => {
    clearTimeout(timer);
    root.removeEventListener('pointerover', onEnter);
    root.removeEventListener('pointerout', onLeave);
    root.removeEventListener('focusin', onEnter);
    root.removeEventListener('touchstart', onTouch);
  };
}
