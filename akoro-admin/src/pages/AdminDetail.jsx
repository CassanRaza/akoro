import { useEffect, useState } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner, { PageLoader } from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { checkImage } from '../utils/validators';
import { getStoredUser, roleLabel } from '../utils/permissions';
import './Beneficiaires.css';
import './BeneficiaireDetail.css';
import './Administrateurs.css';

const formatDate = (value) => {
  if (!value) return '—';
  return new Date(value).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' });
};

export default function AdminDetail() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();
  const { id } = useParams();
  const navigate = useNavigate();
  const me = getStoredUser();

  const [a, setA] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [photoBusy, setPhotoBusy] = useState(false);
  const [photoError, setPhotoError] = useState('');

  const load = () => api.get(`/administrateurs/${id}`).then((res) => setA(res.data));

  useEffect(() => {
    load()
      .catch((err) => {
        if ([403, 404].includes(err.response?.status)) {
          navigate('/administrateurs', { replace: true });
        } else {
          setError(err.response?.data?.message || 'Erreur de chargement.');
        }
      })
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const isMe = me && a && me.id === a.id;
  const canEditPhoto = me && a && (isMe || me.role === 'admin_global');

  // Si c'est sa propre photo, la sidebar se met à jour aussitôt
  const notifySidebar = () => {
    if (isMe) window.dispatchEvent(new Event('akoro:user-updated'));
  };

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
      title: a.photo_url ? 'Remplacer la photo ?' : 'Ajouter cette photo ?',
      message: a.photo_url
        ? 'La photo de profil actuelle sera remplacée.'
        : 'Cette image sera ajoutée au profil de l’administrateur.',
      confirmLabel: a.photo_url ? 'Remplacer' : 'Ajouter',
      variant: 'info',
    }))) return;

    const formData = new FormData();
    formData.append('photo', file);

    setPhotoBusy(true);
    try {
      await api.post(`/administrateurs/${id}/photo`, formData);
      showToast(a.photo_url ? 'Photo remplacée avec succès.' : 'Photo ajoutée avec succès.');
      await load();
      notifySidebar();
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
      message: 'La photo de profil de cet administrateur sera supprimée.',
      confirmLabel: 'Retirer la photo',
      variant: 'danger',
    }))) return;
    setPhotoError('');
    setPhotoBusy(true);
    try {
      await api.delete(`/administrateurs/${id}/photo`);
      showToast('Photo supprimée avec succès.');
      await load();
      notifySidebar();
    } catch (err) {
      setPhotoError(err.response?.data?.message || 'Erreur lors de la suppression.');
    } finally {
      setPhotoBusy(false);
    }
  };

  if (loading) {
    return (
      <Layout>
        <PageLoader />
      </Layout>
    );
  }

  if (!a) {
    return (
      <Layout>
        <Link to="/administrateurs" className="bd-back">← Administrateurs</Link>
        <p style={{ color: 'var(--error-text)' }}>{error || 'Administrateur introuvable.'}</p>
      </Layout>
    );
  }

  return (
    <Layout>
      <Link to="/administrateurs" className="bd-back">← Administrateurs</Link>

      <div className="bd-card">
        <div className="bd-photo">
          <div className="bd-avatar-wrap">
            <Avatar key={a.photo_url || 'none'} name={a.name} url={a.photo_url} size={120} />
            {photoBusy && (
              <div className="bd-avatar-busy">
                <Spinner size={28} light />
              </div>
            )}
          </div>

          {canEditPhoto && (
            <>
              <label className="bene-action bd-photo-btn">
                {a.photo_url ? 'Changer la photo' : 'Ajouter une photo'}
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={handlePhoto}
                  disabled={photoBusy}
                />
              </label>

              {a.photo_url && (
                <button className="bene-action bd-danger" onClick={handlePhotoDelete} disabled={photoBusy}>
                  Retirer la photo
                </button>
              )}
            </>
          )}

          {photoError && <p className="bd-photo-error">{photoError}</p>}
        </div>

        <div className="bd-info">
          <h1 className="bd-name">{a.name}</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
            {isMe ? 'Mon profil' : "Fiche de l'administrateur"}
          </p>

          <div className="bd-grid">
            <div>
              <div className="bd-label">Rôle</div>
              <div className="bd-value">
                <span className="adm-role-badge">{roleLabel(a.role)}</span>
              </div>
            </div>
            <div>
              <div className="bd-label">Statut du compte</div>
              <div className="bd-value">
                <span className={`bene-badge ${a.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                  {a.actif ? 'Actif' : 'En attente'}
                </span>
              </div>
            </div>
            <div>
              <div className="bd-label">Email</div>
              <div className="bd-value">{a.email}</div>
            </div>
            <div>
              <div className="bd-label">Téléphone</div>
              <div className="bd-value">{a.telephone || '—'}</div>
            </div>
            <div>
              <div className="bd-label">Adresse</div>
              <div className="bd-value">{a.adresse || '—'}</div>
            </div>
            <div>
              <div className="bd-label">Inscrit le</div>
              <div className="bd-value">{formatDate(a.created_at)}</div>
            </div>
          </div>
        </div>
      </div>
      {confirmationDialog}
    </Layout>
  );
}