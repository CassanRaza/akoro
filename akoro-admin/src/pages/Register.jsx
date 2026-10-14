import { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import logo from '../assets/logo.jpg';
import ThemeToggle from '../components/ThemeToggle';
import PasswordInput from '../components/PasswordInput';
import PhotoPicker from '../components/PhotoPicker';
import Spinner from '../components/Spinner';
import {
  typeName, typeEmail, typePhone, typeAddress, typePassword,
  checkName, checkEmail, checkPhone, checkAddress, checkRole, checkPassword, checkConfirm,
} from '../utils/validators';
import { CHOIX_ROLES, ROLE_LABELS } from '../utils/permissions';
import './Login.css';
import './AuthExtra.css';

const EMPTY_ERRORS = {
  nom: '', email: '', telephone: '', adresse: '', role: '', photo: '', password: '', confirm: '',
};

export default function Register() {
  const [nom, setNom] = useState('');
  const [email, setEmail] = useState('');
  const [telephone, setTelephone] = useState('');
  const [adresse, setAdresse] = useState('');
  const [role, setRole] = useState('');
  const [photo, setPhoto] = useState(null);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [fieldErrors, setFieldErrors] = useState(EMPTY_ERRORS);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  const clearField = (name) => setFieldErrors((f) => ({ ...f, [name]: '' }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const errors = {
      nom: checkName(nom),
      email: checkEmail(email),
      telephone: checkPhone(telephone),
      adresse: checkAddress(adresse),
      role: checkRole(role),
      photo: fieldErrors.photo,
      password: checkPassword(password),
      confirm: checkConfirm(password, confirm),
    };
    setFieldErrors(errors);
    if (Object.values(errors).some(Boolean)) return;

    const formData = new FormData();
    formData.append('nom', nom.trim());
    formData.append('email', email);
    formData.append('telephone', telephone.trim());
    formData.append('adresse', adresse.trim());
    formData.append('role', role);
    formData.append('password', password);
    formData.append('password_confirmation', confirm);
    if (photo) formData.append('photo', photo);

    setLoading(true);

    try {
      const response = await api.post('/admin/register', formData);
      setSuccess(response.data.message);
    } catch (err) {
      if (err.response?.status === 429) {
        setError('Trop de tentatives. Réessayez dans une minute.');
      } else if (err.response?.data?.errors) {
        const serverErrors = err.response.data.errors;
        setFieldErrors({
          nom: serverErrors.nom?.[0] || '',
          email: serverErrors.email?.[0] || '',
          telephone: serverErrors.telephone?.[0] || '',
          adresse: serverErrors.adresse?.[0] || '',
          role: serverErrors.role?.[0] || '',
          photo: serverErrors.photo?.[0] || '',
          password: serverErrors.password?.[0] || '',
          confirm: '',
        });
      } else {
        setError(err.response?.data?.message || 'Inscription impossible. Vérifiez votre réseau.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <ThemeToggle />

      <div className="login-visual">
        <div className="login-visual-content">
          <img src={logo} alt="FabLab Solidaire Hay Tao" className="login-visual-logo" />
          <h1 className="login-visual-title">FabLab Admin</h1>
          <p className="login-visual-subtitle">
            Portail d'administration du FabLab Hay Tao Fianarantsoa
          </p>
        </div>
      </div>

      <div className="login-form-side">
        <div className="login-card">
          <div className="login-brand-mobile">
            <img src={logo} alt="FabLab" />
            <span>FabLab Admin</span>
          </div>

          <h2 className="login-heading">Inscription</h2>
          <p className="login-subheading">Créez votre compte administrateur</p>

          {success ? (
            <>
              <p className="login-success">{success}</p>
              <p className="login-switch">
                <Link to="/login">Retour à la connexion</Link>
              </p>
            </>
          ) : (
            <>
              <form onSubmit={handleSubmit} className="login-form" noValidate>
                <label className="login-label">Nom et prénoms</label>
                <input
                  type="text"
                  value={nom}
                  onChange={(e) => {
                    setNom(typeName(e.target.value));
                    clearField('nom');
                  }}
                  placeholder="Rasolofoniaina Hervé"
                  autoComplete="name"
                  maxLength={100}
                  className={'login-input' + (fieldErrors.nom ? ' login-input-error' : '')}
                />
                {fieldErrors.nom && <p className="login-field-error">{fieldErrors.nom}</p>}

                <label className="login-label">Adresse Email</label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => {
                    setEmail(typeEmail(e.target.value));
                    clearField('email');
                  }}
                  onBlur={() => email && setFieldErrors((f) => ({ ...f, email: checkEmail(email) }))}
                  placeholder="nom@haytao.mg"
                  autoComplete="email"
                  maxLength={255}
                  className={'login-input' + (fieldErrors.email ? ' login-input-error' : '')}
                />
                {fieldErrors.email && <p className="login-field-error">{fieldErrors.email}</p>}

                <label className="login-label">Téléphone</label>
                <input
                  type="tel"
                  value={telephone}
                  onChange={(e) => {
                    setTelephone(typePhone(e.target.value));
                    clearField('telephone');
                  }}
                  placeholder="+261 34 12 345 67"
                  autoComplete="tel"
                  maxLength={20}
                  className={'login-input' + (fieldErrors.telephone ? ' login-input-error' : '')}
                />
                {fieldErrors.telephone && <p className="login-field-error">{fieldErrors.telephone}</p>}

                <label className="login-label">Adresse</label>
                <input
                  type="text"
                  value={adresse}
                  onChange={(e) => {
                    setAdresse(typeAddress(e.target.value));
                    clearField('adresse');
                  }}
                  placeholder="Lot 12 Ambalakilonga, Fianarantsoa"
                  autoComplete="street-address"
                  maxLength={150}
                  className={'login-input' + (fieldErrors.adresse ? ' login-input-error' : '')}
                />
                {fieldErrors.adresse && <p className="login-field-error">{fieldErrors.adresse}</p>}

                <label className="login-label">Rôle souhaité</label>
                <select
                  value={role}
                  onChange={(e) => {
                    setRole(e.target.value);
                    clearField('role');
                  }}
                  className={'login-input' + (fieldErrors.role ? ' login-input-error' : '')}
                >
                  <option value="">Choisir un rôle</option>
                  {CHOIX_ROLES.map((r) => (
                    <option key={r} value={r}>{ROLE_LABELS[r]}</option>
                  ))}
                </select>
                {fieldErrors.role ? (
                  <p className="login-field-error">{fieldErrors.role}</p>
                ) : (
                  <p className="login-hint">Le Super Admin confirmera votre rôle lors de la validation.</p>
                )}

                <PhotoPicker
                  name={nom}
                  file={photo}
                  onChange={setPhoto}
                  error={fieldErrors.photo}
                  onError={(message) => setFieldErrors((f) => ({ ...f, photo: message }))}
                />

                <label className="login-label">Mot de passe</label>
                <PasswordInput
                  value={password}
                  onChange={(e) => {
                    setPassword(typePassword(e.target.value));
                    clearField('password');
                  }}
                  autoComplete="new-password"
                  hasError={!!fieldErrors.password}
                />
                {fieldErrors.password ? (
                  <p className="login-field-error">{fieldErrors.password}</p>
                ) : (
                  <p className="login-hint">8 caractères minimum, avec une lettre et un chiffre, sans espace</p>
                )}

                <label className="login-label">Confirmer le mot de passe</label>
                <PasswordInput
                  value={confirm}
                  onChange={(e) => {
                    setConfirm(typePassword(e.target.value));
                    clearField('confirm');
                  }}
                  autoComplete="new-password"
                  hasError={!!fieldErrors.confirm}
                />
                {fieldErrors.confirm && <p className="login-field-error">{fieldErrors.confirm}</p>}

                {error && <p className="login-error">{error}</p>}

                <button type="submit" className="login-button" disabled={loading}>
                  {loading ? (
                    <>
                      <Spinner size={18} light /> Envoi
                    </>
                  ) : (
                    "S'inscrire"
                  )}
                </button>
              </form>

              <p className="login-switch">
                Déjà un compte ?<Link to="/login">Se connecter</Link>
              </p>
            </>
          )}

          <p className="login-footer">FabManager v1.2</p>
        </div>
      </div>
    </div>
  );
}