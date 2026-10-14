import { useCallback, useEffect, useState } from 'react';
import { ToastContext } from './useToast';
import './ToastProvider.css';

const TOAST_DURATION = 3200;

export function ToastProvider({ children }) {
  const [toast, setToast] = useState(null);

  const showToast = useCallback((message, type = 'success') => {
    setToast({ message, type, id: Date.now() + Math.random() });
  }, []);

  useEffect(() => {
    if (!toast) return undefined;
    const timer = window.setTimeout(() => {
      if (toast.exiting) {
        setToast(null);
      } else {
        setToast((current) => (
          current?.id === toast.id ? { ...current, exiting: true } : current
        ));
      }
    }, toast.exiting ? 240 : TOAST_DURATION);
    return () => window.clearTimeout(timer);
  }, [toast]);

  return (
    <ToastContext.Provider value={showToast}>
      {children}
      {toast && (
        <div
          key={toast.id}
          className={`app-toast app-toast-${toast.type}${toast.exiting ? ' app-toast-exiting' : ''}`}
          role="status"
          aria-live="polite"
          style={{ '--toast-duration': `${TOAST_DURATION}ms` }}
        >
          <span className="app-toast-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
              strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="m5 12 4 4L19 6" />
            </svg>
          </span>
          <span className="app-toast-message">{toast.message}</span>
          <span className="app-toast-progress" aria-hidden="true" />
        </div>
      )}
    </ToastContext.Provider>
  );
}
