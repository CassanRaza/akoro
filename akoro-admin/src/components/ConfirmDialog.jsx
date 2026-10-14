import { createPortal } from 'react-dom';
import Modal from './Modal';
import './ConfirmDialog.css';

const ICONS = {
  danger: (
    <>
      <path d="M10.3 3.86 1.82 18.5A2 2 0 0 0 3.55 21.5h16.9a2 2 0 0 0 1.73-3L13.7 3.86a2 2 0 0 0-3.46 0Z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <circle cx="12" cy="17" r="0.6" fill="currentColor" stroke="none" />
    </>
  ),
  warning: (
    <>
      <path d="M10.3 3.86 1.82 18.5A2 2 0 0 0 3.55 21.5h16.9a2 2 0 0 0 1.73-3L13.7 3.86a2 2 0 0 0-3.46 0Z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <circle cx="12" cy="17" r="0.6" fill="currentColor" stroke="none" />
    </>
  ),
  info: (
    <>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="16" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12.01" y2="8" />
    </>
  ),
};

export default function ConfirmDialog({
  title = 'Confirmer cette action',
  message,
  confirmLabel = 'Confirmer',
  cancelLabel = 'Annuler',
  variant = 'warning',
  onConfirm,
  onCancel,
}) {
  return createPortal(
    <Modal open title={title} onClose={onCancel}>
      <div className={`confirm-dialog confirm-dialog-${variant}`}>
        <div className="confirm-dialog-icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
            strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            {ICONS[variant] || ICONS.warning}
          </svg>
        </div>
        <p className="confirm-dialog-message">{message}</p>
        <div className="confirm-dialog-actions">
          <button type="button" className="confirm-dialog-cancel" onClick={onCancel} autoFocus>
            {cancelLabel}
          </button>
          <button type="button" className="confirm-dialog-submit" onClick={onConfirm}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </Modal>,
    document.body
  );
}
