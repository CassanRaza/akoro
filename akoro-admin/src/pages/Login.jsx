import { useState, useRef } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../services/api';
import logo from '../assets/logo.jpg';
import ThemeToggle from '../components/ThemeToggle';
import PasswordInput from '../components/PasswordInput';
import Spinner from '../components/Spinner';
import { typeEmail, typePassword, checkEmail } from '../utils/validators';
import { can, homePath } from '../utils/permissions';
import './Login.css';
import './AuthExtra.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const visualRef = useRef(null);

  const handleMouseMove = (e) => {
    const el = visualRef.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    el.style.setProperty('--tx', `${x * 18}px`);
    el.style.setProperty('--ty', `${y * 18}px`);
  };

  const handleMouseLeave = () => {
    const el = visualRef.current;
    if (!el) return;
    el.style.setProperty('--tx', '0px');
    el.style.setProperty('--ty', '0px');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const errors = {
      email: checkEmail(email),
      password: password ? '' : 'Le mot de passe est obligatoire.',
    };
    setFieldErrors(errors);
    if (errors.email || errors.password) return;

    setLoading(true);

    try {
      const response = await api.post('/login', { email, password });
      const { user, token } = response.data;

      if (!can.isAdmin(user.role)) {
        setError('Accès réservé aux administrateurs.');
        setLoading(false);
        return;
      }

      localStorage.setItem('akoro_token', token);
      localStorage.setItem('akoro_user', JSON.stringify(user));
      navigate(homePath(user.role));
    } catch (err) {
      if (err.response?.status === 429) {
        setError('Trop de tentatives. Réessayez dans une minute.');
      } else {
        const errors = err.response?.data?.errors;
        const firstError = errors ? Object.values(errors)[0][0] : null;
        setError(firstError || err.response?.data?.message || 'Connexion impossible. Vérifiez votre réseau.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <ThemeToggle />

      <div
        className="login-visual"
        ref={visualRef}
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
      >
        <div
          className="login-visual-content"
          style={{ transform: 'translate(var(--tx, 0px), var(--ty, 0px))' }}
        >
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

          <h2 className="login-heading">Connexion</h2>
          <p className="login-subheading">Accédez à votre espace administrateur</p>

          <form onSubmit={handleSubmit} className="login-form" noValidate>
            <label className="login-label">Adresse Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(typeEmail(e.target.value));
                setFieldErrors((f) => ({ ...f, email: '' }));
              }}
              onBlur={() => email && setFieldErrors((f) => ({ ...f, email: checkEmail(email) }))}
              placeholder="nom@haytao.mg"
              autoComplete="email"
              maxLength={255}
              className={'login-input' + (fieldErrors.email ? ' login-input-error' : '')}
            />
            {fieldErrors.email && <p className="login-field-error">{fieldErrors.email}</p>}

            <label className="login-label">Mot de passe</label>
            <PasswordInput
              value={password}
              onChange={(e) => {
                setPassword(typePassword(e.target.value));
                setFieldErrors((f) => ({ ...f, password: '' }));
              }}
              hasError={!!fieldErrors.password}
            />
            {fieldErrors.password && <p className="login-field-error">{fieldErrors.password}</p>}

            {error && <p className="login-error">{error}</p>}

            <button type="submit" className="login-button" disabled={loading}>
              {loading ? (
                <>
                  <Spinner size={18} light /> Connexion
                </>
              ) : (
                'Se connecter'
              )}
            </button>
          </form>

          <p className="login-switch">
            Nouvel administrateur ?<Link to="/register">S'inscrire</Link>
          </p>

          <p className="login-footer">FabManager v1.2</p>
        </div>
      </div>
    </div>
  );
}