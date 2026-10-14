import { useEffect, useState } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import StatutAbsence from '../components/StatutAbsence';
import Spinner, { PageLoader } from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import './Beneficiaires.css';
import './BeneficiaireDetail.css';

const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Photo : type et taille
const checkImage = (file, maxMo = 2) => {
  if (!file) return 'Veuillez choisir une image.';
  if (!IMAGE_TYPES.includes(file.type)) return 'Formats acceptés : JPG, PNG ou WEBP.';
  if (file.size > maxMo * 1024 * 1024) return `La photo est trop volumineuse (${maxMo} Mo maximum).`;
  return '';
};

const formatDate = (value) => {
  if (!value) return '—';
  const date = new Date(value.length === 10 ? `${value}T00:00:00` : value);
  return date.toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' });
};

const hhmm = (time) => (time ? time.slice(0, 5) : '—');

// Durée de présence entre l'arrivée et le départ (ex. 8h53)
const duree = (arrivee, depart) => {
  if (!arrivee || !depart) return '—';
  const [h1, m1] = arrivee.split(':').map(Number);
  const [h2, m2] = depart.split(':').map(Number);
  const minutes = h2 * 60 + m2 - (h1 * 60 + m1);
  if (minutes <= 0) return '—';
  return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`;
};

const MODES = { biometrique: 'Empreinte digitale', manuel: 'Saisie manuelle' };

export default function BeneficiaireDetail() {
  const { confirm, confirmationDialog } = useConfirmation();
  const { id } = useParams();
  const navigate = useNavigate();

  const [b, setB] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('absences');
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState('');
  const [toggling, setToggling] = useState(false);

  const load = () => api.get(`/beneficiaires/${id}`).then((res) => setB(res.data));

  useEffect(() => {
    load()
      .catch((err) => {
        if ([403, 404].includes(err.response?.status)) {
          navigate('/beneficiaires', { replace: true });
        } else {
          setError(err.response?.data?.message || 'Erreur de chargement.');
        }
      })
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  // ---------- Photo ----------
  const handlePhoto = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // permet de re-choisir le même fichier
    setPhotoError('');

    const message = checkImage(file);
    if (message) {
      setPhotoError(message);
      return;
    }

    if (!(await confirm({
      title: b.photo_url ? 'Remplacer la photo ?' : 'Ajouter cette photo ?',
      message: b.photo_url
        ? 'La photo de profil actuelle sera remplacée.'
        : 'Cette image sera ajoutée au profil du bénéficiaire.',
      confirmLabel: b.photo_url ? 'Remplacer' : 'Ajouter',
      variant: 'info',
    }))) return;

    const formData = new FormData();
    formData.append('photo', file);

    setPhotoBusy(true);
    try {
      await api.post(`/beneficiaires/${id}/photo`, formData);
      await load();
    } catch (err) {
      setPhotoError(
        err.response?.data?.errors?.photo?.[0] || err.response?.data?.message || "Échec de l'envoi de la photo."
      );
    } finally {
      setPhotoBusy(false);
    }
  };

  const handlePhotoDelete = async () => {
    if (!(await confirm({
      title: 'Retirer cette photo ?',
      message: 'La photo de profil de ce bénéficiaire sera supprimée.',
      confirmLabel: 'Retirer la photo',
      variant: 'danger',
    }))) return;
    setPhotoError('');
    setPhotoBusy(true);
    try {
      await api.delete(`/beneficiaires/${id}/photo`);
      await load();
    } catch (err) {
      setPhotoError(err.response?.data?.message || 'Erreur lors de la suppression.');
    } finally {
      setPhotoBusy(false);
    }
  };

  // ---------- Statut du compte ----------
  const toggleActif = async () => {
    const next = !b.actif;
    const action = next ? 'Activer' : 'Désactiver';
    if (!(await confirm({
      title: `Confirmer : ${action.toLowerCase()} le compte ?`,
      message: next
        ? `Le compte de ${b.name} sera activé.`
        : `${b.name} sera déconnecté de l'application.`,
      confirmLabel: action,
      variant: next ? 'info' : 'warning',
    }))) return;

    setError('');
    setToggling(true);
    try {
      await api.put(`/beneficiaires/${id}`, { actif: next });
      await load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la mise à jour.');
    } finally {
      setToggling(false);
    }
  };

  if (loading) {
    return (
      <Layout>
        <PageLoader />
      </Layout>
    );
  }

  if (!b) {
    return (
      <Layout>
        <Link to="/beneficiaires" className="bd-back">← Bénéficiaires</Link>
        <p style={{ color: 'var(--error-text)' }}>{error || 'Bénéficiaire introuvable.'}</p>
      </Layout>
    );
  }

  const absences = b.absences || [];
  const presences = b.presences || [];
  const nonJustifiees = absences.filter((a) => a.statut === 'non_justifiee').length;
  const aValider = absences.filter((a) => a.statut === 'a_valider').length;

  return (
    <Layout>
      <Link to="/beneficiaires" className="bd-back">← Bénéficiaires</Link>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="bd-card">
        <div className="bd-photo">
          <div className="bd-avatar-wrap">
            <Avatar key={b.photo_url || 'none'} name={b.name} url={b.photo_url} size={120} />
            {photoBusy && (
              <div className="bd-avatar-busy">
                <Spinner size={28} light />
              </div>
            )}
          </div>

          <label className="bene-action bd-photo-btn">
            {b.photo_url ? 'Changer la photo' : 'Ajouter une photo'}
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              onChange={handlePhoto}
              disabled={photoBusy}
            />
          </label>

          {b.photo_url && (
            <button className="bene-action bd-danger" onClick={handlePhotoDelete} disabled={photoBusy}>
              Retirer la photo
            </button>
          )}

          {photoError && <p className="bd-photo-error">{photoError}</p>}
        </div>

        <div className="bd-info">
          <h1 className="bd-name">{b.name}</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
            Fiche de suivi détaillée du bénéficiaire
          </p>

          <div className="bd-grid">
            <div>
              <div className="bd-label">Email</div>
              <div className="bd-value">{b.email}</div>
            </div>
            <div>
              <div className="bd-label">Parcours assigné</div>
              <div className="bd-value">{b.parcours?.nom || '—'}</div>
            </div>
            <div>
              <div className="bd-label">Date d'inscription</div>
              <div className="bd-value">{formatDate(b.created_at)}</div>
            </div>
            <div>
              <div className="bd-label">Statut du compte</div>
              <div className="bd-value">
                <span className={`bene-badge ${b.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                  {b.actif ? 'Actif' : 'Inactif'}
                </span>
              </div>
            </div>
          </div>

          <div className="bd-actions">
            <button className="bene-action" onClick={toggleActif} disabled={toggling}>
              {toggling ? <Spinner size={14} /> : null}
              {b.actif ? 'Désactiver le compte' : 'Activer le compte'}
            </button>
          </div>
        </div>
      </div>

      <div className="bd-tabs">
        <button
          className={'bd-tab' + (tab === 'absences' ? ' bd-tab-active' : '')}
          onClick={() => setTab('absences')}
        >
          Historique des absences ({absences.length})
        </button>
        <button
          className={'bd-tab' + (tab === 'presences' ? ' bd-tab-active' : '')}
          onClick={() => setTab('presences')}
        >
          Présences ({presences.length})
        </button>
        <button
          className={'bd-tab' + (tab === 'progression' ? ' bd-tab-active' : '')}
          onClick={() => setTab('progression')}
        >
          Progression du parcours
        </button>
      </div>

      {tab === 'absences' && (
        absences.length === 0 ? (
          <div className="bd-empty">Aucune absence enregistrée pour ce bénéficiaire.</div>
        ) : (
          <>
            <div className="bd-summary">
              <div className="bd-stat">
                <div className="bd-stat-value">{absences.length}</div>
                <div className="bd-stat-label">Absences au total</div>
              </div>
              <div className="bd-stat">
                <div className="bd-stat-value">{nonJustifiees}</div>
                <div className="bd-stat-label">Non justifiées</div>
              </div>
              <div className="bd-stat">
                <div className="bd-stat-value">{aValider}</div>
                <div className="bd-stat-label">Justificatifs à valider</div>
              </div>
            </div>

            <div className="bene-table-wrap">
              <table className="bene-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Leçon</th>
                    <th>Motif de l'absence</th>
                    <th>Justification</th>
                  </tr>
                </thead>
                <tbody>
                  {absences.map((a) => (
                    <tr key={a.id}>
                      <td>{formatDate(a.date)}</td>
                      <td>
                        {a.lecon?.titre || 'Séance libre'}
                        {a.seance && (
                          <span style={{ display: 'block', color: 'var(--text-muted)', fontSize: 12 }}>
                            {hhmm(a.seance.heure_debut)} – {hhmm(a.seance.heure_fin)}
                          </span>
                        )}
                      </td>
                      <td>{a.motif || 'Pas de motif fourni'}</td>
                      <td><StatutAbsence statut={a.statut} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )
      )}

      {tab === 'presences' && (
        presences.length === 0 ? (
          <div className="bd-empty">
            Aucun pointage enregistré. Les présences arrivent depuis l'application mobile.
          </div>
        ) : (
          <div className="bene-table-wrap" style={{ marginTop: 20 }}>
            <table className="bene-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Arrivée</th>
                  <th>Départ</th>
                  <th>Durée</th>
                  <th>Mode</th>
                </tr>
              </thead>
              <tbody>
                {presences.map((p) => (
                  <tr key={p.id}>
                    <td>{formatDate(p.date)}</td>
                    <td>{hhmm(p.heure_arrivee)}</td>
                    <td>{hhmm(p.heure_depart)}</td>
                    <td>{duree(p.heure_arrivee, p.heure_depart)}</td>
                    <td>{MODES[p.mode] || p.mode}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      )}

      {tab === 'progression' && (
        <div className="bd-empty">
          La progression sera calculée à partir des leçons suivies et des quiz réussis dans
          l'application mobile.
        </div>
      )}
      {confirmationDialog}
    </Layout>
  );
}