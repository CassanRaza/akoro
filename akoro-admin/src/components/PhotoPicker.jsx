import { useEffect, useState } from 'react';
import Avatar from './Avatar';
import { checkImage } from '../utils/validators';
import './PhotoPicker.css';

export default function PhotoPicker({
  name = '',
  file,
  onChange,
  error,
  onError,
  label = 'Photo de profil (facultative)',
}) {
  const [preview, setPreview] = useState(null);

  // Aperçu de l'image choisie
  useEffect(() => {
    if (!file) {
      setPreview(null);
      return undefined;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const handleChange = (e) => {
    const chosen = e.target.files?.[0];
    e.target.value = ''; // permet de re-choisir le même fichier
    if (!chosen) return;

    const message = checkImage(chosen);
    if (message) {
      onChange(null);
      onError(message);
      return;
    }

    onError('');
    onChange(chosen);
  };

  return (
    <div className="photo-picker">
      <span className="photo-picker-label">{label}</span>

      <div className="photo-picker-row">
        <Avatar key={preview || 'none'} name={name} url={preview} size={72} />

        <div className="photo-picker-actions">
          <label className="photo-picker-btn">
            {file ? 'Changer la photo' : 'Choisir une photo'}
            <input type="file" accept="image/jpeg,image/png,image/webp" onChange={handleChange} />
          </label>

          {file && (
            <button
              type="button"
              className="photo-picker-btn photo-picker-remove"
              onClick={() => {
                onChange(null);
                onError('');
              }}
            >
              Retirer
            </button>
          )}

          <span className="photo-picker-hint">JPG, PNG ou WEBP — 2 Mo maximum</span>
        </div>
      </div>

      {error && <p className="photo-picker-error">{error}</p>}
    </div>
  );
}