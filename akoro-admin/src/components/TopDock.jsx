import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import Avatar from './Avatar';
import ThemeToggle from './ThemeToggle';
import { getSeen, markSeen, refreshNotifications, useNotifications } from '../services/notifications';
import './TopDock.css';

// Dock flottant : messagerie + notifications + thème.
// Clic = ouvrir ; appui maintenu puis glisser = déplacer (souris ou doigt).

const POS_KEY = 'akoro_dock_pos';
const HOLD_MS = 280;
const MARGIN = 8;

const TYPES = {
  justificatif: { label: 'Justificatif', tone: 'pink', icon: 'doc' },
  correction: { label: 'À corriger', tone: 'blue', icon: 'check' },
  inscription: { label: 'Inscription', tone: 'green', icon: 'user' },
  echeance: { label: 'Échéance', tone: 'amber', icon: 'clock' },
  echu: { label: 'En retard', tone: 'red', icon: 'alert' },
  seance: { label: 'Séance', tone: 'blue', icon: 'calendar' },
};

function Icon({ name, size = 20 }) {
  const p = {
    width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
    strokeWidth: 1.9, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true,
  };
  switch (name) {
    case 'bell': return <svg {...p}><path d="M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8" /><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" /></svg>;
    case 'chat': return <svg {...p}><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z" /><path d="M8.5 11h.01M12 11h.01M15.5 11h.01" /></svg>;
    case 'grip': return <svg {...p} strokeWidth={2.4}><path d="M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" /></svg>;
    case 'doc': return <svg {...p}><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" /><path d="M14 3v5h5M9 13h6M9 17h4" /></svg>;
    case 'check': return <svg {...p}><path d="M9 11l3 3 8-8" /><path d="M20 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" /></svg>;
    case 'user': return <svg {...p}><circle cx="10" cy="8" r="4" /><path d="M2 21a8 8 0 0 1 13.3-6M19 16v6M16 19h6" /></svg>;
    case 'clock': return <svg {...p}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg>;
    case 'alert': return <svg {...p}><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z" /><path d="M12 9v4M12 17h.01" /></svg>;
    case 'calendar': return <svg {...p}><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></svg>;
    case 'phone': return <svg {...p}><rect x="6" y="2" width="12" height="20" rx="2.5" /><path d="M11 18h2" /></svg>;
    case 'close': return <svg {...p}><path d="M18 6 6 18M6 6l12 12" /></svg>;
    default: return null;
  }
}

