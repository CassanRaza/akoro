import { useEffect, useState } from 'react';
import './ThemeToggle.css';

const Moon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
  </svg>
);

const Sun = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
  </svg>
);

/**
 * variant "floating" : bouton rond fixé en haut à droite (pages de connexion)
 * variant "dock"     : bouton intégré au dock de l'interface admin
 * ignoreClick()      : renvoie true pour ignorer un clic (ex. juste après un déplacement du dock)
 */
export default function ThemeToggle({ variant = 'floating', ignoreClick }) {
  const [theme, setTheme] = useState(
    () => localStorage.getItem('akoro_theme') || 'light'
  );

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('akoro_theme', theme);
  }, [theme]);

  const toggle = () => {
    if (ignoreClick?.()) return;
    setTheme((t) => (t === 'light' ? 'dark' : 'light'));
  };

  return (
    <button
      type="button"
      className={variant === 'dock' ? 'dock-btn theme-toggle-dock' : 'theme-toggle'}
      onClick={toggle}
      aria-label="Basculer le mode sombre"
      title={theme === 'light' ? 'Activer le mode sombre' : 'Activer le mode clair'}
    >
      <span className="theme-toggle-icon">{theme === 'light' ? <Moon /> : <Sun />}</span>
    </button>
  );
}
