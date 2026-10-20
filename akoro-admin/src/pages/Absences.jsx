import { useEffect, useState } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Modal from '../components/Modal';
import Spinner from '../components/Spinner';
import StatutAbsence from '../components/StatutAbsence';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { ActionIconButton } from '../components/ActionIcon';
import { typeSearch, todayString } from '../utils/validators';
import './Beneficiaires.css';
import './Parcours.css';
import './Absences.css';

const formatDate = (value) =>
  new Date(`${value}T00:00:00`).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });

const hhmm = (time) => (time || '').slice(0, 5);

const monthStart = (date) => `${date.slice(0, 7)}-01`;
const shiftDate = (date, days) => {
  const shifted = new Date(`${date}T00:00:00`);
  shifted.setDate(shifted.getDate() + days);
  return [
    shifted.getFullYear(),
    String(shifted.getMonth() + 1).padStart(2, '0'),
    String(shifted.getDate()).padStart(2, '0'),
  ].join('-');
};

// Motif : pas d'espace en début ni d'espaces multiples
const typeMotif = (v) => v.replace(/^\s+/, '').replace(/ {2,}/g, ' ');

export default function Absences() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();
  const [stats, setStats] = useState(null);
  const [list, setList] = useState({ data: [], current_page: 1, last_page: 1, total: 0 });
  const [parcoursList, setParcoursList] = useState([]);

  const [dateDebut, setDateDebut] = useState(() => monthStart(todayString()));
  const [dateFin, setDateFin] = useState(todayString);
  const [parcoursFilter, setParcoursFilter] = useState('');
  const [statutFilter, setStatutFilter] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');

  // Fenêtre "Justifier"
  const [modalAbsence, setModalAbsence] = useState(null);
  const [motif, setMotif] = useState('');
  const [motifError, setMotifError] = useState('');
  const [modalSaving, setModalSaving] = useState(false);

  const load = () => {
    setRefreshing(true);
    api.get('/absences', {
      params: {
        date_debut: dateDebut || undefined,
        date_fin: dateFin || undefined,
        parcours_id: parcoursFilter || undefined,
        statut: statutFilter || undefined,
        search: search || undefined,
        page,
      },
    })
      .then((res) => {
        setStats(res.data.stats);
        setList(res.data.absences);
      })
      .catch((err) => setError(err.response?.data?.message || 'Erreur de chargement.'))
      .finally(() => {
        setInitialLoading(false);
        setRefreshing(false);
      });
  };

  useEffect(() => {
    api.get('/parcours').then((res) => setParcoursList(res.data));
  }, []);

  // Attend la fin de la frappe avant de lancer la recherche
  useEffect(() => {
    const timer = setTimeout(() => {
      setPage(1);
      setSearch(searchInput.trim());
    }, 350);
    return () => clearTimeout(timer);
  }, [searchInput]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dateDebut, dateFin, parcoursFilter, statutFilter, search, page]);

  const applyDatePreset = (preset) => {
    const today = todayString();
    setPage(1);
    if (preset === 'today') {
      setDateDebut(today);
      setDateFin(today);
    } else if (preset === '7days') {
      setDateDebut(shiftDate(today, -6));
      setDateFin(today);
    } else if (preset === '30days') {
      setDateDebut(shiftDate(today, -29));
      setDateFin(today);
    } else if (preset === 'month') {
      setDateDebut(monthStart(today));
      setDateFin(today);
    } else {
      setDateDebut('');
      setDateFin('');
    }
  };

  const activeDatePreset = (() => {
    const today = todayString();
    if (!dateDebut && !dateFin) return 'all';
    if (dateDebut === today && dateFin === today) return 'today';
    if (dateDebut === shiftDate(today, -6) && dateFin === today) return '7days';
    if (dateDebut === shiftDate(today, -29) && dateFin === today) return '30days';
    if (dateDebut === monthStart(today) && dateFin === today) return 'month';
    return '';
  })();

  // ---------- Actions ----------
  const changerStatut = async (absence, statut) => {
    const label = statut === 'justifiee' ? 'Valider' : 'Refuser';
    if (!(await confirm({
      title: `${label} ce justificatif ?`,
      message: `Le justificatif de ${absence.user?.name} du ${formatDate(absence.date)} sera ${statut === 'justifiee' ? 'validé' : 'refusé'}.`,
      confirmLabel: label,
      variant: statut === 'justifiee' ? 'info' : 'warning',
    }))) return;

    setError('');
    try {
      await api.put(`/absences/${absence.id}`, { statut });
      showToast(statut === 'justifiee' ? 'Justificatif validé avec succès.' : 'Justificatif refusé.');
      load();
    } catch (err) {
      setError(
        err.response?.data?.errors?.motif?.[0] || err.response?.data?.message || 'Erreur lors de la mise à jour.'
      );
    }
  };

  const annuler = async (absence) => {
    if (!(await confirm({
      title: 'Annuler cette absence ?',
      message: `L'absence de ${absence.user?.name} du ${formatDate(absence.date)} sera supprimée.`,
      confirmLabel: 'Annuler l’absence',
      variant: 'danger',
    }))) return;
    setError('');
    try {
      await api.delete(`/absences/${absence.id}`);
      showToast('Absence annulée avec succès.');
      load();
    } catch (err) {
      setError(err.response?.data?.message || "Erreur lors de l'annulation.");
    }
  };

  const ouvrirJustifier = (absence) => {
    setModalAbsence(absence);
    setMotif(absence.motif || '');
    setMotifError('');
  };

  const fermerModal = () => setModalAbsence(null);

  const submitJustifier = async (e) => {
    e.preventDefault();

    if (motif.trim().length < 3) {
      setMotifError('Le motif est obligatoire (3 caractères minimum).');
      return;
    }

    if (!(await confirm({
      title: 'Enregistrer cette justification ?',
      message: `L'absence de ${modalAbsence.user?.name} du ${formatDate(modalAbsence.date)} sera marquée comme justifiée.`,
      confirmLabel: 'Justifier',
      variant: 'info',
    }))) return;

    setModalSaving(true);
    try {
      await api.put(`/absences/${modalAbsence.id}`, { statut: 'justifiee', motif: motif.trim() });
      setModalAbsence(null);
      showToast('Absence justifiée avec succès.');
      load();
    } catch (err) {
      setMotifError(
        err.response?.data?.errors?.motif?.[0] || err.response?.data?.message || 'Erreur lors de la justification.'
      );
    } finally {
      setModalSaving(false);
    }
  };

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Historique des absences</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        Suivre et valider les justificatifs d'absences envoyés via l'application mobile
      </p>

      {stats && (
        <div className="abs-stats">
          <div className="abs-stat">
            <div className="abs-stat-value">{stats.total}</div>
            <div className="abs-stat-label">Total des absences</div>
          </div>
          <div className="abs-stat abs-stat-warn">
            <div className="abs-stat-value">{stats.non_justifiees}</div>
            <div className="abs-stat-label">Non justifiées (à clarifier)</div>
          </div>
          <div className="abs-stat abs-stat-pending">
            <div className="abs-stat-value">{stats.a_valider}</div>
            <div className="abs-stat-label">Justificatifs à valider</div>
          </div>
          <div className="abs-stat">
            <div className="abs-stat-value">{stats.taux !== null ? `${stats.taux} %` : '—'}</div>
            <div className="abs-stat-label">Taux d'absentéisme</div>
          </div>
        </div>
      )}

      <div className="abs-filters">
        <input
          className="bene-search abs-search"
          placeholder="Rechercher un bénéficiaire..."
          value={searchInput}
          onChange={(e) => setSearchInput(typeSearch(e.target.value))}
          maxLength={100}
        />
        <div className="abs-date-filter" aria-label="Filtrer par période">
          <div className="abs-date-presets" role="group" aria-label="Périodes rapides">
            {[
              ['today', "Aujourd'hui"],
              ['7days', '7 jours'],
              ['30days', '30 jours'],
              ['month', 'Ce mois'],
              ['all', 'Tout'],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                className={`abs-date-preset${activeDatePreset === value ? ' abs-date-preset-active' : ''}`}
                onClick={() => applyDatePreset(value)}
                aria-pressed={activeDatePreset === value}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="abs-date-inputs">
            <label>
              <span>Du</span>
              <input
                type="date"
                value={dateDebut}
                max={dateFin || undefined}
                onChange={(e) => { setPage(1); setDateDebut(e.target.value); }}
                aria-label="Date de début"
              />
            </label>
            <span className="abs-date-separator" aria-hidden="true">→</span>
            <label>
              <span>Au</span>
              <input
                type="date"
                value={dateFin}
                min={dateDebut || undefined}
                onChange={(e) => { setPage(1); setDateFin(e.target.value); }}
                aria-label="Date de fin"
              />
            </label>
          </div>
        </div>
        <select
          className="bene-filter"
          value={parcoursFilter}
          onChange={(e) => { setPage(1); setParcoursFilter(e.target.value); }}
        >
          <option value="">Parcours : Tous</option>
          {parcoursList.map((p) => (
            <option key={p.id} value={p.id}>{p.nom}</option>
          ))}
        </select>
        <select
          className="bene-filter"
          value={statutFilter}
          onChange={(e) => { setPage(1); setStatutFilter(e.target.value); }}
        >
          <option value="">Justification : Toutes</option>
          <option value="non_justifiee">Non justifiées</option>
          <option value="a_valider">À valider</option>
          <option value="justifiee">Justifiées</option>
          <option value="refusee">Refusées</option>
        </select>
        {refreshing && !initialLoading && <Spinner size={20} />}
      </div>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="bene-table-wrap">
        <table className="bene-table" style={{ opacity: refreshing && !initialLoading ? 0.65 : 1 }}>
          <thead>
            <tr>
              <th>Date</th>
              <th>Bénéficiaire</th>
              <th>Parcours</th>
              <th>Leçon</th>
              <th>Motif</th>
              <th>Justification</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {initialLoading ? (
              <tr>
                <td colSpan={7}>
                  <div className="table-loader"><Spinner size={30} /></div>
                </td>
              </tr>
            ) : list.data.length === 0 ? (
              <tr><td colSpan={7}>Aucune absence trouvée pour ces filtres.</td></tr>
            ) : (
              list.data.map((a) => (
                <tr key={a.id}>
                  <td>{formatDate(a.date)}</td>
                  <td>
                    <div className="abs-who">
                      <Avatar name={a.user?.name || ''} url={a.user?.photo_url} size={32} />
                      <span>{a.user?.name}</span>
                    </div>
                  </td>
                  <td>{a.user?.parcours?.nom || '—'}</td>
                  <td>
                    {a.lecon?.titre || 'Séance libre'}
                    {a.seance && (
                      <span className="abs-sub">{hhmm(a.seance.heure_debut)} – {hhmm(a.seance.heure_fin)}</span>
                    )}
                  </td>
                  <td>
                    <div className="abs-motif" title={a.motif || ''}>{a.motif || 'Pas de motif fourni'}</div>
                  </td>
                  <td><StatutAbsence statut={a.statut} /></td>
                  <td>
                    <div className="abs-actions">
                      {a.statut === 'a_valider' && (
                        <>
                          <ActionIconButton
                            icon="check"
                            label="Valider"
                            className="bene-action abs-ok"
                            onClick={() => changerStatut(a, 'justifiee')}
                          />
                          <ActionIconButton
                            icon="x"
                            label="Refuser"
                            className="bene-action abs-danger"
                            onClick={() => changerStatut(a, 'refusee')}
                          />
                        </>
                      )}
                      {(a.statut === 'non_justifiee' || a.statut === 'refusee') && (
                        <ActionIconButton
                          icon="justify"
                          label="Justifier"
                          className="bene-action abs-ok"
                          onClick={() => ouvrirJustifier(a)}
                        />
                      )}
                      <ActionIconButton
                        icon="cancel"
                        label="Annuler cette absence"
                        className="bene-action abs-danger"
                        onClick={() => annuler(a)}
                      />
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {list.last_page > 1 && (
        <div className="bene-pagination">
          <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Précédent</button>
          <span>Page {list.current_page} / {list.last_page} — {list.total} absences</span>
          <button disabled={page >= list.last_page} onClick={() => setPage((p) => p + 1)}>Suivant</button>
        </div>
      )}

      <Modal open={!!modalAbsence} title="Justifier l'absence" onClose={fermerModal}>
        {modalAbsence && (
          <form onSubmit={submitJustifier} noValidate>
            <p className="abs-modal-info">
              {modalAbsence.user?.name} — absence du {formatDate(modalAbsence.date)}
            </p>
            <textarea
              className={'abs-textarea' + (motifError ? ' abs-input-error' : '')}
              placeholder="Motif de l'absence"
              value={motif}
              onChange={(e) => {
                setMotif(typeMotif(e.target.value));
                setMotifError('');
              }}
              maxLength={255}
              autoFocus
            />
            {motifError && <p className="abs-field-error">{motifError}</p>}

            <div className="modal-actions">
              <button type="submit" className="parcours-add" disabled={modalSaving}>
                {modalSaving ? <Spinner size={16} light /> : null}
                Justifier
              </button>
              <button type="button" className="bene-action" onClick={fermerModal}>Annuler</button>
            </div>
          </form>
        )}
      </Modal>
      {confirmationDialog}
    </Layout>
  );
}