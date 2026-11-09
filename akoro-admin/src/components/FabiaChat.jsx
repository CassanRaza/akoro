import { useEffect, useRef, useState } from 'react';
import api from '../services/api';
import Spinner from './Spinner';
import useToast from './useToast';
import Markdown from '../utils/markdown';
import { getStoredUser } from '../utils/permissions';
import './FabiaChat.css';

const heure = (v) => (v ? new Date(v).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '');

export function Spark({ size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z" />
      <path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z" />
    </svg>
  );
}

// Conversation avec FAB'IA : historique, suggestions, saisie (panneau de Discussion et page de gestion)
export default function FabiaChat({ autoFocus = false }) {
  const showToast = useToast();
  const [user] = useState(getStoredUser);
  const [echanges, setEchanges] = useState([]);
  const [suggestions, setSuggestions] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [question, setQuestion] = useState('');
  const [enAttente, setEnAttente] = useState(null);
  const corpsRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    api.get('/fabia/historique')
      .then((res) => {
        setEchanges(res.data.echanges || []);
        setSuggestions(res.data.suggestions || []);
      })
      .catch(() => showToast('Impossible de joindre FAB’IA.'))
      .finally(() => setChargement(false));
  }, [showToast]);

  useEffect(() => {
    const box = corpsRef.current;
    if (box) box.scrollTop = box.scrollHeight;
  }, [echanges, enAttente, chargement]);

  useEffect(() => {
    if (autoFocus) inputRef.current?.focus();
  }, [autoFocus]);

  const poser = async (texte) => {
    const q = (texte ?? question).trim();
    if (q.length < 2 || enAttente) return;
    setQuestion('');
    setEnAttente(q);
    try {
      const res = await api.post('/fabia/questions', { question: q });
      setEchanges((prev) => [...prev, res.data]);
    } catch (err) {
      setQuestion(q);
      showToast(err.response?.status === 429
        ? 'Trop de questions en peu de temps. Patientez une minute.'
        : err.response?.data?.message || 'FAB’IA n’a pas pu répondre.');
    } finally {
      setEnAttente(null);
      inputRef.current?.focus();
    }
  };

  const nouvelleDiscussion = async () => {
    try {
      await api.delete('/fabia/historique');
      setEchanges([]);
    } catch {
      showToast('Impossible d’effacer la discussion.');
    }
  };

  const prenom = (user?.name || '').split(' ').slice(-1)[0];

  return (
    <div className="fchat">
      <div className="fchat-body" ref={corpsRef}>
        {chargement ? (
          <div className="fchat-loading"><Spinner size={20} /></div>
        ) : (
          <>
            <div className="fchat-welcome">
              <span className="fchat-avatar"><Spark size={18} /></span>
              <div className="fchat-msg fchat-msg-bot">
                Bonjour {prenom} ! Je suis <strong>FAB’IA</strong>, l’assistant du FabLab. Posez-moi une question sur le FabLab,
                les parcours… ou demandez-moi de rédiger un message.
              </div>
            </div>
            {echanges.map((e) => (
              <div key={e.id} className="fchat-exchange">
                <div className="fchat-msg fchat-msg-user">{e.question}<span>{heure(e.created_at)}</span></div>
                <div className="fchat-row">
                  <span className="fchat-avatar"><Spark size={18} /></span>
                  <div className="fchat-msg fchat-msg-bot">
                    <Markdown texte={e.reponse} />
                    <span>{e.source === 'local' ? 'Base de connaissances (hors ligne)' : 'FAB’IA'} · {heure(e.created_at)}</span>
                  </div>
                </div>
              </div>
            ))}
            {enAttente && (
              <div className="fchat-exchange">
                <div className="fchat-msg fchat-msg-user">{enAttente}</div>
                <div className="fchat-row">
                  <span className="fchat-avatar"><Spark size={18} /></span>
                  <div className="fchat-msg fchat-msg-bot fchat-typing" aria-label="FAB’IA écrit"><i /><i /><i /></div>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {!chargement && echanges.length === 0 && suggestions.length > 0 && (
        <div className="fchat-suggestions">
          {suggestions.map((s) => (
            <button key={s} type="button" onClick={() => poser(s)} disabled={!!enAttente}>{s}</button>
          ))}
        </div>
      )}

      <form className="fchat-form" onSubmit={(e) => { e.preventDefault(); poser(); }}>
        <input
          ref={inputRef}
          type="text"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="Écrire à FAB’IA…"
          maxLength={2000}
          disabled={!!enAttente}
        />
        <button type="submit" className="fchat-send" disabled={!!enAttente || question.trim().length < 2} aria-label="Envoyer">
          {enAttente ? <Spinner size={16} light /> : (
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M22 2 11 13M22 2l-7 20-4-9-9-4z" />
            </svg>
          )}
        </button>
      </form>

      {echanges.length > 0 && (
        <button type="button" className="fchat-reset" onClick={nouvelleDiscussion}>Nouvelle discussion</button>
      )}
    </div>
  );
}
