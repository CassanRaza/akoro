import './StatutAbsence.css';

const LABELS = {
  non_justifiee: 'Non justifiée',
  a_valider: 'À valider',
  justifiee: 'Justifiée',
  refusee: 'Refusée',
};

export default function StatutAbsence({ statut }) {
  return <span className={`abs-badge abs-badge-${statut}`}>{LABELS[statut] || statut}</span>;
}