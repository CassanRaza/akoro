import { useEffect, useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import api from '../services/api';
import logo from '../assets/logo.jpg';
import Avatar from './Avatar';
import ThemeToggle from './ThemeToggle';
import { can, getStoredUser, roleLabel } from '../utils/permissions';
import './Layout.css';
import './LayoutUser.css';

// "allowed" : fonction qui dit si le rôle voit le lien (sans "allowed" = tous les admins)
const NAV_ITEMS = [
  { to: '/dashboard', label: 'Tableau de bord', allowed: can.dashboard },
  { to: '/beneficiaires', label: 'Bénéficiaires' },
  { to: '/parcours', label: 'Parcours & Leçons' },
  { to: '/absences', label: 'Absences' },
  { to: '/devoirs', label: 'Devoirs' },
  { to: '/administrateurs', label: 'Administrateurs' },
  { to: '/parametres', label: 'Paramètres' },
];

export default function Layout({ children }) {
  const navigate = useNavigate();
  const [user, setUser] = useState(getStoredUser);

  // Rafraîchit le profil (rôle, photo) : le lien de la photo expire au bout d'1 h
  useEffect(() => {
    const refresh = () =>
      api.get('/user')
        .then((res) => {
          localStorage.setItem('akoro_user', JSON.stringify(res.data));
          setUser(res.data);
        })
        .catch(() => {});

    refresh();
    window.addEventListener('akoro:user-updated', refresh);
    return () => window.removeEventListener('akoro:user-updated', refresh);
  }, []);

  const handleLogout = async () => {
    try {
      await api.post('/logout');
    } catch {
      // on se déconnecte quand même côté interface
    }
    localStorage.removeItem('akoro_token');
    localStorage.removeItem('akoro_user');
    navigate('/login');
  };

  const items = NAV_ITEMS.filter((item) => !item.allowed || item.allowed(user?.role));

  return (
    <div className="layout">
      <ThemeToggle />

      <aside className="sidebar">
        <div className="sidebar-brand">
          <img src={logo} alt="FabLab" className="sidebar-logo" />
          <div>
            <div className="sidebar-brand-name">FabLab Admin</div>
            <div className="sidebar-brand-version">FabManager v1.2</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                'sidebar-link' + (isActive ? ' sidebar-link-active' : '')
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-apk">
            <span className="sidebar-apk-dot" />
            Compagnon APK<br />
            <span className="sidebar-apk-version">Connecté • v1.0.8</span>
          </div>

          <Link
            to={`/administrateurs/${user?.id}`}
            className="sidebar-user sidebar-user-link"
            title="Voir mon profil"
          >
            <Avatar
              key={user?.photo_url || 'none'}
              name={user?.name || ''}
              url={user?.photo_url}
              size={36}
            />
            <div className="sidebar-user-text">
              <div className="sidebar-user-name">{user?.name || 'Utilisateur'}</div>
              <div className="sidebar-user-role">{roleLabel(user?.role)}</div>
            </div>
          </Link>

          <button className="sidebar-logout" onClick={handleLogout}>
            Se déconnecter
          </button>
        </div>
      </aside>

      <main className="main-content">{children}</main>
    </div>
  );
}