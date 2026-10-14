import { useEffect, useState } from 'react';
import './ThemeToggle.css';

export default function ThemeToggle() {
  const [theme, setTheme] = useState(
    () => localStorage.getItem('akoro_theme') || 'light'
  );

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('akoro_theme', theme);
  }, [theme]);

  const toggle = () => setTheme((t) => (t === 'light' ? 'dark' : 'light'));

  return (
    <button
      className="theme-toggle"
      onClick={toggle}
      aria-label="Basculer le mode sombre"
      title={theme === 'light' ? 'Activer le mode sombre' : 'Activer le mode clair'}
    >
      <span className="theme-toggle-icon">{theme === 'light' ? '🌙' : '☀️'}</span>
    </button>
  );
}