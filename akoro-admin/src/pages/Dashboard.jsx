import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import { PageLoader } from '../components/Spinner';
import { ColumnChart, HBarChart, LineChart } from '../components/Charts';
import { getStoredUser, roleLabel } from '../utils/permissions';
import './Dashboard.css';

// ---------- Formatage ----------
const fmtDate = (v, opts = { day: 'numeric', month: 'short' }) =>
  v ? new Date(v.length === 10 ? `${v}T00:00:00` : v).toLocaleDateString('fr-FR', opts) : '—';
const fmtDateHeure = (v) =>
  v ? new Date(v).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';
const fmtPct = (v) => (v === null || v === undefined ? '—' : `${v} %`);

const STATUT_POINTAGE = {
  absent: { label: 'Absent', className: 'db-pill-absent' },
  present: { label: 'Présent', className: 'db-pill-present' },
  parti: { label: 'Reparti', className: 'db-pill-parti' },
};

const RACCOURCIS = [
  { to: '/beneficiaires', label: 'Bénéficiaires', icon: 'users' },
  { to: '/parcours', label: 'Créer une leçon', icon: 'book' },
  { to: '/devoirs', label: 'Programmer un devoir', icon: 'task' },
  { to: '/absences', label: 'Absences', icon: 'calendar' },
  { to: '/discussion', label: 'Discussion', icon: 'chat' },
];

function Icon({ name, size = 20 }) {
  const p = {
    width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
    strokeWidth: 1.9, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true,
  };
  switch (name) {
    case 'users': return <svg {...p}><circle cx="9" cy="8" r="3.5" /><path d="M3 20v-1a6 6 0 0 1 12 0v1" /><path d="M16 5.5a3.5 3.5 0 0 1 0 6.8M18 14a5 5 0 0 1 3 4.5V20" /></svg>;
    case 'route': return <svg {...p}><circle cx="6" cy="19" r="2.5" /><circle cx="18" cy="5" r="2.5" /><path d="M8.5 19H17a3.5 3.5 0 0 0 0-7H7a3.5 3.5 0 0 1 0-7h8.5" /></svg>;
    case 'book': return <svg {...p}><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21z" /><path d="M4 5.5v13A2.5 2.5 0 0 1 6.5 16H20M8 7h8M8 10h6" /></svg>;
    case 'task': return <svg {...p}><path d="M8 4H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3" /><rect x="8" y="2" width="8" height="4" rx="1" /><path d="m8 13 2 2 5-5" /></svg>;
    case 'calendar': return <svg {...p}><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></svg>;
    case 'chat': return <svg {...p}><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12Z" /></svg>;
    case 'spark': return <svg {...p}><path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z" /><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z" /></svg>;
    case 'arrow': return <svg {...p}><path d="M5 12h14M13 6l6 6-6 6" /></svg>;
    default: return null;
  }
}

// ---------- Petits blocs ----------
function Kpi({ label, value, sub, tone, icon, to }) {
  return (
    <Link to={to} className={`db-kpi tone-${tone}`}>
      <span className="db-kpi-icon"><Icon name={icon} size={22} /></span>
      <span className="db-kpi-body">
        <span className="db-kpi-value">{value}</span>
        <span className="db-kpi-label">{label}</span>
        {sub && <span className="db-kpi-sub">{sub}</span>}
      </span>
    </Link>
  );
}

function Card({ title, subtitle, action, children, className = '' }) {
  return (
    <section className={`db-card ${className}`}>
      <header className="db-card-head">
        <div>
          <h2>{title}</h2>
          {subtitle && <p className="db-card-sub">{subtitle}</p>}
        </div>
        {action}
      </header>
      {children}
    </section>
  );
}

const Empty = ({ children }) => <p className="db-empty">{children}</p>;
const Soon = ({ children }) => <p className="db-soon">{children}</p>;

