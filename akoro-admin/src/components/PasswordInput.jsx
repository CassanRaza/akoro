import { useState } from 'react';
import './PasswordInput.css';

const EyeIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

const EyeOffIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M17.94 17.94A10.94 10.94 0 0 1 12 19c-7 0-11-7-11-7a19.77 19.77 0 0 1 5.06-5.94" />
    <path d="M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 7 11 7a19.86 19.86 0 0 1-3.17 4.19" />
    <path d="M14.12 14.12A3 3 0 1 1 9.88 9.88" />
    <line x1="1" y1="1" x2="23" y2="23" />
  </svg>
);

export default function PasswordInput({
  value,
  onChange,
  onBlur,
  placeholder = '••••••••••••',
  autoComplete = 'current-password',
  maxLength = 64,
  hasError = false,
}) {
  const [visible, setVisible] = useState(false);

  return (
    <div className="pwd-wrap">
      <input
        type={visible ? 'text' : 'password'}
        value={value}
        onChange={onChange}
        onBlur={onBlur}
        placeholder={placeholder}
        autoComplete={autoComplete}
        maxLength={maxLength}
        className={'login-input pwd-input' + (hasError ? ' login-input-error' : '')}
      />
      <button
        type="button"
        className="pwd-toggle"
        onClick={() => setVisible((v) => !v)}
        aria-label={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
        title={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
      >
        {visible ? <EyeOffIcon /> : <EyeIcon />}
      </button>
    </div>
  );
}