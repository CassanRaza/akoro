import { mmss, phaseQuiz, temps, URGENT_MS } from '../utils/quizTemps';
import './CompteAReboursQuiz.css';

/** Badge « Commence dans mm:ss » : visible 5 min avant le début, clignote en rouge la dernière minute. */
export default function CompteAReboursQuiz({ devoir, now }) {
  if (phaseQuiz(devoir, now) !== 'bientot') return null;
  const reste = temps(devoir.date_debut) - now;
  const urgent = reste <= URGENT_MS;
  const secondes = Math.max(0, Math.ceil(reste / 1000));
  return (
    <span
      className={`cr-quiz${urgent ? ' cr-quiz-urgent' : ''}`}
      role="timer"
      aria-live={urgent ? 'assertive' : 'off'}
      aria-label={`Le quiz commence dans ${Math.floor(secondes / 60)} minutes ${secondes % 60} secondes`}
    >
      <svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true">
        <circle cx="12" cy="13" r="8" fill="none" stroke="currentColor" strokeWidth="2" />
        <path d="M12 9v4l2.5 2M9 2h6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      </svg>
      Commence dans {mmss(reste)}
    </span>
  );
}
