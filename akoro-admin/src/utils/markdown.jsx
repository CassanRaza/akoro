import './markdown.css';

// Mini rendu Markdown pour les réponses de FAB'IA : **gras**, _italique_, listes à puces.
// Construit des éléments React (jamais de HTML injecté) : aucun risque XSS.

function inline(texte, cle) {
  const morceaux = texte.split(/(\*\*[^*]+\*\*|_[^_]+_)/g).filter(Boolean);
  return morceaux.map((m, i) => {
    if (m.startsWith('**') && m.endsWith('**')) return <strong key={`${cle}-${i}`}>{m.slice(2, -2)}</strong>;
    if (m.length > 2 && m.startsWith('_') && m.endsWith('_')) return <em key={`${cle}-${i}`}>{m.slice(1, -1)}</em>;
    return m;
  });
}

const PUCE = /^\s*(?:[-*•]|\d+[.)])\s+/;

export default function Markdown({ texte = '', className = '' }) {
  const blocs = [];
  let liste = null;

  texte.split('\n').forEach((ligne, i) => {
    if (PUCE.test(ligne)) {
      if (!liste) {
        liste = [];
        blocs.push({ type: 'ul', items: liste, key: i });
      }
      liste.push({ texte: ligne.replace(PUCE, ''), key: i });
      return;
    }
    liste = null;
    if (ligne.trim() === '') return;
    // « ### Titre » ou « Points clés : » seuls sur une ligne → intertitre en gras
    const titre = ligne.replace(/^#+\s*/, '');
    blocs.push({ type: /^#+\s/.test(ligne) ? 'h' : 'p', texte: titre, key: i });
  });

  return (
    <div className={`md ${className}`}>
      {blocs.map((b) => {
        if (b.type === 'ul') {
          return (
            <ul key={b.key}>
              {b.items.map((it) => <li key={it.key}>{inline(it.texte, it.key)}</li>)}
            </ul>
          );
        }
        if (b.type === 'h') return <p key={b.key}><strong>{b.texte}</strong></p>;
        return <p key={b.key}>{inline(b.texte, b.key)}</p>;
      })}
    </div>
  );
}
