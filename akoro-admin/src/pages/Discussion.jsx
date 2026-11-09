import { useEffect, useLayoutEffect, useState, useRef, useCallback } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Modal from '../components/Modal';
import FabiaChat, { Spark } from '../components/FabiaChat';
import Spinner, { PageLoader } from '../components/Spinner';
import useToast from '../components/useToast';
import useConfirmation from '../components/useConfirmation';
import Markdown from '../utils/markdown';
import { can, getStoredUser } from '../utils/permissions';
import './Discussion.css';

const formatHeure = (value) => {
  if (!value) return '';
  return new Date(value).toLocaleTimeString('fr-FR', {
    hour: '2-digit',
    minute: '2-digit',
  });
};

const formatDateSeparateur = (value) => {
  if (!value) return '';
  const d = new Date(value);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);

  if (d.toDateString() === today.toDateString()) return "Aujourd'hui";
  if (d.toDateString() === yesterday.toDateString()) return 'Hier';
  return d.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
};

// Deux messages du même auteur à moins de 5 min d'écart forment un groupe (comme Messenger)
const ECART_GROUPE_MS = 5 * 60 * 1000;

const REACTIONS_PAR_DEFAUT = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

function MiniIcon({ name }) {
  const p = {
    width: 15, height: 15, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
    strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true,
  };
  switch (name) {
    case 'reply': return <svg {...p}><path d="M9 14 4 9l5-5" /><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11" /></svg>;
    case 'smile': return <svg {...p}><circle cx="12" cy="12" r="9" /><path d="M8 14s1.5 2 4 2 4-2 4-2M9 9.5h.01M15 9.5h.01" /></svg>;
    case 'edit': return <svg {...p}><path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" /></svg>;
    case 'trash': return <svg {...p}><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6" /></svg>;
    case 'spark': return <svg {...p}><path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z" /><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z" /></svg>;
    case 'close': return <svg {...p}><path d="M18 6 6 18M6 6l12 12" /></svg>;
    default: return null;
  }
}

