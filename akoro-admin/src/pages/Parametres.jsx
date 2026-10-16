import { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import PasswordInput from '../components/PasswordInput';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { getStoredUser, roleLabel } from '../utils/permissions';
import { checkConfirm, checkPassword } from '../utils/validators';
import './Parametres.css';

export default function Parametres() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();
  const [user] = useState(getStoredUser());
  const [currentPassword, setCurrentPassword] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errors, setErrors] = useState({
    currentPassword: '',
    password: '',
    confirmPassword: '',
  });
  const [saving, setSaving] = useState(false);

  const clearError = (key) => setErrors((prev) => ({ ...prev, [key]: '' }));

  const handlePasswordChange = async (e) => {
    e.preventDefault();

    const nextErrors = {
      currentPassword: currentPassword ? '' : 'Votre mot de passe actuel est obligatoire.',
      password: checkPassword(password),
      confirmPassword: checkConfirm(password, confirmPassword),
    };

    setErrors(nextErrors);
    if (nextErrors.currentPassword || nextErrors.password || nextErrors.confirmPassword) return;

    if (!(await confirm({
      title: 'Changer le mot de passe ?',
      message: 'Votre mot de passe actuel sera remplacé par le nouveau mot de passe.',
      confirmLabel: 'Valider',
      variant: 'info',
    }))) return;

    setSaving(true);
    try {
      await api.put('/user/password', {
        current_password: currentPassword,
        password,
        password_confirmation: confirmPassword,
      });
      setCurrentPassword('');
      setPassword('');
      setConfirmPassword('');
      setErrors({ currentPassword: '', password: '', confirmPassword: '' });
      showToast('Mot de passe mis à jour avec succès.');
    } catch (err) {
      const serverErrors = err.response?.data?.errors || {};
      setErrors({
        currentPassword: serverErrors.current_password?.[0] || err.response?.data?.message || '',
        password: serverErrors.password?.[0] || '',
        confirmPassword: serverErrors.password?.[0] || '',
      });
    } finally {
      setSaving(false);
    }
  };

  if (!user) {
    return (
      <Layout>
        <div className="settings-empty">Chargement du profil…</div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="settings-header">
        <h1>Paramètres</h1>
        <p>Gérez votre compte et les actions utiles à votre accès.</p>
      </div>

      <div className="settings-grid">
        <section className="settings-card settings-profile">
          <div className="settings-profile-top">
            <Avatar key={user.photo_url || 'none'} name={user.name || ''} url={user.photo_url} size={64} />
            <div>
              <h2>{user.name || 'Utilisateur'}</h2>
              <span className="settings-role">{roleLabel(user.role)}</span>
            </div>
          </div>

          <div className="settings-info-grid">
            <div>
              <span className="settings-label">Email</span>
              <strong>{user.email || '—'}</strong>
            </div>
            <div>
              <span className="settings-label">Téléphone</span>
              <strong>{user.telephone || '—'}</strong>
            </div>
          </div>

          <div className="settings-actions">
            <Link to={`/administrateurs/${user.id}`} className="settings-link primary">
              Voir mon profil
            </Link>
            <Link to={`/administrateurs/${user.id}`} className="settings-link secondary">
              Gérer ma photo
            </Link>
          </div>
        </section>

        <section className="settings-card">
          <h2>Changer le mot de passe</h2>
          <form className="settings-form" onSubmit={handlePasswordChange} noValidate>
            <div className="settings-field">
              <label htmlFor="currentPassword">Mot de passe actuel</label>
              <PasswordInput
                value={currentPassword}
                onChange={(e) => {
                  setCurrentPassword(e.target.value);
                  clearError('currentPassword');
                }}
                autoComplete="current-password"
                placeholder="Mot de passe actuel"
                hasError={!!errors.currentPassword}
              />
              {errors.currentPassword && <span className="settings-error">{errors.currentPassword}</span>}
            </div>

            <div className="settings-field">
              <label htmlFor="newPassword">Nouveau mot de passe</label>
              <PasswordInput
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  clearError('password');
                }}
                autoComplete="new-password"
                placeholder="Nouveau mot de passe"
                hasError={!!errors.password}
              />
              {errors.password && <span className="settings-error">{errors.password}</span>}
            </div>

            <div className="settings-field">
              <label htmlFor="confirmPassword">Confirmer le mot de passe</label>
              <PasswordInput
                value={confirmPassword}
                onChange={(e) => {
                  setConfirmPassword(e.target.value);
                  clearError('confirmPassword');
                }}
                autoComplete="new-password"
                placeholder="Confirmer le mot de passe"
                hasError={!!errors.confirmPassword}
              />
              {errors.confirmPassword && <span className="settings-error">{errors.confirmPassword}</span>}
            </div>

            <button type="submit" className="settings-submit" disabled={saving}>
              {saving ? 'Enregistrement…' : 'Enregistrer le mot de passe'}
            </button>
          </form>
        </section>
      </div>

      {confirmationDialog}
    </Layout>
  );
}
