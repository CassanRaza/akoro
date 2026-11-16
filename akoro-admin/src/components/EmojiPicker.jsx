import { useEffect, useRef, useState } from 'react';
import { CATEGORIES_EMOJIS } from '../utils/emojis';
import './EmojiPicker.css';

// Panneau d'emojis à insérer dans un message (onglets par catégorie, fermeture par Échap ou clic extérieur)
export default function EmojiPicker({ onChoisir, onFermer }) {
  const [categorie, setCategorie] = useState(CATEGORIES_EMOJIS[0].id);
  const panneauRef = useRef(null);
  const active = CATEGORIES_EMOJIS.find((c) => c.id === categorie) || CATEGORIES_EMOJIS[0];

  useEffect(() => {
    const surClic = (e) => {
      if (panneauRef.current && !panneauRef.current.contains(e.target) && !e.target.closest('[data-emoji-toggle]')) {
        onFermer();
      }
    };
    const surTouche = (e) => e.key === 'Escape' && onFermer();
    document.addEventListener('mousedown', surClic);
    document.addEventListener('keydown', surTouche);
    return () => {
      document.removeEventListener('mousedown', surClic);
      document.removeEventListener('keydown', surTouche);
    };
  }, [onFermer]);

  return (
    <div className="emoji-picker" ref={panneauRef} role="dialog" aria-label="Choisir un emoji">
      <div className="emoji-picker-tabs" role="tablist">
        {CATEGORIES_EMOJIS.map((c) => (
          <button
            key={c.id}
            type="button"
            role="tab"
            aria-selected={c.id === categorie}
            title={c.label}
            className={'emoji-picker-tab' + (c.id === categorie ? ' is-active' : '')}
            onClick={() => setCategorie(c.id)}
          >
            {c.icone}
          </button>
        ))}
      </div>
      <div className="emoji-picker-label">{active.label}</div>
      <div className="emoji-picker-grid">
        {active.emojis.map((emoji) => (
          <button
            key={emoji}
            type="button"
            className="emoji-picker-item"
            // mousedown empêché : le champ de saisie garde le focus et la position du curseur
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => onChoisir(emoji)}
            aria-label={emoji}
          >
            {emoji}
          </button>
        ))}
      </div>
    </div>
  );
}
