import { useEffect, useRef, useState } from 'react';

/** Le compte à rebours apparaît 5 minutes avant le début d'un QCM. */
export const RAPPEL_MS = 5 * 60_000;
/** Dernière minute : le compte à rebours clignote en rouge. */
export const URGENT_MS = 60_000;

export const temps = (v) => (v ? new Date(v).getTime() : NaN);

const finQuiz = (d) => {
  const fin = temps(d.date_limite);
  if (!Number.isNaN(fin)) return fin;
  const debut = temps(d.date_debut);
  return Number.isNaN(debut) || !d.duree_minutes ? NaN : debut + Number(d.duree_minutes) * 60_000;
};

/**
 * Statut réel d'un QCM à l'instant `now` : le serveur le met à jour chaque minute,
 * on l'anticipe ici pour que la page passe en « En cours » / « Terminé » à la seconde près.
 */
export function statutEffectifDevoir(d, now = Date.now()) {
  if (!d || d.type !== 'qcm' || !['programme', 'en_cours'].includes(d.statut)) return d?.statut;
  if (now >= finQuiz(d)) return 'termine';
  if (now >= temps(d.date_debut)) return 'en_cours';
  return d.statut;
}

/** Phase d'un QCM : loin | bientot (≤ 5 min) | ouvert | termine | autre. */
export function phaseQuiz(d, now = Date.now()) {
  const statut = statutEffectifDevoir(d, now);
  if (d?.type !== 'qcm') return 'autre';
  if (statut === 'termine') return 'termine';
  if (statut === 'en_cours') return 'ouvert';
  if (statut !== 'programme') return 'autre';
  return temps(d.date_debut) - now <= RAPPEL_MS ? 'bientot' : 'loin';
}

/** Horloge qui avance chaque seconde tant que `actif` est vrai. */
export function useHorloge(actif = true) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!actif) return undefined;
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [actif]);
  return now;
}

/** QCM programmés ou en cours dont la page doit suivre l'heure. */
export const quizASuivre = (devoirs) =>
  (devoirs || []).filter((d) => d?.type === 'qcm' && ['programme', 'en_cours'].includes(d.statut));

/**
 * Avertit lors des changements de phase vus en direct :
 * `rappel` (≤ 5 min avant), `debut` (le quiz commence), `fin` (durée écoulée).
 */
export function useAlertesQuiz(devoirs, now, onEvenement) {
  const phases = useRef(new Map());
  const callback = useRef(onEvenement);
  useEffect(() => {
    callback.current = onEvenement;
  });

  useEffect(() => {
    for (const d of devoirs || []) {
      if (d?.type !== 'qcm') continue;
      const phase = phaseQuiz(d, now);
      const avant = phases.current.get(d.id);
      phases.current.set(d.id, phase);
      if (avant === phase) continue;
      if (phase === 'bientot' && (avant === undefined || avant === 'loin')) callback.current?.('rappel', d, now);
      if (phase === 'ouvert' && (avant === 'bientot' || avant === 'loin')) callback.current?.('debut', d, now);
      if (phase === 'termine' && avant === 'ouvert') callback.current?.('fin', d, now);
    }
  }, [devoirs, now]);
}

export const mmss = (ms) => {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};

/** Message de rappel prêt à afficher (toast). */
export const messageRappel = (d, now = Date.now()) => {
  const minutes = Math.max(1, Math.ceil((temps(d.date_debut) - now) / 60_000));
  return `Le quiz « ${d.titre} » commence dans ${minutes} minute${minutes > 1 ? 's' : ''} !`;
};

