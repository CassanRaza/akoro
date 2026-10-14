import { useRef } from 'react';
import { Link } from 'react-router-dom';
import './ActionIcon.css';

const ICONS = {
  eye: (
    <>
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  power: (
    <>
      <path d="M18.4 6.6a8 8 0 1 1-12.8 0" />
      <line x1="12" y1="2" x2="12" y2="12" />
    </>
  ),
  plus: (
    <>
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </>
  ),
  trash: (
    <>
      <path d="M3 6h18" />
      <path d="M8 6V4h8v2" />
      <path d="m19 6-1 14H6L5 6" />
      <path d="M10 11v5M14 11v5" />
    </>
  ),
  edit: (
    <>
      <path d="m15 5 4 4" />
      <path d="M4 20h4l11-11a2.8 2.8 0 0 0-4-4L4 16v4Z" />
    </>
  ),
  role: (
    <>
      <circle cx="9" cy="8" r="3" />
      <path d="M3 20a6 6 0 0 1 12 0" />
      <path d="m17 11 1.3 1.3L21 9.5" />
    </>
  ),
  check: <path d="m5 12 4 4L19 6" />,
  x: <path d="m18 6-12 12M6 6l12 12" />,
  justify: (
    <>
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z" />
      <path d="M14 2v6h6M8 14l2.5 2.5L16 11" />
    </>
  ),
  cancel: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="m9 9 6 6m0-6-6 6" />
    </>
  ),
  upload: (
    <>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <path d="m17 8-5-5-5 5M12 3v12" />
    </>
  ),
};

function Icon({ name }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {ICONS[name]}
    </svg>
  );
}

export function ActionIconButton({ icon, label, className = '', ...props }) {
  return (
    <button
      type="button"
      className={`list-action ${className}`.trim()}
      aria-label={label}
      title={label}
      {...props}
    >
      <Icon name={icon} />
    </button>
  );
}

export function ActionIconFile({ icon, label, className = '', ...props }) {
  const inputRef = useRef(null);
  const disabled = Boolean(props.disabled);

  return (
    <>
      <button
        type="button"
        className={`list-action ${className}`.trim()}
        aria-label={label}
        title={label}
        disabled={disabled}
        onClick={() => inputRef.current?.click()}
      >
        <Icon name={icon} />
      </button>
      <input
        ref={inputRef}
        className="action-file-input"
        type="file"
        aria-label={label}
        {...props}
      />
    </>
  );
}

export function ActionIconLink({ icon, label, className = '', ...props }) {
  return (
    <Link
      className={`list-action ${className}`.trim()}
      aria-label={label}
      title={label}
      {...props}
    >
      <Icon name={icon} />
    </Link>
  );
}
