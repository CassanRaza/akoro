import { useState } from 'react';
import './Avatar.css';

export default function Avatar({ name = '', url = null, size = 36 }) {
  const [failed, setFailed] = useState(false);
  const style = { width: size, height: size, fontSize: Math.round(size * 0.42) };

  if (url && !failed) {
    return (
      <img
        src={url}
        alt={name}
        className="avatar avatar-img"
        style={style}
        onError={() => setFailed(true)}
      />
    );
  }

  return (
    <span className="avatar" style={style} aria-label={name}>
      {name.trim().charAt(0).toUpperCase() || '?'}
    </span>
  );
}