export default function Discussion() {
  const showToast = useToast();
  const { confirm, confirmationDialog } = useConfirmation();
  const [moi] = useState(getStoredUser);
  const currentUserId = moi?.id;

  const [conversations, setConversations] = useState([]);
  const [loading, setLoading] = useState(true);
  // Conversation demandée depuis l'icône de messagerie (?c=ID)
  const [selectedId, setSelectedId] = useState(
    () => Number(new URLSearchParams(window.location.search).get('c')) || null
  );
  const [messages, setMessages] = useState([]);
  const [lectures, setLectures] = useState([]);
  const [reactionsDispo, setReactionsDispo] = useState(REACTIONS_PAR_DEFAUT);
  const [loadingMessages, setLoadingMessages] = useState(() => !!selectedId);
  const [contenu, setContenu] = useState('');
  const [sending, setSending] = useState(false);
  const [search, setSearch] = useState('');

  // Réponse / modification / réactions
  const [replyTo, setReplyTo] = useState(null);
  const [editing, setEditing] = useState(null);
  const [pickerFor, setPickerFor] = useState(null);

  // Nouvelle conversation privée
  const [showNewModal, setShowNewModal] = useState(false);
  const [contacts, setContacts] = useState([]);
  const [loadingContacts, setLoadingContacts] = useState(false);
  const [contactSearch, setContactSearch] = useState('');

  const [parcoursList, setParcoursList] = useState([]);
  const [showParcoursMenu, setShowParcoursMenu] = useState(false);

  // Assistant FAB'IA (bouton en bas à gauche)
  const [fabiaOuvert, setFabiaOuvert] = useState(false);

  // Résumé FAB'IA
  const [resume, setResume] = useState(null); // { loading } | { resume, source, messages } | { error }

  const messagesEndRef = useRef(null);
  const messagesBoxRef = useRef(null);
  const inputRef = useRef(null);
  const pollRef = useRef(null);
  const selectedIdRef = useRef(selectedId);
  const dernierIdRef = useRef(null);

  useEffect(() => {
    selectedIdRef.current = selectedId;
  }, [selectedId]);

  // Défile la zone des messages uniquement (la page ne bouge pas)
  const scrollToBottom = (smooth = true) => {
    const box = messagesBoxRef.current;
    if (box) box.scrollTo({ top: box.scrollHeight, behavior: smooth ? 'smooth' : 'auto' });
  };

  const procheDuBas = () => {
    const box = messagesBoxRef.current;
    return !box || box.scrollHeight - box.scrollTop - box.clientHeight < 120;
  };

  // ---------- Charger la liste des conversations ----------
  const loadConversations = useCallback(async () => {
    try {
      const res = await api.get('/conversations');
      setConversations(res.data || []);
    } catch {
      // silencieux en polling
    }
  }, []);

  // ---------- Charger les messages ----------
  const loadMessages = useCallback(
    async (id, silent = false) => {
      if (!id) return;
      // Le spinner est activé par l'appelant (selectConversation)
      try {
        const res = await api.get(`/conversations/${id}/messages`);
        // La conversation a pu changer pendant la requête
        if (selectedIdRef.current !== id) return;

        const liste = res.data.messages || [];
        const dernierId = liste.length ? liste[liste.length - 1].id : null;
        const nouveau = dernierId !== dernierIdRef.current;
        const suivre = !silent || (nouveau && procheDuBas());

        dernierIdRef.current = dernierId;
        setMessages(liste);
        setLectures(res.data.lectures || []);
        if (res.data.reactions_disponibles?.length) setReactionsDispo(res.data.reactions_disponibles);

        if (suivre) setTimeout(() => scrollToBottom(silent), 30);
        if (!silent || nouveau) {
          // Les messages sont maintenant lus : on met à jour le compteur de l'icône
          window.dispatchEvent(new Event('akoro:notifications-refresh'));
        }
      } catch {
        if (!silent) showToast('Erreur de chargement des messages.');
      } finally {
        if (!silent) setLoadingMessages(false);
      }
    },
    [showToast]
  );

  // ---------- Sélectionner une conversation ----------
  const selectConversation = useCallback(
    (id) => {
      selectedIdRef.current = id;
      dernierIdRef.current = null;
      setSelectedId(id);
      setMessages([]);
      setLectures([]);
      setReplyTo(null);
      setEditing(null);
      setPickerFor(null);
      setContenu('');
      setLoadingMessages(true);
      loadMessages(id);
    },
    [loadMessages]
  );

  // ---------- Chargement initial ----------
  useEffect(() => {
    api
      .get('/conversations')
      .then((res) => setConversations(res.data || []))
      .catch(() => showToast('Erreur de chargement des conversations.'))
      .finally(() => setLoading(false));
    if (selectedIdRef.current) loadMessages(selectedIdRef.current);
    api
      .get('/parcours')
      .then((res) => setParcoursList(res.data.data || res.data || []))
      .catch(() => {});
  }, [loadMessages, showToast]);

  // Clic sur un message dans l'icône alors qu'on est déjà sur cette page
  useEffect(() => {
    const ouvrir = (e) => {
      const id = Number(e.detail);
      if (id) selectConversation(id);
    };
    window.addEventListener('akoro:open-conversation', ouvrir);
    return () => window.removeEventListener('akoro:open-conversation', ouvrir);
  }, [selectConversation]);

  // ---------- Polling toutes les 4 secondes ----------
  useEffect(() => {
    pollRef.current = setInterval(() => {
      // Onglet caché : inutile d'occuper le serveur
      if (document.hidden) return;
      loadConversations();
      if (selectedIdRef.current) {
        loadMessages(selectedIdRef.current, true);
      }
    }, 4000);

    return () => clearInterval(pollRef.current);
  }, [loadConversations, loadMessages]);

  // Fermer le sélecteur de réactions au clic ailleurs
  useEffect(() => {
    if (!pickerFor) return undefined;
    const fermer = (e) => {
      if (!e.target.closest('.disc-react-picker, .disc-act-react')) setPickerFor(null);
    };
    document.addEventListener('mousedown', fermer);
    return () => document.removeEventListener('mousedown', fermer);
  }, [pickerFor]);

  useEffect(() => {
    if (!fabiaOuvert) return undefined;
    const fermer = (e) => e.key === 'Escape' && setFabiaOuvert(false);
    document.addEventListener('keydown', fermer);
    return () => document.removeEventListener('keydown', fermer);
  }, [fabiaOuvert]);

  // Zone de saisie : grandit avec le texte (jusqu'à 5 lignes)
  useLayoutEffect(() => {
    const el = inputRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 132)}px`;
  }, [contenu, selectedId]);

  const remplacerMessage = (m) => setMessages((prev) => prev.map((x) => (x.id === m.id ? m : x)));

  // ---------- Envoyer / modifier un message ----------
  const sendMessage = async (e) => {
    e?.preventDefault();
    const texte = contenu.trim();
    if (!texte || !selectedId || sending) return;

    setSending(true);
    try {
      if (editing) {
        const res = await api.put(`/messages/${editing.id}`, { contenu: texte });
        remplacerMessage(res.data);
        setEditing(null);
      } else {
        const res = await api.post(`/conversations/${selectedId}/messages`, {
          contenu: texte,
          reply_to_id: replyTo?.id,
        });
        dernierIdRef.current = res.data.id;
        setMessages((prev) => [...prev, res.data]);
        setReplyTo(null);
        setTimeout(scrollToBottom, 50);
        loadConversations();
      }
      setContenu('');
    } catch (err) {
      showToast(err.response?.data?.message || (editing ? 'Modification impossible.' : 'Erreur lors de l’envoi.'));
    } finally {
      setSending(false);
    }
  };

  const commencerReponse = (m) => {
    setEditing(null);
    setReplyTo(m);
    inputRef.current?.focus();
  };

  const commencerModification = (m) => {
    setReplyTo(null);
    setEditing(m);
    setContenu(m.contenu || '');
    inputRef.current?.focus();
  };

  const annulerComposition = () => {
    if (editing) setContenu('');
    setEditing(null);
    setReplyTo(null);
  };

  const supprimerMessage = async (m) => {
    const ok = await confirm({
      title: 'Supprimer ce message ?',
      message: 'Le message sera supprimé pour tous les participants. Cette action est définitive.',
      confirmLabel: 'Supprimer',
      variant: 'danger',
    });
    if (!ok) return;
    try {
      const res = await api.delete(`/messages/${m.id}`);
      remplacerMessage(res.data);
      if (editing?.id === m.id) annulerComposition();
      loadConversations();
    } catch (err) {
      showToast(err.response?.data?.message || 'Suppression impossible.');
    }
  };

  const reagir = async (m, emoji) => {
    setPickerFor(null);
    try {
      const res = await api.post(`/messages/${m.id}/reactions`, { emoji });
      remplacerMessage(res.data);
    } catch (err) {
      showToast(err.response?.data?.message || 'Réaction impossible.');
    }
  };

  // ---------- Résumé par FAB'IA ----------
  const resumer = async () => {
    if (!selectedId) return;
    setResume({ loading: true });
    try {
      const res = await api.post(`/conversations/${selectedId}/resume`);
      setResume(res.data);
    } catch (err) {
      setResume({
        error: err.response?.status === 429
          ? 'Trop de demandes de résumé. Réessayez dans une minute.'
          : err.response?.data?.message || 'Le résumé n’a pas pu être généré.',
      });
    }
  };

  // ---------- Conversation privée ----------
  const openPrivate = async (userId) => {
    try {
      const res = await api.post('/conversations/privee', { user_id: userId });
      setShowNewModal(false);
      await loadConversations();
      selectConversation(res.data.id);
    } catch (err) {
      showToast(err.response?.data?.message || 'Erreur.');
    }
  };

  // ---------- Groupe général ----------
  const openGroupeGeneral = async () => {
    try {
      const res = await api.get('/conversations/groupe-general');
      await loadConversations();
      selectConversation(res.data.id);
    } catch {
      showToast('Erreur lors de l’ouverture du groupe général.');
    }
  };

  // ---------- Groupe parcours ----------
  const openGroupeParcours = async (parcoursId) => {
    try {
      const res = await api.get(`/conversations/groupe-parcours/${parcoursId}`);
      setShowParcoursMenu(false);
      await loadConversations();
      selectConversation(res.data.id);
    } catch {
      showToast('Erreur lors de l’ouverture du groupe parcours.');
    }
  };

  // ---------- Modal nouvelle conversation ----------
  const openNewModal = async () => {
    setShowNewModal(true);
    setContactSearch('');
    setLoadingContacts(true);
    try {
      const res = await api.get('/conversations/contacts');
      setContacts(res.data || []);
    } catch {
      showToast('Erreur de chargement des contacts.');
    } finally {
      setLoadingContacts(false);
    }
  };

  // ---------- Filtrage ----------
  const filtered = conversations.filter((c) =>
    (c.nom || '').toLowerCase().includes(search.toLowerCase())
  );
  const contactsFiltres = contacts.filter((c) =>
    `${c.name} ${c.detail}`.toLowerCase().includes(contactSearch.toLowerCase())
  );

  const selectedConv = conversations.find((c) => c.id === selectedId);
  const peutModerer = selectedConv && selectedConv.type !== 'privee' && can.dashboard(moi?.role);

  // ---------- « Vu » : sous mon dernier message ----------
  const monDernier = [...messages].reverse().find((m) => m.auteur_id === currentUserId && !m.supprime);
  const vuPar = monDernier
    ? lectures.filter((l) => new Date(l.last_read_at) >= new Date(monDernier.created_at))
    : [];
  const libelleVu = !vuPar.length
    ? null
    : selectedConv?.type === 'privee'
      ? 'Vu'
      : vuPar.length <= 3
        ? `Vu par ${vuPar.map((l) => l.name.split(' ')[0]).join(', ')}`
        : `Vu par ${vuPar.length} personnes`;

  // ---------- Grouper messages par date ----------
  const messagesByDate = [];
  let lastDate = null;
  const memeGroupe = (a, b) =>
    a && b && a.auteur_id === b.auteur_id && !a.supprime && !b.supprime
    && new Date(a.created_at).toDateString() === new Date(b.created_at).toDateString()
    && Math.abs(new Date(b.created_at) - new Date(a.created_at)) < ECART_GROUPE_MS;
  messages.forEach((m, i) => {
    const dateKey = new Date(m.created_at).toDateString();
    if (dateKey !== lastDate) {
      messagesByDate.push({ type: 'separator', date: m.created_at });
      lastDate = dateKey;
    }
    messagesByDate.push({
      type: 'message',
      data: m,
      debut: !memeGroupe(messages[i - 1], m),
      fin: !memeGroupe(m, messages[i + 1]),
    });
  });
  const estGroupe = selectedConv && selectedConv.type !== 'privee';

  if (loading) {
    return (
      <Layout>
        <PageLoader />
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="disc-container">
        {/* ---------- Colonne gauche : liste ---------- */}
        <div className="disc-sidebar">
          <div className="disc-sidebar-header">
            <h2>Discussion</h2>
            <div className="disc-sidebar-actions">
              <button
                className="parcours-add"
                onClick={openGroupeGeneral}
                title="Groupe général du FabLab"
              >
                Général
              </button>

              <div style={{ position: 'relative' }}>
                <button
                  className="parcours-add"
                  onClick={() => setShowParcoursMenu((v) => !v)}
                  title="Groupe d’un parcours"
                >
                  Parcours
                </button>
                {showParcoursMenu && (
                  <div className="disc-parcours-menu">
                    {parcoursList.length === 0 ? (
                      <div className="disc-empty">Aucun parcours</div>
                    ) : (
                      parcoursList.map((p) => (
                        <button
                          key={p.id}
                          className="disc-parcours-item"
                          onClick={() => openGroupeParcours(p.id)}
                        >
                          {p.nom}
                        </button>
                      ))
                    )}
                  </div>
                )}
              </div>

              <button
                className="parcours-add"
                onClick={openNewModal}
                title="Conversation privée"
              >
                +
              </button>
            </div>
          </div>

          <input
            type="text"
            className="disc-search"
            placeholder="Rechercher…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />

          <div className="disc-list">
            {filtered.length === 0 ? (
              <div className="disc-empty">Aucune conversation</div>
            ) : (
              filtered.map((c) => (
                <button
                  key={c.id}
                  className={
                    'disc-item' + (selectedId === c.id ? ' disc-item-active' : '')
                  }
                  onClick={() => selectConversation(c.id)}
                >
                  <Avatar name={c.nom || '?'} url={c.avatar_url} size={40} />
                  <div className="disc-item-body">
                    <div className="disc-item-top">
                      <span className="disc-item-name">
                        {c.nom}
                        {c.interlocuteur_admin && <span className="disc-admin-badge">Admin</span>}
                      </span>
                      {c.dernier_message && (
                        <span className="disc-item-time">
                          {formatHeure(c.dernier_message.created_at)}
                        </span>
                      )}
                    </div>
                    <div className="disc-item-bottom">
                      <span className={'disc-item-preview' + (c.dernier_message?.supprime ? ' is-deleted' : '')}>
                        {c.dernier_message
                          ? `${c.dernier_message.auteur || ''} : ${c.dernier_message.contenu}`
                          : 'Aucun message'}
                      </span>
                      {c.unread_count > 0 && (
                        <span className="disc-badge">{c.unread_count}</span>
                      )}
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>

          <button
            type="button"
            className={'disc-fabia-fab' + (fabiaOuvert ? ' is-open' : '')}
            onClick={() => setFabiaOuvert((v) => !v)}
            aria-expanded={fabiaOuvert}
            aria-label="Ouvrir l’assistant FAB’IA"
            title="FAB’IA, l’assistant du FabLab"
          >
            {fabiaOuvert ? <MiniIcon name="close" /> : <Spark size={22} />}
          </button>
        </div>

        {fabiaOuvert && (
          <section className="disc-fabia-panel" role="dialog" aria-label="Assistant FAB’IA">
            <header className="disc-fabia-head">
              <span className="disc-fabia-logo"><Spark size={18} /></span>
              <div>
                <strong>FAB’IA</strong>
                <span>Assistant du FabLab</span>
              </div>
              {can.manageFabia(moi?.role) && (
                <Link to="/fabia" className="disc-fabia-manage" title="Base de connaissances et statistiques">Gérer</Link>
              )}
              <button type="button" className="disc-act" onClick={() => setFabiaOuvert(false)} aria-label="Fermer FAB’IA">
                <MiniIcon name="close" />
              </button>
            </header>
            <FabiaChat autoFocus />
          </section>
        )}

        {/* ---------- Colonne droite : chat ---------- */}
        <div className="disc-main">
          {!selectedId ? (
            <div className="disc-placeholder">
              <p>
                Sélectionnez une conversation
                <br />
                ou créez-en une nouvelle.
              </p>
            </div>
          ) : (
            <>
              <div className="disc-chat-header">
                <Avatar name={selectedConv?.nom || '?'} url={selectedConv?.avatar_url} size={36} />
                <div className="disc-chat-title">
                  <strong>
                    {selectedConv?.nom}
                    {selectedConv?.interlocuteur_admin && <span className="disc-admin-badge">Admin</span>}
                  </strong>
                  {selectedConv?.parcours ? (
                    <span className="disc-chat-sub">{selectedConv.parcours}</span>
                  ) : selectedConv?.type !== 'privee' && selectedConv?.membres ? (
                    <span className="disc-chat-sub">{selectedConv.membres.length} membres</span>
                  ) : null}
                </div>
                <button
                  type="button"
                  className="disc-summary-btn"
                  onClick={resumer}
                  disabled={messages.length === 0}
                  title="Résumer la conversation avec FAB’IA"
                >
                  <MiniIcon name="spark" /> Résumer
                </button>
              </div>

              <div className="disc-messages" ref={messagesBoxRef}>
                {loadingMessages ? (
                  <div className="disc-loading">
                    <Spinner size={24} />
                  </div>
                ) : (
                  <>
                    {messages.length === 0 && (
                      <div className="disc-empty">Aucun message. Écrivez le premier !</div>
                    )}
                    {messagesByDate.map((item, i) => {
                      if (item.type === 'separator') {
                        return (
                          <div key={`sep-${i}`} className="disc-date-sep">
                            {formatDateSeparateur(item.date)}
                          </div>
                        );
                      }
                      const { data: m, debut, fin } = item;
                      const mien = m.auteur_id === currentUserId;
                      const peutSupprimer = !m.supprime && (mien || peutModerer);

                      return (
                        <div
                          key={m.id}
                          className={
                            'disc-bubble-wrap' +
                            (mien ? ' disc-bubble-mine' : ' disc-bubble-other') +
                            (debut ? ' is-first' : ' is-grouped') +
                            (fin ? ' is-last' : '') +
                            (editing?.id === m.id ? ' is-editing' : '')
                          }
                        >
                          {!mien && estGroupe && (
                            <span className="disc-bubble-avatar">
                              {fin && <Avatar name={m.auteur?.name || '?'} url={m.auteur?.photo_url} size={28} />}
                            </span>
                          )}
                          <div className="disc-bubble-col">
                            <div className={'disc-bubble' + (m.supprime ? ' is-deleted' : '')}>
                              {!mien && estGroupe && debut && !m.supprime && (
                                <div className="disc-bubble-author">
                                  {m.auteur?.name}
                                  {m.auteur?.admin && <span className="disc-admin-badge">Admin</span>}
                                </div>
                              )}
                              {m.reply_to && !m.supprime && (
                                <div className="disc-quote">
                                  <span className="disc-quote-author">{m.reply_to.auteur || '?'}</span>
                                  <span className="disc-quote-text">
                                    {m.reply_to.supprime ? 'Message supprimé' : m.reply_to.extrait}
                                  </span>
                                </div>
                              )}
                              <div className="disc-bubble-text">
                                {m.supprime ? 'Message supprimé' : m.contenu}
                              </div>
                              <div className="disc-bubble-time">
                                {m.modifie && !m.supprime && <span className="disc-edited">modifié · </span>}
                                {formatHeure(m.created_at)}
                              </div>
                            </div>

                            {m.reactions?.length > 0 && (
                              <div className="disc-reactions">
                                {m.reactions.map((r) => (
                                  <button
                                    key={r.emoji}
                                    type="button"
                                    className={'disc-reaction' + (r.moi ? ' is-mine' : '')}
                                    onClick={() => reagir(m, r.emoji)}
                                    title={r.noms.join(', ')}
                                  >
                                    {r.emoji} {r.total > 1 && <span>{r.total}</span>}
                                  </button>
                                ))}
                              </div>
                            )}

                            {monDernier?.id === m.id && libelleVu && (
                              <div className="disc-seen">{libelleVu}</div>
                            )}
                          </div>

                          {!m.supprime && (
                            <div className="disc-actions">
                              <button type="button" className="disc-act disc-act-react" title="Réagir" onClick={() => setPickerFor(pickerFor === m.id ? null : m.id)}>
                                <MiniIcon name="smile" />
                              </button>
                              <button type="button" className="disc-act" title="Répondre" onClick={() => commencerReponse(m)}>
                                <MiniIcon name="reply" />
                              </button>
                              {m.peut_modifier && (
                                <button type="button" className="disc-act" title="Modifier (15 min après l’envoi)" onClick={() => commencerModification(m)}>
                                  <MiniIcon name="edit" />
                                </button>
                              )}
                              {peutSupprimer && (
                                <button type="button" className="disc-act disc-act-danger" title="Supprimer pour tout le monde" onClick={() => supprimerMessage(m)}>
                                  <MiniIcon name="trash" />
                                </button>
                              )}
                              {pickerFor === m.id && (
                                <div className="disc-react-picker">
                                  {reactionsDispo.map((emoji) => (
                                    <button key={emoji} type="button" onClick={() => reagir(m, emoji)}>
                                      {emoji}
                                    </button>
                                  ))}
                                </div>
                              )}
                            </div>
                          )}
                        </div>
                      );
                    })}
                    <div ref={messagesEndRef} />
                  </>
                )}
              </div>

              {(replyTo || editing) && (
                <div className="disc-compose-context">
                  <div>
                    <strong>
                      {editing
                        ? 'Modification du message'
                        : `Réponse à ${replyTo.auteur_id === currentUserId ? 'vous-même' : replyTo.auteur?.name || '?'}`}
                    </strong>
                    <span>{(editing || replyTo).contenu}</span>
                  </div>
                  <button type="button" className="disc-act" onClick={annulerComposition} title="Annuler (Échap)">
                    <MiniIcon name="close" />
                  </button>
                </div>
              )}

              <form className="disc-composer" onSubmit={sendMessage}>
                <textarea
                  ref={inputRef}
                  rows={1}
                  placeholder={editing ? 'Modifier le message…' : 'Écrire un message…'}
                  title="Entrée pour envoyer · Maj + Entrée pour aller à la ligne"
                  value={contenu}
                  onChange={(e) => setContenu(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Escape') annulerComposition();
                    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                      e.preventDefault();
                      sendMessage();
                    }
                  }}
                  maxLength={2000}
                  disabled={sending}
                />
                <button
                  type="submit"
                  className="parcours-add"
                  disabled={sending || !contenu.trim()}
                >
                  {sending ? <Spinner size={16} light /> : editing ? 'Enregistrer' : 'Envoyer'}
                </button>
              </form>
            </>
          )}
        </div>
      </div>

      {/* ---------- Modal nouvelle conversation privée ---------- */}
      {showNewModal && (
        <div className="disc-modal-overlay" onClick={() => setShowNewModal(false)}>
          <div className="disc-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Nouvelle conversation privée</h3>
            <input
              type="text"
              className="disc-search disc-search-modal"
              placeholder="Rechercher une personne ou un parcours…"
              value={contactSearch}
              onChange={(e) => setContactSearch(e.target.value)}
              autoFocus
            />
            {loadingContacts ? (
              <Spinner size={24} />
            ) : contactsFiltres.length === 0 ? (
              <p className="disc-empty">Aucune personne trouvée.</p>
            ) : (
              <div className="disc-benef-list">
                {contactsFiltres.map((c) => (
                  <button
                    key={c.id}
                    className="disc-benef-item"
                    onClick={() => openPrivate(c.id)}
                  >
                    <Avatar name={c.name} url={c.photo_url} size={36} />
                    <span className="disc-contact-body">
                      <span className="disc-contact-name">
                        {c.name}
                        {c.admin && <span className="disc-admin-badge">Admin</span>}
                      </span>
                      <span className="disc-contact-detail">{c.detail}</span>
                    </span>
                  </button>
                ))}
              </div>
            )}
            <button className="bene-filter" onClick={() => setShowNewModal(false)}>
              Fermer
            </button>
          </div>
        </div>
      )}

      {/* ---------- Résumé FAB'IA ---------- */}
      <Modal
        open={!!resume}
        title={`Résumé FAB’IA${selectedConv?.nom ? ` · ${selectedConv.nom}` : ''}`}
        onClose={() => setResume(null)}
        className="disc-summary-modal"
      >
        {resume?.loading ? (
          <div className="disc-summary-loading">
            <Spinner size={22} />
            <span>FAB’IA lit la conversation…</span>
          </div>
        ) : resume?.error ? (
          <p className="disc-summary-error">{resume.error}</p>
        ) : resume ? (
          <>
            <Markdown texte={resume.resume} className="disc-summary-text" />
            <p className="disc-summary-meta">
              {resume.messages} message(s) analysé(s)
              {resume.source === 'local' && ' · résumé simplifié (IA indisponible)'}
            </p>
          </>
        ) : null}
      </Modal>

      {confirmationDialog}
    </Layout>
  );
}
