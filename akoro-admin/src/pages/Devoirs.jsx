import { useEffect, useState } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Spinner from '../components/Spinner';
import Modal from '../components/Modal';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { ActionIconButton, ActionIconLink } from '../components/ActionIcon';
import { calculateQcmDeadline, toDateTimeLocal, toIsoDateTime } from '../utils/devoirDates';
import { typeSearch } from '../utils/validators';
import './Beneficiaires.css';
import './Parcours.css';
import './Devoirs.css';

const formatDateTime = (value) => {
  if (!value) return '—';
  return new Date(value).toLocaleString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const typeLabel = (type) => (type === 'qcm' ? 'QCM programmé' : 'Rendu PDF');

const statutLabel = (s) => {
  const map = {
    brouillon: 'Brouillon',
    programme: 'Programmé',
    en_cours: 'En cours',
    termine: 'Terminé',
    archive: 'Archivé',
  };
  return map[s] || s;
};

export default function Devoirs() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();

  const [list, setList] = useState({ data: [], current_page: 1, last_page: 1, total: 0 });
  const [parcoursList, setParcoursList] = useState([]);
  const [leconsList, setLeconsList] = useState([]);
  const [loadingLecons, setLoadingLecons] = useState(false);

  const [page, setPage] = useState(1);
  const [parcoursFilter, setParcoursFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [statutFilter, setStatutFilter] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');

  const [showModal, setShowModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    type: 'qcm',
    parcours_id: '',
    lecon_ids: [],
    titre: '',
    description: '',
    date_debut: '',
    duree_minutes: 30,
    date_limite: '',
    fichier_consigne: null,
  });
  const [formErrors, setFormErrors] = useState({});

  const load = () => {
    setRefreshing(true);
    api
      .get('/devoirs', {
        params: {
          parcours_id: parcoursFilter || undefined,
          type: typeFilter || undefined,
          statut: statutFilter || undefined,
          search: search || undefined,
          page,
        },
      })
      .then((res) => setList(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Erreur de chargement.'))
      .finally(() => {
        setLoading(false);
        setRefreshing(false);
      });
  };

  useEffect(() => {
    api.get('/parcours').then((res) => setParcoursList(res.data));
  }, []);

  // Charger les leçons dès qu’un parcours est choisi
  useEffect(() => {
    if (!form.parcours_id) {
      setLeconsList([]);
      setForm((f) => ({ ...f, lecon_ids: [] }));
      return;
    }

    setLoadingLecons(true);
    api
      .get(`/parcours/${form.parcours_id}/lecons`)
      .then((res) => setLeconsList(res.data || []))
      .catch(() => setLeconsList([]))
      .finally(() => setLoadingLecons(false));
  }, [form.parcours_id]);

  useEffect(() => {
    const timer = setTimeout(() => {
      setPage(1);
      setSearch(searchInput.trim());
    }, 350);
    return () => clearTimeout(timer);
  }, [searchInput]);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [parcoursFilter, typeFilter, statutFilter, search, page]);

  const openCreate = () => {
    setForm({
      type: 'qcm',
      parcours_id: '',
      lecon_ids: [],
      titre: '',
      description: '',
      date_debut: '',
      duree_minutes: 30,
      date_limite: '',
      fichier_consigne: null,
    });
    setLeconsList([]);
    setFormErrors({});
    setShowModal(true);
  };

  const toggleLecon = (leconId) => {
    setForm((f) => {
      const exists = f.lecon_ids.includes(leconId);
      return {
        ...f,
        lecon_ids: exists
          ? f.lecon_ids.filter((id) => id !== leconId)
          : [...f.lecon_ids, leconId],
      };
    });
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setFormErrors({});

    if (form.type === 'qcm' && form.lecon_ids.length === 0) {
      setFormErrors({ lecon_ids: 'Sélectionnez au moins une leçon de référence.' });
      return;
    }

    if (
      !(await confirm({
        title: 'Créer ce devoir ?',
        message: `Le devoir « ${form.titre.trim()} » sera créé.`,
        confirmLabel: 'Créer',
        variant: 'info',
      }))
    )
      return;

    setSaving(true);
    try {
      const formData = new FormData();
      formData.append('type', form.type);
      formData.append('parcours_id', form.parcours_id);
      formData.append('titre', form.titre.trim());
      formData.append('statut', 'brouillon');

      if (form.description.trim()) {
        formData.append('description', form.description.trim());
      }

      // Leçons de référence (QCM)
      form.lecon_ids.forEach((id) => {
        formData.append('lecon_ids[]', id);
      });

      if (form.type === 'qcm') {
        formData.append('date_debut', toIsoDateTime(form.date_debut));
        formData.append('duree_minutes', String(form.duree_minutes));
      } else {
        formData.append('date_limite', toIsoDateTime(form.date_limite));
        if (form.fichier_consigne) {
          formData.append('fichier_consigne', form.fichier_consigne);
        }
      }

      await api.post('/devoirs', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      setShowModal(false);
      showToast('Devoir créé avec succès.');
      load();
    } catch (err) {
      const errors = err.response?.data?.errors || {};
      setFormErrors({
        titre: errors.titre?.[0],
        parcours_id: errors.parcours_id?.[0],
        lecon_ids: errors.lecon_ids?.[0],
        date_debut: errors.date_debut?.[0],
        date_limite: errors.date_limite?.[0],
        duree_minutes: errors.duree_minutes?.[0],
        fichier_consigne: errors.fichier_consigne?.[0],
        general: err.response?.data?.message,
      });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (devoir) => {
    if (
      !(await confirm({
        title: 'Supprimer ce devoir ?',
        message: `Le devoir « ${devoir.titre} » sera définitivement supprimé.`,
        confirmLabel: 'Supprimer',
        variant: 'danger',
      }))
    )
      return;

    try {
      await api.delete(`/devoirs/${devoir.id}`);
      showToast('Devoir supprimé.');
      load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la suppression.');
    }
  };

  return (
    <Layout>
      <div className="devoirs-header">
        <div>
          <h1 style={{ margin: 0, fontSize: 24 }}>Devoirs</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
            Programmez des QCM synchronisés ou des devoirs à rendre (PDF / image)
          </p>
        </div>
      </div>

      <div className="devoirs-toolbar">
        <input
          className="bene-search"
          placeholder="Rechercher un devoir..."
          value={searchInput}
          onChange={(e) => setSearchInput(typeSearch(e.target.value))}
          maxLength={100}
        />
        <select
          className="bene-filter"
          value={parcoursFilter}
          onChange={(e) => {
            setPage(1);
            setParcoursFilter(e.target.value);
          }}
        >
          <option value="">Parcours : Tous</option>
          {parcoursList.map((p) => (
            <option key={p.id} value={p.id}>
              {p.nom}
            </option>
          ))}
        </select>
        <select
          className="bene-filter"
          value={typeFilter}
          onChange={(e) => {
            setPage(1);
            setTypeFilter(e.target.value);
          }}
        >
          <option value="">Type : Tous</option>
          <option value="qcm">QCM programmé</option>
          <option value="rendu">Rendu PDF</option>
        </select>
        <select
          className="bene-filter"
          value={statutFilter}
          onChange={(e) => {
            setPage(1);
            setStatutFilter(e.target.value);
          }}
        >
          <option value="">Statut : Tous</option>
          <option value="brouillon">Brouillon</option>
          <option value="programme">Programmé</option>
          <option value="en_cours">En cours</option>
          <option value="termine">Terminé</option>
        </select>
        {refreshing && !loading && <Spinner size={20} />}
        <button className="parcours-add" onClick={openCreate}>
          Nouveau devoir
        </button>
      </div>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="bene-table-wrap">
        <table className="bene-table" style={{ opacity: refreshing && !loading ? 0.65 : 1 }}>
          <thead>
            <tr>
              <th>Titre</th>
              <th>Type</th>
              <th>Parcours</th>
              <th>Date / Limite</th>
              <th>Statut</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6}>
                  <div className="table-loader">
                    <Spinner size={30} />
                  </div>
                </td>
              </tr>
            ) : list.data.length === 0 ? (
              <tr>
                <td colSpan={6}>Aucun devoir trouvé.</td>
              </tr>
            ) : (
              list.data.map((d) => (
                <tr key={d.id}>
                  <td>
                    <strong>{d.titre}</strong>
                  </td>
                  <td>
                    <span className={`devoir-type devoir-type-${d.type}`}>{typeLabel(d.type)}</span>
                  </td>
                  <td>{d.parcours?.nom || '—'}</td>
                  <td>
                    {d.type === 'qcm' ? (
                      <div className="devoir-date-summary">
                        <span>Début : {formatDateTime(d.date_debut)}</span>
                        <span>
                          Fin : {formatDateTime(d.date_limite || calculateQcmDeadline(d.date_debut, d.duree_minutes))}
                        </span>
                      </div>
                    ) : formatDateTime(d.date_limite)}
                  </td>
                  <td>
                    <span className={`devoir-statut devoir-statut-${d.statut}`}>
                      {statutLabel(d.statut)}
                    </span>
                  </td>
                  <td>
                    <div className="parcours-actions">
                      <ActionIconLink
                        icon="eye"
                        label="Voir"
                        className="bene-action"
                        to={`/devoirs/${d.id}`}
                      />
                      <ActionIconButton
                        icon="trash"
                        label="Supprimer"
                        className="bene-action parcours-delete"
                        onClick={() => handleDelete(d)}
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
        <div className="pagination" style={{ marginTop: 16, display: 'flex', gap: 8 }}>
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => p - 1)}
            className="bene-filter"
          >
            Précédent
          </button>
          <span style={{ alignSelf: 'center' }}>
            Page {list.current_page} / {list.last_page}
          </span>
          <button
            disabled={page >= list.last_page}
            onClick={() => setPage((p) => p + 1)}
            className="bene-filter"
          >
            Suivant
          </button>
        </div>
      )}

      <Modal open={showModal} title="Nouveau devoir" onClose={() => setShowModal(false)}>
        <form onSubmit={handleCreate} className="devoir-form">
          <div className="devoir-form-row">
            <label>Type de devoir</label>
            <div className="devoir-type-switch">
              <button
                type="button"
                className={form.type === 'qcm' ? 'active' : ''}
                onClick={() =>
                  setForm({ ...form, type: 'qcm', fichier_consigne: null, lecon_ids: form.lecon_ids })
                }
              >
                QCM programmé
              </button>
              <button
                type="button"
                className={form.type === 'rendu' ? 'active' : ''}
                onClick={() => setForm({ ...form, type: 'rendu' })}
              >
                Rendu PDF
              </button>
            </div>
          </div>

          <div className="devoir-form-row">
            <label>Parcours *</label>
            <select
              value={form.parcours_id}
              onChange={(e) =>
                setForm({ ...form, parcours_id: e.target.value, lecon_ids: [] })
              }
              required
            >
              <option value="">Choisir un parcours</option>
              {parcoursList.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.nom}
                </option>
              ))}
            </select>
            {formErrors.parcours_id && (
              <span className="field-error">{formErrors.parcours_id}</span>
            )}
          </div>

          {/* Leçons de référence (uniquement pour QCM, dès qu’un parcours est choisi) */}
          {form.type === 'qcm' && form.parcours_id && (
            <div className="devoir-form-row">
              <label>
                Leçons de référence pour l’IA *
                <span style={{ fontWeight: 400, color: 'var(--text-muted)' }}>
                  {' '}
                  (l’IA générera les questions à partir de ces leçons)
                </span>
              </label>

              {loadingLecons ? (
                <div style={{ padding: '12px 0' }}>
                  <Spinner size={20} />
                </div>
              ) : leconsList.length === 0 ? (
                <p style={{ color: 'var(--text-muted)', fontSize: 13, margin: '6px 0' }}>
                  Aucune leçon dans ce parcours. Ajoutez d’abord des leçons.
                </p>
              ) : (
                <div className="devoir-lecons-list">
                  {leconsList.map((lecon) => (
                    <label key={lecon.id} className="devoir-lecon-item">
                      <input
                        type="checkbox"
                        checked={form.lecon_ids.includes(lecon.id)}
                        onChange={() => toggleLecon(lecon.id)}
                      />
                      <span>{lecon.titre}</span>
                    </label>
                  ))}
                </div>
              )}
              {formErrors.lecon_ids && (
                <span className="field-error">{formErrors.lecon_ids}</span>
              )}
            </div>
          )}

          <div className="devoir-form-row">
            <label>Titre *</label>
            <input
              value={form.titre}
              onChange={(e) => setForm({ ...form, titre: e.target.value })}
              required
              maxLength={255}
            />
            {formErrors.titre && <span className="field-error">{formErrors.titre}</span>}
          </div>

          <div className="devoir-form-row">
            <label>Description</label>
            <textarea
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              rows={3}
              maxLength={2000}
            />
          </div>

          {form.type === 'qcm' ? (
            <>
              <div className="devoir-form-row">
                <label>Date et heure de début *</label>
                <input
                  type="datetime-local"
                  value={form.date_debut}
                  onChange={(e) => setForm({ ...form, date_debut: e.target.value })}
                  required
                />
                {formErrors.date_debut && (
                  <span className="field-error">{formErrors.date_debut}</span>
                )}
              </div>
              <div className="devoir-form-row">
                <label>Durée (minutes) *</label>
                <input
                  type="number"
                  min={5}
                  max={180}
                  value={form.duree_minutes}
                  onChange={(e) => setForm({ ...form, duree_minutes: e.target.value })}
                  required
                />
              </div>
              <div className="devoir-form-row">
                <label>Date limite (calculée automatiquement)</label>
                <input
                  type="datetime-local"
                  value={toDateTimeLocal(calculateQcmDeadline(form.date_debut, form.duree_minutes))}
                  readOnly
                  aria-readonly="true"
                />
              </div>
            </>
          ) : (
            <>
              <div className="devoir-form-row">
                <label>Date limite de rendu *</label>
                <input
                  type="datetime-local"
                  value={form.date_limite}
                  onChange={(e) => setForm({ ...form, date_limite: e.target.value })}
                  required
                />
                {formErrors.date_limite && (
                  <span className="field-error">{formErrors.date_limite}</span>
                )}
              </div>

              <div className="devoir-form-row">
                <label>Fichier de consigne (PDF)</label>
                <input
                  type="file"
                  accept="application/pdf"
                  onChange={(e) =>
                    setForm({ ...form, fichier_consigne: e.target.files?.[0] || null })
                  }
                />
                {form.fichier_consigne && (
                  <span className="devoir-file-name">{form.fichier_consigne.name}</span>
                )}
                {formErrors.fichier_consigne && (
                  <span className="field-error">{formErrors.fichier_consigne}</span>
                )}
              </div>
            </>
          )}

          {formErrors.general && <p className="field-error">{formErrors.general}</p>}

          <div className="devoir-form-actions">
            <button type="button" className="bene-filter" onClick={() => setShowModal(false)}>
              Annuler
            </button>
            <button type="submit" className="parcours-add" disabled={saving}>
              {saving ? <Spinner size={16} light /> : null}
              Créer le devoir
            </button>
          </div>
        </form>
      </Modal>

      {confirmationDialog}
    </Layout>
  );
}