const rtf = new Intl.RelativeTimeFormat('fr', { numeric: 'auto' });
function ilya(date, now) {
  if (!date) return '';
  const diff = (new Date(date).getTime() - now) / 1000;
  const abs = Math.abs(diff);
  if (abs < 60) return 'à l’instant';
  if (abs < 3600) return rtf.format(Math.round(diff / 60), 'minute');
  if (abs < 86400) return rtf.format(Math.round(diff / 3600), 'hour');
  if (abs < 86400 * 30) return rtf.format(Math.round(diff / 86400), 'day');
  return new Date(date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
}

function readPos() {
  try {
    const p = JSON.parse(localStorage.getItem(POS_KEY) || 'null');
    return p && Number.isFinite(p.x) && Number.isFinite(p.y) ? p : null;
  } catch {
    return null;
  }
}

const clamp = (v, min, max) => Math.min(Math.max(v, min), Math.max(min, max));

export default function TopDock() {
  const navigate = useNavigate();
  const location = useLocation();
  const { data } = useNotifications();

  const dockRef = useRef(null);
  const drag = useRef(null);
  const [pos, setPos] = useState(readPos); // { x, y } en fractions de l'écran, ou null = place par défaut
  const [dragging, setDragging] = useState(false);
  const [open, setOpen] = useState(null); // 'notifs' | 'messages' | null
  const [panelStyle, setPanelStyle] = useState({});
  const [now, setNow] = useState(0);
  const [seen, setSeen] = useState(getSeen);

  const alertes = data?.alertes || [];
  const messagerie = data?.messagerie || { non_lues: 0, derniers: [] };
  const nonVues = alertes.filter((a) => !seen.has(a.id)).length;

  // ---------- Position ----------
  const applyPos = useCallback(() => {
    const el = dockRef.current;
    if (!el) return;
    if (!pos) {
      el.style.left = '';
      el.style.top = '';
      return;
    }
    const { width, height } = el.getBoundingClientRect();
    el.style.left = `${clamp(pos.x * window.innerWidth, MARGIN, window.innerWidth - width - MARGIN)}px`;
    el.style.top = `${clamp(pos.y * window.innerHeight, MARGIN, window.innerHeight - height - MARGIN)}px`;
  }, [pos]);

  useLayoutEffect(() => {
    applyPos();
    window.addEventListener('resize', applyPos);
    return () => window.removeEventListener('resize', applyPos);
  }, [applyPos]);

  const cancelHold = () => {
    if (drag.current?.timer) clearTimeout(drag.current.timer);
  };

  const onPointerDown = (e) => {
    if (e.button !== undefined && e.button !== 0) return;
    const rect = dockRef.current.getBoundingClientRect();
    const start = { x: e.clientX, y: e.clientY };
    const grip = e.target.closest('.dock-grip');
    const pointerId = e.pointerId;
    const startDrag = () => {
      if (!drag.current) return;
      drag.current.active = true;
      setDragging(true);
      setOpen(null);
      navigator.vibrate?.(12);
      // Capture seulement une fois le déplacement lancé, pour ne pas voler les clics des boutons
      try { dockRef.current?.setPointerCapture(pointerId); } catch { /* pointeur déjà relâché */ }
    };
    drag.current = { start, offset: { x: start.x - rect.left, y: start.y - rect.top }, active: false };
    // Sur la poignée, on peut déplacer tout de suite ; ailleurs il faut maintenir
    if (grip) startDrag();
    else drag.current.timer = setTimeout(startDrag, HOLD_MS);
  };

  const onPointerMove = (e) => {
    const d = drag.current;
    if (!d) return;
    const dist = Math.hypot(e.clientX - d.start.x, e.clientY - d.start.y);
    if (!d.active) {
      if (dist > 8) cancelHold(); // l'utilisateur fait défiler, pas un appui long
      return;
    }
    const el = dockRef.current;
    const { width, height } = el.getBoundingClientRect();
    el.style.left = `${clamp(e.clientX - d.offset.x, MARGIN, window.innerWidth - width - MARGIN)}px`;
    el.style.top = `${clamp(e.clientY - d.offset.y, MARGIN, window.innerHeight - height - MARGIN)}px`;
  };

  const onPointerUp = () => {
    const d = drag.current;
    cancelHold();
    if (d?.active) {
      const rect = dockRef.current.getBoundingClientRect();
      const next = { x: rect.left / window.innerWidth, y: rect.top / window.innerHeight };
      setPos(next);
      try { localStorage.setItem(POS_KEY, JSON.stringify(next)); } catch { /* ignoré */ }
      setDragging(false);
      // Empêche le clic qui suit le relâchement
      d.suppressClick = true;
      setTimeout(() => { drag.current = null; }, 0);
      return;
    }
    drag.current = null;
  };

  const resetPos = () => {
    setPos(null);
    try { localStorage.removeItem(POS_KEY); } catch { /* ignoré */ }
  };

  // ---------- Panneaux ----------
  const placePanel = () => {
    const rect = dockRef.current.getBoundingClientRect();
    if (window.innerWidth < 640) return setPanelStyle({});
    const style = {};
    if (rect.left + rect.width / 2 > window.innerWidth / 2) style.right = Math.max(MARGIN, window.innerWidth - rect.right);
    else style.left = Math.max(MARGIN, rect.left);
    if (rect.top + rect.height / 2 > window.innerHeight / 2) style.bottom = window.innerHeight - rect.top + 10;
    else style.top = rect.bottom + 10;
    setPanelStyle(style);
  };

  const closePanel = useCallback(() => {
    setOpen((current) => {
      if (current === 'notifs') {
        const ids = (data?.alertes || []).map((a) => a.id);
        markSeen(ids);
        setSeen(new Set(ids));
      }
      return null;
    });
  }, [data]);

  const toggle = (name, e) => {
    if (drag.current?.suppressClick) {
      e.preventDefault();
      return;
    }
    if (open === name) return closePanel();
    if (open === 'notifs') closePanel();
    placePanel();
    setNow(Date.now());
    setOpen(name);
    refreshNotifications();
  };

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => e.key === 'Escape' && closePanel();
    const onDown = (e) => {
      if (!e.target.closest('.dock-panel') && !e.target.closest('.dock')) closePanel();
    };
    window.addEventListener('keydown', onKey);
    window.addEventListener('pointerdown', onDown);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('pointerdown', onDown);
    };
  }, [open, closePanel]);

  // Change de page → on ferme le panneau
  const [lastPath, setLastPath] = useState(location.pathname);
  if (lastPath !== location.pathname) {
    setLastPath(location.pathname);
    if (open) setOpen(null);
  }

  const goAlerte = (a) => {
    closePanel();
    navigate(a.lien);
  };

  const goMessage = (m) => {
    closePanel();
    if (location.pathname === '/discussion') {
      window.dispatchEvent(new CustomEvent('akoro:open-conversation', { detail: m.conversation_id }));
    }
    navigate(`/discussion?c=${m.conversation_id}`);
  };

  const markAllSeen = () => {
    const ids = alertes.map((a) => a.id);
    markSeen(ids);
    setSeen(new Set(ids));
  };

  return (
    <>
      <div
        ref={dockRef}
        className={`dock${pos ? ' dock-placed' : ''}${dragging ? ' is-dragging' : ''}`}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onContextMenu={(e) => e.preventDefault()}
      >
        <span
          className="dock-grip"
          title="Glisser pour déplacer · double-clic pour replacer"
          onDoubleClick={resetPos}
          aria-hidden="true"
        >
          <Icon name="grip" size={16} />
        </span>

        <button
          type="button"
          className={`dock-btn${open === 'messages' ? ' is-open' : ''}`}
          onClick={(e) => toggle('messages', e)}
          aria-label={`Messagerie${messagerie.non_lues ? ` (${messagerie.non_lues} non lue(s))` : ''}`}
          aria-expanded={open === 'messages'}
          title="Messagerie"
        >
          <Icon name="chat" />
          {messagerie.non_lues > 0 && <span className="dock-badge dock-badge-blue">{messagerie.non_lues}</span>}
        </button>

        <button
          type="button"
          className={`dock-btn${open === 'notifs' ? ' is-open' : ''}`}
          onClick={(e) => toggle('notifs', e)}
          aria-label={`Notifications${nonVues ? ` (${nonVues} nouvelle(s))` : ''}`}
          aria-expanded={open === 'notifs'}
          title="Notifications"
        >
          <span className={nonVues ? 'dock-bell-ring' : ''}><Icon name="bell" /></span>
          {nonVues > 0 && <span className="dock-badge">{nonVues > 9 ? '9+' : nonVues}</span>}
        </button>

        <span
          className="dock-btn dock-mobile"
          role="status"
          title="Application mobile AKORO — compagnon connecté (v1.0.8)"
          aria-label="Application mobile connectée, version 1.0.8"
        >
          <Icon name="phone" />
          <span className="dock-mobile-dot" aria-hidden="true" />
        </span>

        <span className="dock-sep" aria-hidden="true" />
        <ThemeToggle variant="dock" ignoreClick={() => Boolean(drag.current?.suppressClick)} />
      </div>

      {open && <button type="button" className="dock-backdrop" aria-label="Fermer" onClick={closePanel} />}

      {open === 'notifs' && (
        <section className="dock-panel" style={panelStyle} role="dialog" aria-label="Notifications">
          <header className="dock-panel-head">
            <div>
              <h2>Notifications</h2>
              <p>{alertes.length ? `${alertes.length} élément(s) · ${nonVues} nouveau(x)` : 'Tout est à jour'}</p>
            </div>
            <div className="dock-panel-actions">
              {nonVues > 0 && <button type="button" className="dock-textbtn" onClick={markAllSeen}>Tout marquer lu</button>}
              <button type="button" className="dock-iconbtn" onClick={closePanel} aria-label="Fermer"><Icon name="close" size={18} /></button>
            </div>
          </header>
          {alertes.length === 0 ? (
            <div className="dock-empty">
              <Icon name="bell" size={28} />
              <p>Aucune notification pour le moment.</p>
            </div>
          ) : (
            <ul className="dock-list">
              {alertes.map((a) => {
                const t = TYPES[a.type] || TYPES.seance;
                return (
                  <li key={a.id}>
                    <button type="button" className={`dock-item${seen.has(a.id) ? '' : ' is-new'}`} onClick={() => goAlerte(a)}>
                      <span className={`dock-item-icon tone-${t.tone}`}><Icon name={t.icon} size={18} /></span>
                      <span className="dock-item-body">
                        <span className="dock-item-title">{a.titre}</span>
                        {a.texte && <span className="dock-item-text">{a.texte}</span>}
                        <span className="dock-item-meta">{t.label} · {ilya(a.date, now)}</span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      )}

      {open === 'messages' && (
        <section className="dock-panel" style={panelStyle} role="dialog" aria-label="Messagerie">
          <header className="dock-panel-head">
            <div>
              <h2>Messagerie</h2>
              <p>{messagerie.non_lues ? `${messagerie.non_lues} conversation(s) non lue(s)` : 'Aucun message non lu'}</p>
            </div>
            <div className="dock-panel-actions">
              <button type="button" className="dock-iconbtn" onClick={closePanel} aria-label="Fermer"><Icon name="close" size={18} /></button>
            </div>
          </header>
          {messagerie.derniers.length === 0 ? (
            <div className="dock-empty">
              <Icon name="chat" size={28} />
              <p>Aucun message reçu.</p>
            </div>
          ) : (
            <ul className="dock-list">
              {messagerie.derniers.map((m) => (
                <li key={m.id}>
                  <button type="button" className={`dock-item${m.non_lu ? ' is-new' : ''}`} onClick={() => goMessage(m)}>
                    <Avatar name={m.auteur || ''} url={m.photo_url} size={36} />
                    <span className="dock-item-body">
                      <span className="dock-item-title">
                        {m.auteur}
                        {m.conversation && <span className="dock-item-conv"> · {m.conversation}</span>}
                      </span>
                      <span className="dock-item-text">{m.contenu}</span>
                      <span className="dock-item-meta">{ilya(m.created_at, now)}</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
          <footer className="dock-panel-foot">
            <button type="button" className="dock-cta" onClick={() => { closePanel(); navigate('/discussion'); }}>
              Ouvrir la discussion
            </button>
          </footer>
        </section>
      )}
    </>
  );
}