// ---------- Page ----------
export default function Dashboard() {
  const [user] = useState(getStoredUser);
  const navigate = useNavigate();
  const [periode, setPeriode] = useState('semaine');
  const [etabId, setEtabId] = useState('');
  const [result, setResult] = useState(null); // { key, data } ou { key, error }
  const [maintenant] = useState(() => Date.now());

  const key = `${periode}|${etabId}`;
  const estGlobal = user?.role === 'admin_global';
  const nbJours = periode === 'mois' ? 30 : 7;

  useEffect(() => {
    if (!user) navigate('/login');
  }, [user, navigate]);

  useEffect(() => {
    let ignore = false;
    api.get('/dashboard', { params: { periode, etablissement_id: etabId || undefined } })
      .then((res) => !ignore && setResult({ key, data: res.data }))
      .catch((err) => !ignore && setResult({
        key,
        error: err.response?.data?.message || 'Impossible de charger le tableau de bord.',
      }));
    return () => { ignore = true; };
  }, [key, periode, etabId]);

  if (!user) return <PageLoader fullscreen />;

  const loading = result?.key !== key;
  const d = result?.data;
  const prenom = (user.name || '').split(' ').slice(-1)[0];
  const aujourdhui = new Date(maintenant).toLocaleDateString('fr-FR', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  });

  return (
    <Layout>
      {/* En-tête */}
      <header className="db-hero">
        <div className="db-hero-text">
          <span className="db-hero-date">{aujourdhui}</span>
          <h1>Bonjour {prenom} 👋</h1>
          <p>
            <span className="db-chip">{d?.etablissement?.nom || 'Établissement'}</span>
            <span className="db-hero-role">{roleLabel(user.role)}</span>
          </p>
        </div>
        <div className="db-filters">
          {estGlobal && d?.etablissements?.length > 0 && (
            <select
              className="db-select"
              value={etabId || d.etablissement?.id || ''}
              onChange={(e) => setEtabId(e.target.value)}
              aria-label="Établissement"
            >
              {d.etablissements.map((e) => (
                <option key={e.id} value={e.id}>{e.nom}</option>
              ))}
            </select>
          )}
          <div className="db-segmented" role="group" aria-label="Période">
            {[['semaine', '7 jours'], ['mois', '30 jours']].map(([code, label]) => (
              <button
                key={code}
                type="button"
                className={periode === code ? 'is-active' : ''}
                onClick={() => setPeriode(code)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </header>

      {result?.error && !loading && <div className="db-error">{result.error}</div>}
      {!d && loading && <PageLoader />}

      {d && (
        <div className={`db-content${loading ? ' is-loading' : ''}`}>
          {/* Indicateurs clés */}
          <div className="db-kpis">
            <Kpi
              label="Bénéficiaires"
              value={d.kpis.beneficiaires.total}
              sub={`${d.kpis.beneficiaires.actifs} actifs · ${d.kpis.beneficiaires.inactifs} inactifs`}
              tone="blue"
              icon="users"
              to="/beneficiaires"
            />
            <Kpi label="Parcours" value={d.kpis.parcours} sub="Filières de formation" tone="green" icon="route" to="/parcours" />
            <Kpi label="Leçons / formations" value={d.kpis.lecons} sub="Tous parcours confondus" tone="pink" icon="book" to="/parcours" />
            <Kpi label="Devoirs actifs" value={d.kpis.devoirs_actifs} sub="Programmés ou en cours" tone="amber" icon="task" to="/devoirs" />
          </div>

          <div className="db-grid">
            {/* Répartition par parcours */}
            <Card title="Bénéficiaires par parcours" subtitle="Effectifs, leçons, présence et résultats" className="db-span-2">
              <div className="db-split">
                <HBarChart
                  items={d.parcours.map((p) => ({
                    id: p.id,
                    label: p.nom,
                    value: p.beneficiaires,
                    detail: `${p.beneficiaires} bénéficiaire(s) · ${p.lecons} leçon(s)`,
                  }))}
                  emptyText="Aucun parcours"
                />
                <div className="db-table-wrap">
                  <table className="db-table">
                    <thead>
                      <tr>
                        <th>Parcours</th>
                        <th className="num">Bénéf.</th>
                        <th className="num">Leçons</th>
                        <th className="num">Présence</th>
                        <th className="num">Note moy.</th>
                      </tr>
                    </thead>
                    <tbody>
                      {d.parcours.map((p) => (
                        <tr key={p.id}>
                          <td><Link to={`/parcours/${p.id}`}>{p.nom}</Link></td>
                          <td className="num">{p.beneficiaires}</td>
                          <td className="num">{p.lecons}</td>
                          <td className="num">{fmtPct(p.taux_presence)}</td>
                          <td className="num">{fmtPct(p.note_moyenne)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </Card>

            {/* Présences */}
            <Card title="Taux de présence" subtitle={`${nbJours} derniers jours · séances terminées`} className="db-span-2">
              <LineChart points={d.presences.courbe} />
            </Card>

            <Card
              title="Pointages du jour"
              subtitle={d.presences.resume_jour.attendus
                ? `${d.presences.resume_jour.presents} présent(s) sur ${d.presences.resume_jour.attendus} attendu(s)`
                : 'Aucune séance prévue aujourd’hui'}
            >
              {d.presences.aujourdhui.length === 0 ? (
                <Empty>Aucun pointage pour l’instant.</Empty>
              ) : (
                <ul className="db-list db-list-scroll">
                  {d.presences.aujourdhui.map((p) => (
                    <li key={p.id}>
                      <div>
                        <Link to={`/beneficiaires/${p.id}`} className="db-strong">{p.name}</Link>
                        <div className="db-muted">
                          {p.parcours || 'Sans parcours'}
                          {p.heure_arrivee && ` · arrivé ${p.heure_arrivee}`}
                          {p.heure_depart && ` · reparti ${p.heure_depart}`}
                        </div>
                      </div>
                      <span className={`db-pill ${STATUT_POINTAGE[p.statut].className}`}>
                        {STATUT_POINTAGE[p.statut].label}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </Card>

            <Card title="Risque de décrochage" subtitle={`Absences non justifiées · ${nbJours} jours`}>
              {d.presences.plus_absents.length === 0 ? (
                <Empty>Aucune absence sur la période.</Empty>
              ) : (
                <ul className="db-list">
                  {d.presences.plus_absents.map((b) => (
                    <li key={b.id}>
                      <div>
                        <Link to={`/beneficiaires/${b.id}`} className="db-strong">{b.name}</Link>
                        <div className="db-muted">{b.parcours || 'Sans parcours'}</div>
                      </div>
                      <span className="db-count">{b.total}</span>
                    </li>
                  ))}
                </ul>
              )}
            </Card>

            {/* Devoirs */}
            <Card
              title="Devoirs"
              subtitle="En cours et programmés"
              action={<Link to="/devoirs" className="db-link">Tout voir <Icon name="arrow" size={14} /></Link>}
            >
              <h3 className="db-h3">En cours</h3>
              <DevoirsListe devoirs={d.devoirs.en_cours} vide="Aucun devoir en cours." maintenant={maintenant} />
              <h3 className="db-h3">Programmés</h3>
              <DevoirsListe devoirs={d.devoirs.a_venir} vide="Aucun devoir programmé." maintenant={maintenant} />
            </Card>

            <Card title="Réussite des derniers devoirs" subtitle={`Moyenne : ${fmtPct(d.devoirs.taux_reussite_moyen)}`}>
              {d.devoirs.derniers.length === 0 ? (
                <Empty>Aucun devoir terminé ou en cours.</Empty>
              ) : (
                <HBarChart
                  unit=" %"
                  items={d.devoirs.derniers.map((dv) => ({
                    id: dv.id,
                    label: dv.titre,
                    value: dv.taux_reussite ?? 0,
                    detail: dv.participants
                      ? `${dv.participants} résultat(s) · moyenne ${dv.moyenne} %`
                      : 'Aucun résultat pour l’instant',
                  }))}
                />
              )}
              <p className="db-hint">Réussi = au moins 50 % (QCM) ou 10/20 (rendu).</p>
            </Card>

            <Card title="Bénéficiaires en difficulté" subtitle="Moyenne inférieure à 50 %">
              {d.devoirs.en_difficulte.length === 0 ? (
                <Empty>Aucun bénéficiaire en difficulté.</Empty>
              ) : (
                <ul className="db-list">
                  {d.devoirs.en_difficulte.map((b) => (
                    <li key={b.id}>
                      <div>
                        <Link to={`/beneficiaires/${b.id}`} className="db-strong">{b.name}</Link>
                        <div className="db-muted">{b.parcours || 'Sans parcours'} · {b.evaluations} évaluation(s)</div>
                      </div>
                      <span className="db-count db-count-warn">{b.moyenne} %</span>
                    </li>
                  ))}
                </ul>
              )}
              <Soon>La progression par leçon arrivera avec la table « progressions ».</Soon>
            </Card>

            <Card title="Activité de messagerie" subtitle={`Messages échangés par jour · ${nbJours} jours`}>
              <ColumnChart points={d.activite_messages} />
            </Card>

            {/* Raccourcis */}
            <Card title="Raccourcis" subtitle="Actions fréquentes">
              <div className="db-shortcuts">
                {RACCOURCIS.map((r) => (
                  <Link key={r.label} to={r.to} className="db-shortcut">
                    <span className="db-shortcut-icon"><Icon name={r.icon} size={18} /></span>
                    {r.label}
                  </Link>
                ))}
              </div>
            </Card>

            {/* Assistant FAB'IA */}
            <Card
              title="Assistant FAB’IA"
              subtitle={`Questions posées · ${nbJours} jours`}
              action={<Link to="/fabia" className="db-link">Gérer <Icon name="arrow" size={14} /></Link>}
            >
              <div className="db-fabia">
                <span className="db-fabia-icon"><Icon name="spark" size={22} /></span>
                <div className="db-fabia-stats">
                  <span><strong>{d.fabia.questions_periode}</strong> question(s)</span>
                  <span><strong>{d.fabia.utilisateurs_periode}</strong> utilisateur(s)</span>
                  <span><strong>{d.fabia.questions_total}</strong> au total</span>
                </div>
              </div>
              <h3 className="db-h3">Questions fréquentes</h3>
              {d.fabia.frequentes.length === 0 ? (
                <Empty>Aucune question posée pour l’instant.</Empty>
              ) : (
                <ul className="db-list">
                  {d.fabia.frequentes.slice(0, 4).map((q) => (
                    <li key={q.question}>
                      <span className="db-fabia-q">{q.question}</span>
                      <span className="db-count">{q.total}</span>
                    </li>
                  ))}
                </ul>
              )}
              {d.fabia.a_completer > 0 && (
                <p className="db-hint">
                  <Link to="/fabia">{d.fabia.a_completer} fiche(s) de la base de connaissances à compléter.</Link>
                </p>
              )}
            </Card>

            {/* Vue comparée — Super Admin */}
            {d.comparaison && (
              <Card title="Comparaison des FabLabs" subtitle="Cliquez sur un FabLab pour l’afficher" className="db-span-2">
                <div className="db-table-wrap">
                  <table className="db-table">
                    <thead>
                      <tr>
                        <th>FabLab</th>
                        <th className="num">Bénéficiaires</th>
                        <th className="num">Administrateurs</th>
                        <th className="num">Présence ({nbJours} j)</th>
                      </tr>
                    </thead>
                    <tbody>
                      {d.comparaison.map((e) => (
                        <tr key={e.id} className={e.id === d.etablissement?.id ? 'is-current' : ''}>
                          <td>
                            <button type="button" className="db-linkbtn" onClick={() => setEtabId(String(e.id))}>
                              {e.nom}
                            </button>
                          </td>
                          <td className="num">{e.beneficiaires}</td>
                          <td className="num">{e.administrateurs}</td>
                          <td className="num">{fmtPct(e.taux_presence)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Card>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
}

function DevoirsListe({ devoirs, vide, maintenant }) {
  if (devoirs.length === 0) return <Empty>{vide}</Empty>;
  return (
    <ul className="db-list">
      {devoirs.map((dv) => {
        const depasse = dv.date_limite && new Date(dv.date_limite).getTime() < maintenant;
        return (
          <li key={dv.id}>
            <div>
              <Link to={`/devoirs/${dv.id}`} className="db-strong">{dv.titre}</Link>
              <div className="db-muted">
                {dv.parcours?.nom} · {dv.type === 'qcm' ? 'QCM' : 'Rendu'}
                {dv.date_debut && ` · début ${fmtDateHeure(dv.date_debut)}`}
              </div>
            </div>
            <span className={`db-tag${depasse ? ' db-tag-late' : ''}`}>
              {dv.date_limite ? `${depasse ? 'Échu ' : 'Limite '}${fmtDate(dv.date_limite)}` : 'Sans limite'}
            </span>
          </li>
        );
      })}
    </ul>
  );
}
