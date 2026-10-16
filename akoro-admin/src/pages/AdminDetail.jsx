import { useEffect, useState } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner, { PageLoader } from '../components/Spinner';
import { ActionIconButton } from '../components/ActionIcon';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import {
  checkAddress, checkEmail, checkImage, checkName, checkPhone,
  typeAddress, typeEmail, typeName, typePhone,
} from '../utils/validators';
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
  const [editingProfile, setEditingProfile] = useState(false);
  const [profileForm, setProfileForm] = useState({ name: '', email: '', telephone: '', adresse: '' });
  const [profileErrors, setProfileErrors] = useState({ name: '', email: '', telephone: '', adresse: '' });
  const [profileSaving, setProfileSaving] = useState(false);

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

  const startProfileEdit = () => {
    setProfileForm({
      name: a.name || '',
      email: a.email || '',
      telephone: a.telephone || '',
      adresse: a.adresse || '',
    });
    setProfileErrors({ name: '', email: '', telephone: '', adresse: '' });
    setEditingProfile(true);
  };

  const cancelProfileEdit = () => {
    setEditingProfile(false);
    setProfileErrors({ name: '', email: '', telephone: '', adresse: '' });
  };

  const handleProfileChange = (field, value) => {
    setProfileForm((prev) => ({ ...prev, [field]: value }));
    setProfileErrors((prev) => ({ ...prev, [field]: '' }));
  };

  const handleProfileSave = async (e) => {
    e.preventDefault();
    const errors = {
      name: checkName(profileForm.name),
      email: checkEmail(profileForm.email),
      telephone: checkPhone(profileForm.telephone),
      adresse: checkAddress(profileForm.adresse),
    };
    setProfileErrors(errors);
    if (Object.values(errors).some(Boolean)) return;

    setError('');
    setProfileSaving(true);
    try {
      const { data } = await api.put('/user/profile', {
        name: profileForm.name.trim(),
        email: profileForm.email.trim(),
        telephone: profileForm.telephone.trim(),
        adresse: profileForm.adresse.trim(),
      });
      setA(data);
      localStorage.setItem('akoro_user', JSON.stringify(data));
      window.dispatchEvent(new Event('akoro:user-updated'));
      setEditingProfile(false);
      showToast('Informations personnelles mises à jour.');
    } catch (err) {
      const serverErrors = err.response?.data?.errors || {};
      setProfileErrors({
        name: serverErrors.nom?.[0] || serverErrors.name?.[0] || '',
        email: serverErrors.email?.[0] || '',
        telephone: serverErrors.telephone?.[0] || '',
        adresse: serverErrors.adresse?.[0] || '',
      });
      if (!Object.values(serverErrors).length) {
        setError(err.response?.data?.message || 'Erreur lors de la mise à jour du profil.');
      } else if (err.response?.data?.message) {
        setError(err.response.data.message);
      }
    } finally {
      setProfileSaving(false);
    }
  };

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

      {error && <p className="adm-error">{error}</p>}

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
          <div className="admin-profile-heading">
            <div>
              <h1 className="bd-name">{a.name}</h1>
              <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
                {isMe ? 'Mon profil' : "Fiche de l'administrateur"}
              </p>
            </div>
            {isMe && !editingProfile && (
              <ActionIconButton
                icon="edit"
                label="Modifier mes informations"
                className="bene-action"
                onClick={startProfileEdit}
              />
            )}
          </div>

          {editingProfile ? (
            <form className="admin-profile-form" onSubmit={handleProfileSave} noValidate>
              {[
                { field: 'name', label: 'Nom complet', type: 'text', formatter: typeName },
                { field: 'email', label: 'Email', type: 'email', formatter: typeEmail },
                { field: 'telephone', label: 'Téléphone', type: 'tel', formatter: typePhone },
                { field: 'adresse', label: 'Adresse', type: 'text', formatter: typeAddress },
              ].map(({ field, label, type, formatter }) => (
                <div className="admin-profile-field" key={field}>
                  <label className="bd-label" htmlFor={`profile-${field}`}>{label}</label>
                  <input
                    id={`profile-${field}`}
                    className={`bene-search${profileErrors[field] ? ' admin-profile-input-error' : ''}`}
                    type={type}
                    value={profileForm[field]}
                    onChange={(event) => handleProfileChange(field, formatter(event.target.value))}
                    maxLength={field === 'email' ? 255 : field === 'adresse' ? 150 : field === 'telephone' ? 20 : 100}
                    autoComplete={field === 'email' ? 'email' : field === 'telephone' ? 'tel' : field === 'adresse' ? 'street-address' : 'name'}
                    disabled={profileSaving}
                  />
                  {profileErrors[field] && <span className="admin-profile-error">{profileErrors[field]}</span>}
                </div>
              ))}
              <div className="bd-grid admin-profile-account-info">
                <div>
                  <div className="bd-label">Rôle</div>
                  <div className="bd-value"><span className="adm-role-badge">{roleLabel(a.role)}</span></div>
                </div>
                <div>
                  <div className="bd-label">Statut du compte</div>
                  <div className="bd-value">
                    <span className={`bene-badge ${a.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                      {a.actif ? 'Actif' : 'En attente'}
                    </span>
                  </div>
                </div>
              </div>
              <div className="admin-profile-actions">
                <ActionIconButton
                  icon="check"
                  label={profileSaving ? 'Enregistrement en cours' : 'Enregistrer les informations'}
                  className="bene-action admin-profile-save"
                  type="submit"
                  disabled={profileSaving}
                />
                <ActionIconButton
                  icon="x"
                  label="Annuler la modification"
                  className="bene-action"
                  onClick={cancelProfileEdit}
                  disabled={profileSaving}
                />
              </div>
            </form>
          ) : (
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
          )}
        </div>
      </div>
      {confirmationDialog}
    </Layout>
  );
}