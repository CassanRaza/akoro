import { useEffect, useState } from 'react';
import { Link, useParams, useSearchParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Spinner, { PageLoader } from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import {
  typeLabel, checkLabel, checkFichier, checkSeance,
  formatSize, todayString, ACCEPT_FICHIERS,
} from '../utils/validators';
import './Beneficiaires.css';
import './Parcours.css';
import './ParcoursDetail.css';
import './ParcoursDetailDownload.css';
import './Seances.css';

// Description : pas d'espace en début ni d'espaces multiples (les retours à la ligne restent permis)
const typeDescription = (v) => v.replace(/^\s+/, '').replace(/ {2,}/g, ' ');

const formatSeanceDate = (value) =>
  new Date(`${value}T00:00:00`).toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

const hhmm = (time) => (time || '').slice(0, 5);

const DownloadIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="7 10 12 15 17 10" />
    <line x1="12" y1="15" x2="12" y2="3" />
  </svg>
);

export default function ParcoursDetail() {
  const { confirm, confirmationDialog } = useConfirmation();
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  const [parcours, setParcours] = useState(null);
  const [lecons, setLecons] = useState([]);
  const [seances, setSeances] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Formulaire d'ajout de leçon
  const [showForm, setShowForm] = useState(searchParams.get('ajout') === '1');
  const [titre, setTitre] = useState('');
  const [description, setDescription] = useState('');
  const [fichier, setFichier] = useState(null);
  const [fieldErrors, setFieldErrors] = useState({ titre: '', description: '', fichier: '' });
  const [saving, setSaving] = useState(false);

  // Modification d'une leçon
  const [editingId, setEditingId] = useState(null);
  const [editTitre, setEditTitre] = useState('');
  const [editDescription, setEditDescription] = useState('');
  const [editErrors, setEditErrors] = useState({ titre: '', description: '' });
  const [editSaving, setEditSaving] = useState(false);

  // Documents
  const [uploadingId, setUploadingId] = useState(null);
  const [lessonErrors, setLessonErrors] = useState({});

  // Séances planifiées
  const [showSeanceForm, setShowSeanceForm] = useState(false);
  const [sLecon, setSLecon] = useState('');
  const [sDate, setSDate] = useState('');
  const [sDebut, setSDebut] = useState('');
  const [sFin, setSFin] = useState('');
  const [seanceErrors, setSeanceErrors] = useState({ lecon: '', date: '', debut: '', fin: '' });
  const [seanceSaving, setSeanceSaving] = useState(false);
  const [seanceError, setSeanceError] = useState('');

  const loadLecons = () => api.get(`/parcours/${id}/lecons`).then((res) => setLecons(res.data));
  const loadSeances = () => api.get(`/parcours/${id}/seances`).then((res) => setSeances(res.data));

  useEffect(() => {
    Promise.all([
      api.get(`/parcours/${id}`),
      api.get(`/parcours/${id}/lecons`),
      api.get(`/parcours/${id}/seances`),
    ])
      .then(([p, l, s]) => {
        setParcours(p.data);
        setLecons(l.data);
        setSeances(s.data);
      })
      .catch((err) => {
        if ([403, 404].includes(err.response?.status)) {
          navigate('/parcours', { replace: true });
        } else {
          setError(err.response?.data?.message || 'Erreur de chargement.');
        }
      })
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const setLessonError = (leconId, message) =>
    setLessonErrors((prev) => ({ ...prev, [leconId]: message }));

  // ---------- Leçons : ajout ----------
  const handleCreate = async (e) => {
    e.preventDefault();
    setError('');

    const errors = {
      titre: checkLabel(titre, 'Le titre de la leçon'),
      description: description.length > 1000 ? 'La description est trop longue (1000 caractères maximum).' : '',
      fichier: fichier ? checkFichier(fichier) : '',
    };
    setFieldErrors(errors);
    if (errors.titre || errors.description || errors.fichier) return;

    if (!(await confirm({
      title: 'Ajouter cette leçon ?',
      message: fichier
        ? `La leçon « ${titre.trim()} » et le fichier « ${fichier.name} » seront ajoutés au parcours.`
        : `La leçon « ${titre.trim()} » sera ajoutée au parcours.`,
      confirmLabel: 'Ajouter',
      variant: 'info',
    }))) return;

    setSaving(true);
    try {
      const { data: nouvelleLecon } = await api.post(`/parcours/${id}/lecons`, {
        titre: titre.trim(),
        description: description.trim(),
      });

      let erreurFichier = '';
      if (fichier) {
        const formData = new FormData();
        formData.append('fichier', fichier);
        try {
          await api.post(`/lecons/${nouvelleLecon.id}/ressources`, formData);
        } catch (err) {
          erreurFichier = err.response?.data?.errors?.fichier?.[0]
            || err.response?.data?.message
            || "Le fichier n'a pas pu être ajouté. Vous pourrez réessayer depuis la leçon créée.";
        }
      }

      setTitre('');
      setDescription('');
      setFichier(null);
      setFieldErrors({ titre: '', description: '', fichier: '' });
      setShowForm(false);
      try {
        await loadLecons();
      } catch (err) {
        setError(err.response?.data?.message || 'La leçon a été créée, mais la liste n’a pas pu être actualisée.');
      }
      if (erreurFichier) {
        setError(`La leçon a été créée, mais le fichier n’a pas été ajouté. ${erreurFichier}`);
      }
    } catch (err) {
      const serverErrors = err.response?.data?.errors;
      if (serverErrors) {
        setFieldErrors({
          titre: serverErrors.titre?.[0] || '',
          description: serverErrors.description?.[0] || '',
          fichier: '',
        });
      } else {
        setError(err.response?.data?.message || 'Erreur lors de la création.');
      }
    } finally {
      setSaving(false);
    }
  };

  // ---------- Leçons : modification ----------
  const startEdit = (lecon) => {
    setEditingId(lecon.id);
    setEditTitre(lecon.titre);
    setEditDescription(lecon.description || '');
    setEditErrors({ titre: '', description: '' });
  };

  const cancelEdit = () => setEditingId(null);

  const handleUpdate = async (lecon) => {
    const errors = {
      titre: checkLabel(editTitre, 'Le titre de la leçon'),
      description: editDescription.length > 1000 ? 'La description est trop longue (1000 caractères maximum).' : '',
    };
    setEditErrors(errors);
    if (errors.titre || errors.description) return;

    if (!(await confirm({
      title: 'Enregistrer les modifications ?',
      message: `Les modifications de la leçon « ${editTitre.trim()} » seront enregistrées.`,
      confirmLabel: 'Enregistrer',
      variant: 'info',
    }))) return;

    setEditSaving(true);
    try {
      await api.put(`/lecons/${lecon.id}`, {
        titre: editTitre.trim(),
        description: editDescription.trim(),
      });
      setEditingId(null);
      await loadLecons();
      await loadSeances();
    } catch (err) {
      const serverErrors = err.response?.data?.errors;
      if (serverErrors) {
        setEditErrors({
          titre: serverErrors.titre?.[0] || '',
          description: serverErrors.description?.[0] || '',
        });
      } else {
        setLessonError(lecon.id, err.response?.data?.message || 'Erreur lors de la modification.');
      }
    } finally {
      setEditSaving(false);
    }
  };

  // ---------- Leçons : suppression ----------
  const handleDeleteLecon = async (lecon) => {
    if (!(await confirm({
      title: 'Supprimer cette leçon ?',
      message: 'Cette leçon et tous les documents associés seront supprimés.',
      confirmLabel: 'Supprimer',
      variant: 'danger',
    }))) return;
    setError('');
    try {
      await api.delete(`/lecons/${lecon.id}`);
      await loadLecons();
      await loadSeances();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la suppression.');
    }
  };

  // ---------- Documents ----------
  const handleUpload = async (lecon, e) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // permet de re-choisir le même fichier
    setLessonError(lecon.id, '');

    const message = checkFichier(file);
    if (message) {
      setLessonError(lecon.id, message);
      return;
    }

    if (!(await confirm({
      title: 'Ajouter ce document ?',
      message: `Le fichier sera ajouté à la leçon « ${lecon.titre} ».`,
      confirmLabel: 'Ajouter',
      variant: 'info',
    }))) return;

    const formData = new FormData();
    formData.append('fichier', file);

    setUploadingId(lecon.id);
    try {
      await api.post(`/lecons/${lecon.id}/ressources`, formData);
      await loadLecons();
    } catch (err) {
      setLessonError(
        lecon.id,
        err.response?.data?.errors?.fichier?.[0] || err.response?.data?.message || "Échec de l'envoi du fichier."
      );
    } finally {
      setUploadingId(null);
    }
  };

  const handleDeleteDoc = async (lecon, ressource) => {
    if (!(await confirm({
      title: 'Supprimer ce document ?',
      message: `Le document « ${ressource.titre} » sera supprimé.`,
      confirmLabel: 'Supprimer',
      variant: 'danger',
    }))) return;
    setLessonError(lecon.id, '');
    try {
      await api.delete(`/ressources/${ressource.id}`);
      await loadLecons();
    } catch (err) {
      setLessonError(lecon.id, err.response?.data?.message || 'Erreur lors de la suppression.');
    }
  };

  // ---------- Séances ----------
  const handleCreateSeance = async (e) => {
    e.preventDefault();
    setSeanceError('');

    const errors = checkSeance({ date: sDate, debut: sDebut, fin: sFin });
    setSeanceErrors({ lecon: '', ...errors });
    if (errors.date || errors.debut || errors.fin) return;

    if (!(await confirm({
      title: 'Planifier cette séance ?',
      message: `Une séance le ${formatSeanceDate(sDate)} de ${hhmm(sDebut)} à ${hhmm(sFin)} sera ajoutée.`,
      confirmLabel: 'Planifier',
      variant: 'info',
    }))) return;

    setSeanceSaving(true);
    try {
      await api.post(`/parcours/${id}/seances`, {
        lecon_id: sLecon || null,
        date: sDate,
        heure_debut: sDebut,
        heure_fin: sFin,
      });
      setSLecon('');
      setSDate('');
      setSDebut('');
      setSFin('');
      setShowSeanceForm(false);
      await loadSeances();
    } catch (err) {
      const serverErrors = err.response?.data?.errors;
      if (serverErrors) {
        setSeanceErrors({
          lecon: serverErrors.lecon_id?.[0] || '',
          date: serverErrors.date?.[0] || '',
          debut: serverErrors.heure_debut?.[0] || '',
          fin: serverErrors.heure_fin?.[0] || '',
        });
      } else {
        setSeanceError(err.response?.data?.message || 'Erreur lors de la planification.');
      }
    } finally {
      setSeanceSaving(false);
    }
  };

  const handleDeleteSeance = async (seance) => {
    if (!(await confirm({
      title: 'Supprimer cette séance ?',
      message: 'Cette séance planifiée sera supprimée.',
      confirmLabel: 'Supprimer',
      variant: 'danger',
    }))) return;
    setSeanceError('');
    try {
      await api.delete(`/seances/${seance.id}`);
      await loadSeances();
    } catch (err) {
      setSeanceError(err.response?.data?.message || 'Erreur lors de la suppression.');
    }
  };

  if (loading) {
    return (
      <Layout>
        <PageLoader />
      </Layout>
    );
  }

  const today = todayString();
  const upcoming = seances.filter((s) => s.date >= today);
  const past = seances.filter((s) => s.date < today).reverse().slice(0, 5);

  return (
    <Layout>
      <Link to="/parcours" className="pd-back">← Parcours & Leçons</Link>

      <div className="pd-header">
        <div>
          <h1 style={{ margin: 0, fontSize: 24 }}>{parcours?.nom}</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
            {parcours?.description || 'Sans description'}
          </p>
          <span className="pd-count">
            {lecons.length} leçon{lecons.length > 1 ? 's' : ''}
          </span>
        </div>

        {!showForm && (
          <button className="parcours-add" onClick={() => setShowForm(true)}>
            + Ajouter une leçon
          </button>
        )}
      </div>

      {error && <p style={{ color: 'var(--error-text)', marginTop: 16 }}>{error}</p>}

      {showForm && (
        <form onSubmit={handleCreate} className="pd-form" noValidate>
          <h2 className="pd-form-title">Ajouter une leçon</h2>
          <input
            className={'pd-input' + (fieldErrors.titre ? ' pd-input-error' : '')}
            placeholder="Titre de la leçon"
            value={titre}
            onChange={(e) => {
              setTitre(typeLabel(e.target.value));
              setFieldErrors((f) => ({ ...f, titre: '' }));
            }}
            maxLength={100}
            autoFocus
          />
          {fieldErrors.titre && <p className="pd-field-error">{fieldErrors.titre}</p>}

          <textarea
            className={'pd-textarea' + (fieldErrors.description ? ' pd-input-error' : '')}
            placeholder="Description (facultatif)"
            value={description}
            onChange={(e) => {
              setDescription(typeDescription(e.target.value));
              setFieldErrors((f) => ({ ...f, description: '' }));
            }}
            maxLength={1000}
          />
          {fieldErrors.description && <p className="pd-field-error">{fieldErrors.description}</p>}

          <div className="pd-file-field">
            <label className="pd-file-label" htmlFor="pd-lecon-file">Ajouter un fichier (facultatif)</label>
            <input
              id="pd-lecon-file"
              className="pd-file-input"
              type="file"
              accept={ACCEPT_FICHIERS}
              onChange={(e) => {
                setFichier(e.target.files?.[0] || null);
                setFieldErrors((f) => ({ ...f, fichier: '' }));
              }}
              disabled={saving}
            />
            <span className="pd-file-help">PDF, documents, images et autres formats autorisés (20 Mo maximum).</span>
            {fichier && <span className="pd-file-name">{fichier.name}</span>}
            {fieldErrors.fichier && <p className="pd-field-error">{fieldErrors.fichier}</p>}
          </div>

          <div className="pd-form-actions">
            <button type="submit" className="parcours-add" disabled={saving}>
              {saving ? <Spinner size={16} light /> : null}
              Enregistrer
            </button>
            <button
              type="button"
              className="bene-action"
              onClick={() => {
                setShowForm(false);
                setTitre('');
                setDescription('');
                setFichier(null);
                setFieldErrors({ titre: '', description: '', fichier: '' });
              }}
            >
              Annuler
            </button>
          </div>
        </form>
      )}

      {lecons.length === 0 ? (
        <div className="lecon-empty">
          Aucune leçon dans ce parcours pour le moment.
        </div>
      ) : (
        <div className="lecon-list">
          {lecons.map((lecon, index) => (
            <div key={lecon.id} className="lecon-card">
              <div className="lecon-number">{index + 1}</div>

              <div className="lecon-body">
                {editingId === lecon.id ? (
                  <>
                    <input
                      className={'pd-input' + (editErrors.titre ? ' pd-input-error' : '')}
                      value={editTitre}
                      onChange={(e) => {
                        setEditTitre(typeLabel(e.target.value));
                        setEditErrors((f) => ({ ...f, titre: '' }));
                      }}
                      maxLength={100}
                    />
                    {editErrors.titre && <p className="pd-field-error">{editErrors.titre}</p>}

                    <textarea
                      className={'pd-textarea' + (editErrors.description ? ' pd-input-error' : '')}
                      style={{ marginTop: 8 }}
                      value={editDescription}
                      onChange={(e) => {
                        setEditDescription(typeDescription(e.target.value));
                        setEditErrors((f) => ({ ...f, description: '' }));
                      }}
                      maxLength={1000}
                    />
                    {editErrors.description && (
                      <p className="pd-field-error">{editErrors.description}</p>
                    )}

                    <div className="pd-form-actions">
                      <button
                        className="parcours-add"
                        onClick={() => handleUpdate(lecon)}
                        disabled={editSaving}
                      >
                        {editSaving ? <Spinner size={16} light /> : null}
                        Enregistrer
                      </button>
                      <button className="bene-action" onClick={cancelEdit}>Annuler</button>
                    </div>
                  </>
                ) : (
                  <>
                    <h3 className="lecon-title">{lecon.titre}</h3>
                    {lecon.description && <p className="lecon-desc">{lecon.description}</p>}
                  </>
                )}

                {lecon.ressources?.length > 0 && (
                  <ul className="lecon-docs">
                    {lecon.ressources.map((r) => (
                      <li key={r.id} className="lecon-doc">
                        <span className="lecon-doc-badge">{(r.type || 'fichier').toUpperCase()}</span>
                        <a href={r.url} target="_blank" rel="noreferrer" title={r.nom_fichier}>
                          {r.titre}
                        </a>
                        <span className="lecon-doc-size">{formatSize(r.taille)}</span>
                        <a
                          className="lecon-doc-download"
                          href={r.download_url}
                          title="Télécharger le document"
                          aria-label="Télécharger le document"
                        >
                          <DownloadIcon />
                        </a>
                        <button
                          className="lecon-doc-delete"
                          onClick={() => handleDeleteDoc(lecon, r)}
                          aria-label="Supprimer le document"
                          title="Supprimer le document"
                        >
                          ✕
                        </button>
                      </li>
                    ))}
                  </ul>
                )}

                {lessonErrors[lecon.id] && <p className="lecon-error">{lessonErrors[lecon.id]}</p>}
              </div>

              {editingId !== lecon.id && (
                <div className="lecon-actions">
                  <label className="bene-action lecon-upload">
                    {uploadingId === lecon.id ? <Spinner size={14} /> : null}
                    {uploadingId === lecon.id ? 'Envoi' : 'Ajouter un fichier'}
                    <input
                      type="file"
                      accept={ACCEPT_FICHIERS}
                      onChange={(e) => handleUpload(lecon, e)}
                      disabled={uploadingId === lecon.id}
                    />
                  </label>

                  <button className="bene-action" onClick={() => startEdit(lecon)}>Modifier</button>
                  <button
                    className="bene-action parcours-delete"
                    onClick={() => handleDeleteLecon(lecon)}
                  >
                    Supprimer
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* ---------- Séances planifiées ---------- */}
      <section className="sc-section">
        <div className="sc-header">
          <div>
            <h2 className="sc-title">Séances planifiées</h2>
            <p style={{ color: 'var(--text-muted)', margin: '4px 0 0', fontSize: 14 }}>
              Les absences sont déduites de ces séances : un bénéficiaire qui n'a pas pointé sur le mobile sera marqué absent.
            </p>
          </div>

          {!showSeanceForm && (
            <button className="parcours-add" onClick={() => setShowSeanceForm(true)}>
              + Planifier une séance
            </button>
          )}
        </div>

        {seanceError && <p style={{ color: 'var(--error-text)', marginTop: 12 }}>{seanceError}</p>}

        {showSeanceForm && (
          <form onSubmit={handleCreateSeance} className="sc-form" noValidate>
            <div className="sc-field sc-field-wide">
              <label className="sc-label">Leçon (facultatif)</label>
              <select
                className="pd-input sc-input"
                value={sLecon}
                onChange={(e) => {
                  setSLecon(e.target.value);
                  setSeanceErrors((f) => ({ ...f, lecon: '' }));
                }}
              >
                <option value="">Séance libre (sans leçon)</option>
                {lecons.map((l, i) => (
                  <option key={l.id} value={l.id}>{i + 1}. {l.titre}</option>
                ))}
              </select>
              {seanceErrors.lecon && <p className="pd-field-error">{seanceErrors.lecon}</p>}
            </div>

            <div className="sc-field">
              <label className="sc-label">Date</label>
              <input
                type="date"
                className={'pd-input sc-input' + (seanceErrors.date ? ' pd-input-error' : '')}
                value={sDate}
                min={todayString()}
                onChange={(e) => {
                  setSDate(e.target.value);
                  setSeanceErrors((f) => ({ ...f, date: '' }));
                }}
              />
              {seanceErrors.date && <p className="pd-field-error">{seanceErrors.date}</p>}
            </div>

            <div className="sc-field">
              <label className="sc-label">Début</label>
              <input
                type="time"
                className={'pd-input sc-input' + (seanceErrors.debut ? ' pd-input-error' : '')}
                value={sDebut}
                onChange={(e) => {
                  setSDebut(e.target.value);
                  setSeanceErrors((f) => ({ ...f, debut: '' }));
                }}
              />
              {seanceErrors.debut && <p className="pd-field-error">{seanceErrors.debut}</p>}
            </div>

            <div className="sc-field">
              <label className="sc-label">Fin</label>
              <input
                type="time"
                className={'pd-input sc-input' + (seanceErrors.fin ? ' pd-input-error' : '')}
                value={sFin}
                onChange={(e) => {
                  setSFin(e.target.value);
                  setSeanceErrors((f) => ({ ...f, fin: '' }));
                }}
              />
              {seanceErrors.fin && <p className="pd-field-error">{seanceErrors.fin}</p>}
            </div>

            <div className="sc-actions">
              <button type="submit" className="parcours-add" disabled={seanceSaving}>
                {seanceSaving ? <Spinner size={16} light /> : null}
                Planifier
              </button>
              <button
                type="button"
                className="bene-action"
                onClick={() => {
                  setShowSeanceForm(false);
                  setSeanceErrors({ lecon: '', date: '', debut: '', fin: '' });
                }}
              >
                Annuler
              </button>
            </div>
          </form>
        )}

        {upcoming.length === 0 && !showSeanceForm ? (
          <div className="sc-empty">Aucune séance à venir pour ce parcours.</div>
        ) : (
          upcoming.length > 0 && (
            <>
              <p className="sc-subtitle">À venir</p>
              <ul className="sc-list">
                {upcoming.map((s) => (
                  <li key={s.id} className="sc-item">
                    <span className="sc-date">{formatSeanceDate(s.date)}</span>
                    <span className="sc-time">{hhmm(s.heure_debut)} – {hhmm(s.heure_fin)}</span>
                    <span className="sc-lecon">{s.lecon?.titre || 'Séance libre'}</span>
                    <button className="bene-action parcours-delete" onClick={() => handleDeleteSeance(s)}>
                      Supprimer
                    </button>
                  </li>
                ))}
              </ul>
            </>
          )
        )}

        {past.length > 0 && (
          <>
            <p className="sc-subtitle">Passées (5 dernières)</p>
            <ul className="sc-list">
              {past.map((s) => (
                <li key={s.id} className="sc-item sc-item-past">
                  <span className="sc-date">{formatSeanceDate(s.date)}</span>
                  <span className="sc-time">{hhmm(s.heure_debut)} – {hhmm(s.heure_fin)}</span>
                  <span className="sc-lecon">{s.lecon?.titre || 'Séance libre'}</span>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
      {confirmationDialog}
    </Layout>
  );
}