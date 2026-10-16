import { useEffect, useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import api from '../services/api';
import logo from '../assets/logo.jpg';
import Avatar from './Avatar';
import ThemeToggle from './ThemeToggle';
import useToast from './useToast';
import useConfirmation from './useConfirmation';
import { can, getStoredUser, roleLabel } from '../utils/permissions';
import './Layout.css';
import './LayoutUser.css';

// "allowed" : fonction qui dit si le rôle voit le lien (sans "allowed" = tous les admins)
const NAV_ITEMS = [
  { to: '/dashboard', label: 'Tableau de bord', icon: 'dashboard', allowed: can.dashboard },
  { to: '/beneficiaires', label: 'Bénéficiaires', icon: 'beneficiaries' },
  { to: '/parcours', label: 'Parcours & Leçons', icon: 'courses' },
  { to: '/absences', label: 'Absences', icon: 'absences' },
  { to: '/devoirs', label: 'Devoirs', icon: 'homework' },
  { to: '/administrateurs', label: 'Administrateurs', icon: 'administrators' },
  { to: '/parametres', label: 'Paramètres', icon: 'settings' },
];

function NavigationIcon({ name }) {
  const common = {
    width: 20,
    height: 20,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
  };

  switch (name) {
    case 'dashboard':
      return <svg {...common}><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></svg>;
    case 'beneficiaries':
      return <svg {...common}><circle cx="9" cy="8" r="3.5" /><path d="M3 20v-1a6 6 0 0 1 12 0v1" /><path d="M16 5.5a3.5 3.5 0 0 1 0 6.8M18 14a5 5 0 0 1 3 4.5V20" /></svg>;
    case 'courses':
      return <svg {...common}><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21z" /><path d="M4 5.5v13A2.5 2.5 0 0 1 6.5 16H20M8 7h8M8 10h8" /></svg>;
    case 'absences':
      return <svg {...common}><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M16 3v4M8 3v4M3 10h18M8 14h3M8 17h6" /></svg>;
    case 'homework':
      return <svg {...common}><path d="M8 4H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3" /><rect x="8" y="2" width="8" height="4" rx="1" /><path d="m8 13 2 2 5-5" /></svg>;
    case 'administrators':
      return <svg {...common}><circle cx="9" cy="8" r="3.5" /><path d="M3 20v-1a6 6 0 0 1 12 0v1M17 11h5M19.5 8.5v5" /></svg>;
    case 'settings':
      return <svg {...common}><circle cx="12" cy="12" r="3" /><path d="m19.4 15 .1.1a1.7 1.7 0 1 1-2.4 2.4l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a1.7 1.7 0 1 1-3.4 0v-.2a1.7 1.7 0 0 0-2.9-1.2l-.1.1a1.7 1.7 0 1 1-2.4-2.4l.1-.1a1.7 1.7 0 0 0-1.2-2.9H4a1.7 1.7 0 1 1 0-3.4h.2a1.7 1.7 0 0 0 1.2-2.9l-.1-.1a1.7 1.7 0 1 1 2.4-2.4l.1.1a1.7 1.7 0 0 0 2.9-1.2V2a1.7 1.7 0 1 1 3.4 0v.2a1.7 1.7 0 0 0 2.9 1.2l.1-.1a1.7 1.7 0 1 1 2.4 2.4l-.1.1a1.7 1.7 0 0 0 1.2 2.9h.2a1.7 1.7 0 1 1 0 3.4h-.2a1.7 1.7 0 0 0-1.2 2.9z" /></svg>;
    case 'logout':
      return <svg {...common}><path d="M10 17l5-5-5-5M15 12H3" /><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6" /></svg>;
    default:
      return null;
  }
}

export default function Layout({ children }) {
  const navigate = useNavigate();
  const showToast = useToast();
  const { confirm, confirmationDialog } = useConfirmation();
  const [user, setUser] = useState(getStoredUser);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(
    () => localStorage.getItem('akoro_sidebar_collapsed') === 'true'
  );
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false);

  useEffect(() => {
    if (!mobileSidebarOpen) return undefined;

    const closeOnEscape = (event) => {
      if (event.key === 'Escape') setMobileSidebarOpen(false);
    };

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [mobileSidebarOpen]);

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
    if (!(await confirm({
      title: 'Se déconnecter ?',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Se déconnecter',
      cancelLabel: 'Annuler',
      variant: 'warning',
    }))) return;

    try {
      await api.post('/logout');
    } catch {
      // on se déconnecte quand même côté interface
    }
    localStorage.removeItem('akoro_token');
    localStorage.removeItem('akoro_user');
    showToast('Déconnexion réussie.');
    navigate('/login');
  };

  const items = NAV_ITEMS.filter((item) => !item.allowed || item.allowed(user?.role));
  const toggleSidebar = () => {
    setSidebarCollapsed((collapsed) => {
      const nextCollapsed = !collapsed;
      localStorage.setItem('akoro_sidebar_collapsed', String(nextCollapsed));
      return nextCollapsed;
    });
  };

  return (
    <div className={`layout${sidebarCollapsed ? ' layout-sidebar-collapsed' : ''}`}>
      <ThemeToggle />
      <button
        type="button"
        className="mobile-sidebar-toggle"
        onClick={() => setMobileSidebarOpen((open) => !open)}
        aria-label={mobileSidebarOpen ? 'Fermer le menu' : 'Ouvrir le menu'}
        aria-expanded={mobileSidebarOpen}
        aria-controls="admin-sidebar"
      >
        <span />
        <span />
        <span />
      </button>

      {mobileSidebarOpen && (
        <button
          type="button"
          className="sidebar-backdrop"
          onClick={() => setMobileSidebarOpen(false)}
          aria-label="Fermer le menu"
        />
      )}

      <aside
        id="admin-sidebar"
        className={`sidebar${mobileSidebarOpen ? ' sidebar-mobile-open' : ''}`}
      >
        <div className="sidebar-brand">
          <img src={logo} alt="FabLab" className="sidebar-logo" />
          <div className="sidebar-brand-text">
            <div className="sidebar-brand-name">FabLab Admin</div>
            <div className="sidebar-brand-version">FabManager v1.2</div>
          </div>
          <button
            type="button"
            className="sidebar-collapse-toggle"
            onClick={toggleSidebar}
            aria-label={sidebarCollapsed ? 'Agrandir le menu' : 'Réduire le menu'}
            title={sidebarCollapsed ? 'Agrandir le menu' : 'Réduire le menu'}
          >
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              {sidebarCollapsed
                ? <><path d="M9 18l6-6-6-6" /><path d="M4 4v16" /></>
                : <><path d="M15 18l-6-6 6-6" /><path d="M20 4v16" /></>}
            </svg>
          </button>
        </div>

        <nav className="sidebar-nav">
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                'sidebar-link' + (isActive ? ' sidebar-link-active' : '')
              }
              onClick={() => setMobileSidebarOpen(false)}
              aria-label={item.label}
              title={item.label}
            >
              <NavigationIcon name={item.icon} />
              <span className="sidebar-link-label">{item.label}</span>
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

          <button className="sidebar-logout" onClick={handleLogout} title="Se déconnecter" aria-label="Se déconnecter">
            <NavigationIcon name="logout" />
            <span className="sidebar-logout-label">Se déconnecter</span>
          </button>
        </div>
      </aside>

      <main className="main-content">{children}</main>
      {confirmationDialog}
    </div>
  );
}