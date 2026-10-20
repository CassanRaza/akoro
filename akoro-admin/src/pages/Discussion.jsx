import { useEffect, useState, useRef, useCallback } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner, { PageLoader } from '../components/Spinner';
import useToast from '../components/useToast';
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

const getCurrentUserId = () => {
  try {
    return JSON.parse(localStorage.getItem('akoro_user') || '{}')?.id;
  } catch {
    return null;
  }
};

export default function Discussion() {
  const showToast = useToast();
  const [conversations, setConversations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [contenu, setContenu] = useState('');
  const [sending, setSending] = useState(false);
  const [search, setSearch] = useState('');
  const [showNewModal, setShowNewModal] = useState(false);
  const [beneficiaires, setBeneficiaires] = useState([]);
  const [loadingBenef, setLoadingBenef] = useState(false);
  const [parcoursList, setParcoursList] = useState([]);
  const [showParcoursMenu, setShowParcoursMenu] = useState(false);

  const messagesEndRef = useRef(null);
  const pollRef = useRef(null);
  const selectedIdRef = useRef(null);
  const currentUserId = getCurrentUserId();

  useEffect(() => {
    selectedIdRef.current = selectedId;
  }, [selectedId]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
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
      if (!silent) setLoadingMessages(true);
      try {
        const res = await api.get(`/conversations/${id}/messages`);
        const data = res.data.data || res.data || [];
        setMessages(data);
        if (!silent) setTimeout(scrollToBottom, 100);
      } catch {
        if (!silent) showToast('Erreur de chargement des messages.');
      } finally {
        if (!silent) setLoadingMessages(false);
      }
    },
    [showToast]
  );

  // ---------- Chargement initial ----------
  useEffect(() => {
    loadConversations().finally(() => setLoading(false));
    api
      .get('/parcours')
      .then((res) => setParcoursList(res.data.data || res.data || []))
      .catch(() => {});
  }, [loadConversations]);

  // ---------- Polling toutes les 4 secondes ----------
  useEffect(() => {
    pollRef.current = setInterval(() => {
      loadConversations();
      if (selectedIdRef.current) {
        loadMessages(selectedIdRef.current, true);
      }
    }, 4000);

    return () => clearInterval(pollRef.current);
  }, [loadConversations, loadMessages]);

  // ---------- Sélectionner une conversation ----------
  const selectConversation = (id) => {
    setSelectedId(id);
    setMessages([]);
    loadMessages(id);
  };

  // ---------- Envoyer un message ----------
  const sendMessage = async (e) => {
    e.preventDefault();
    if (!contenu.trim() || !selectedId || sending) return;

    setSending(true);
    try {
      const res = await api.post(`/conversations/${selectedId}/messages`, {
        contenu: contenu.trim(),
      });
      setMessages((prev) => [...prev, res.data]);
      setContenu('');
      setTimeout(scrollToBottom, 50);
      loadConversations();
    } catch {
      showToast('Erreur lors de l’envoi.');
    } finally {
      setSending(false);
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
    setLoadingBenef(true);
    try {
      const res = await api.get('/beneficiaires');
      setBeneficiaires(res.data.data || res.data || []);
    } catch {
      showToast('Erreur de chargement des bénéficiaires.');
    } finally {
      setLoadingBenef(false);
    }
  };

  // ---------- Filtrage ----------
  const filtered = conversations.filter((c) =>
    (c.nom || '').toLowerCase().includes(search.toLowerCase())
  );

  const selectedConv = conversations.find((c) => c.id === selectedId);

  // ---------- Grouper messages par date ----------
  const messagesByDate = [];
  let lastDate = null;
  messages.forEach((m) => {
    const dateKey = new Date(m.created_at).toDateString();
    if (dateKey !== lastDate) {
      messagesByDate.push({ type: 'separator', date: m.created_at });
      lastDate = dateKey;
    }
    messagesByDate.push({ type: 'message', data: m });
  });

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
                  <Avatar name={c.nom || '?'} size={40} />
                  <div className="disc-item-body">
                    <div className="disc-item-top">
                      <span className="disc-item-name">{c.nom}</span>
                      {c.dernier_message && (
                        <span className="disc-item-time">
                          {formatHeure(c.dernier_message.created_at)}
                        </span>
                      )}
                    </div>
                    <div className="disc-item-bottom">
                      <span className="disc-item-preview">
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
        </div>

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
                <Avatar name={selectedConv?.nom || '?'} size={36} />
                <div>
                  <strong>{selectedConv?.nom}</strong>
                  {selectedConv?.parcours && (
                    <span className="disc-chat-sub">{selectedConv.parcours}</span>
                  )}
                </div>
              </div>

              <div className="disc-messages">
                {loadingMessages ? (
                  <div className="disc-loading">
                    <Spinner size={24} />
                  </div>
                ) : (
                  <>
                    {messagesByDate.map((item, i) =>
                      item.type === 'separator' ? (
                        <div key={`sep-${i}`} className="disc-date-sep">
                          {formatDateSeparateur(item.date)}
                        </div>
                      ) : (
                        <div
                          key={item.data.id}
                          className={
                            'disc-bubble-wrap' +
                            (item.data.auteur_id === currentUserId
                              ? ' disc-bubble-mine'
                              : ' disc-bubble-other')
                          }
                        >
                          <div className="disc-bubble">
                            {item.data.auteur_id !== currentUserId && (
                              <div className="disc-bubble-author">
                                {item.data.auteur?.name}
                              </div>
                            )}
                            <div className="disc-bubble-text">{item.data.contenu}</div>
                            <div className="disc-bubble-time">
                              {formatHeure(item.data.created_at)}
                            </div>
                          </div>
                        </div>
                      )
                    )}
                    <div ref={messagesEndRef} />
                  </>
                )}
              </div>

              <form className="disc-composer" onSubmit={sendMessage}>
                <input
                  type="text"
                  placeholder="Écrire un message…"
                  value={contenu}
                  onChange={(e) => setContenu(e.target.value)}
                  maxLength={2000}
                  disabled={sending}
                />
                <button
                  type="submit"
                  className="parcours-add"
                  disabled={sending || !contenu.trim()}
                >
                  {sending ? <Spinner size={16} light /> : 'Envoyer'}
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
            {loadingBenef ? (
              <Spinner size={24} />
            ) : beneficiaires.length === 0 ? (
              <p>Aucun bénéficiaire trouvé.</p>
            ) : (
              <div className="disc-benef-list">
                {beneficiaires.map((b) => (
                  <button
                    key={b.id}
                    className="disc-benef-item"
                    onClick={() => openPrivate(b.id)}
                  >
                    <Avatar name={b.name} url={b.photo_url} size={36} />
                    <span>{b.name}</span>
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
    </Layout>
  );
}