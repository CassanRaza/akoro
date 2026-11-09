import { useCallback, useEffect, useState } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Modal from '../components/Modal';
import Spinner, { PageLoader } from '../components/Spinner';
import { HBarChart } from '../components/Charts';
import useToast from '../components/useToast';
import useConfirmation from '../components/useConfirmation';
import FabiaChat, { Spark } from '../components/FabiaChat';
import { getStoredUser } from '../utils/permissions';
import './Fabia.css';

const FICHE_VIDE = {
  categorie: 'presentation',
  titre: '',
  contenu: '',
  questions_types: '',
  mots_cles: '',
  a_valider: false,
  actif: true,
};

export default function Fabia() {
  const showToast = useToast();
  const { confirm, confirmationDialog } = useConfirmation();
  const [user] = useState(getStoredUser);
  const estGlobal = user?.role === 'admin_global';

  // Base de connaissances
  const [base, setBase] = useState(null); // { categories, connaissances, statistiques }
  const [erreur, setErreur] = useState(null);
  const [filtreCat, setFiltreCat] = useState('');
  const [filtreTexte, setFiltreTexte] = useState('');
  const [seulementACompleter, setSeulementACompleter] = useState(false);
  const [edition, setEdition] = useState(null); // fiche en cours (avec id = modification)
  const [erreursForm, setErreursForm] = useState({});
  const [enregistrement, setEnregistrement] = useState(false);

  const chargerBase = useCallback(async () => {
    try {
      const res = await api.get('/fabia/connaissances');
      setBase(res.data);
      setErreur(null);
    } catch (err) {
      setErreur(err.response?.data?.message || 'Impossible de charger la base de connaissances.');
    }
  }, []);

  useEffect(() => {
    api.get('/fabia/connaissances')
      .then((res) => setBase(res.data))
      .catch((err) => setErreur(err.response?.data?.message || 'Impossible de charger la base de connaissances.'));
  }, []);

  // ---------- Fiches ----------
  const peutModifier = (f) => f.etablissement_id !== null || estGlobal;

  const ouvrirFiche = (f) => {
    setErreursForm({});
    setEdition(f ? { ...FICHE_VIDE, ...f, questions_types: f.questions_types || '', mots_cles: f.mots_cles || '' } : { ...FICHE_VIDE, categorie: filtreCat || 'presentation' });
  };

  const enregistrerFiche = async (e) => {
    e.preventDefault();
    setEnregistrement(true);
    setErreursForm({});
    const donnees = {
      categorie: edition.categorie,
      titre: edition.titre.trim(),
      contenu: edition.contenu.trim(),
      questions_types: edition.questions_types.trim() || null,
      mots_cles: edition.mots_cles.trim() || null,
      a_valider: edition.a_valider,
      actif: edition.actif,
    };
    try {
      if (edition.id) await api.put(`/fabia/connaissances/${edition.id}`, donnees);
      else await api.post('/fabia/connaissances', donnees);
      showToast(edition.id ? 'Fiche mise à jour.' : 'Fiche ajoutée à la base.');
      setEdition(null);
      chargerBase();
    } catch (err) {
      const erreurs = err.response?.data?.errors;
      if (erreurs) setErreursForm(Object.fromEntries(Object.entries(erreurs).map(([k, v]) => [k, v[0]])));
      else showToast(err.response?.data?.message || 'Enregistrement impossible.');
    } finally {
      setEnregistrement(false);
    }
  };

  const basculerActif = async (f) => {
    try {
      await api.put(`/fabia/connaissances/${f.id}`, {
        categorie: f.categorie, titre: f.titre, contenu: f.contenu,
        questions_types: f.questions_types, mots_cles: f.mots_cles,
        a_valider: f.a_valider, actif: !f.actif,
      });
      chargerBase();
    } catch (err) {
      showToast(err.response?.data?.message || 'Modification impossible.');
    }
  };

  const supprimerFiche = async (f) => {
    const ok = await confirm({
      title: 'Supprimer cette fiche ?',
      message: `« ${f.titre} » sera retirée de la base de FAB’IA. Pour la masquer temporairement, désactivez-la plutôt.`,
      confirmLabel: 'Supprimer',
      variant: 'danger',
    });
    if (!ok) return;
    try {
      await api.delete(`/fabia/connaissances/${f.id}`);
      showToast('Fiche supprimée.');
      chargerBase();
    } catch (err) {
      showToast(err.response?.data?.message || 'Suppression impossible.');
    }
  };

  if (!base && !erreur) {
    return <Layout><PageLoader /></Layout>;
  }

  const categories = base?.categories || [];
  const libelleCat = Object.fromEntries(categories.map((c) => [c.code, c.label]));
  const stats = base?.statistiques;
  const recherche = filtreTexte.trim().toLowerCase();
  const fiches = (base?.connaissances || []).filter((f) =>
    (!filtreCat || f.categorie === filtreCat)
    && (!seulementACompleter || f.a_valider)
    && (!recherche || `${f.titre} ${f.contenu} ${f.mots_cles || ''}`.toLowerCase().includes(recherche))
  );
  const nbACompleter = (base?.connaissances || []).filter((f) => f.a_valider && f.actif).length;

  return (
    <Layout>
      <header className="fab-hero">
        <span className="fab-hero-icon"><Spark size={26} /></span>
        <div>
          <h1>FAB’IA</h1>
          <p>L’assistant du FabLab répond aux bénéficiaires à partir de cette base de connaissances. Testez-le et tenez les fiches à jour.</p>
        </div>
      </header>

      {erreur && <div className="fab-error">{erreur}</div>}

      {stats && (
        <div className="fab-kpis">
          <div className="fab-kpi"><strong>{stats.questions_periode}</strong><span>questions · 30 jours</span></div>
          <div className="fab-kpi"><strong>{stats.utilisateurs_periode}</strong><span>utilisateurs · 30 jours</span></div>
          <div className="fab-kpi"><strong>{stats.hors_ligne_periode}</strong><span>réponses hors ligne</span></div>
          <button type="button" className={`fab-kpi fab-kpi-btn${stats.a_completer ? ' is-warn' : ''}`} onClick={() => { setSeulementACompleter(true); setFiltreCat(''); }}>
            <strong>{stats.a_completer}</strong><span>fiches à compléter</span>
          </button>
        </div>
      )}

      <div className="fab-grid">
        {/* ---------- Tester FAB'IA ---------- */}
        <section className="fab-card fab-chat">
          <header className="fab-card-head">
            <div>
              <h2>Tester FAB’IA</h2>
              <p>Posez une question comme le ferait un bénéficiaire.</p>
            </div>
          </header>
          <FabiaChat />
        </section>

        {/* ---------- Statistiques ---------- */}
        <section className="fab-card">
          <header className="fab-card-head">
            <div>
              <h2>Questions fréquentes</h2>
              <p>Sur les 90 derniers jours</p>
            </div>
          </header>
          {!stats || stats.frequentes.length === 0 ? (
            <p className="fab-empty">Aucune question posée pour l’instant.</p>
          ) : (
            <ol className="fab-freq">
              {stats.frequentes.map((q) => (
                <li key={q.question}>
                  <span>{q.question}</span>
                  <span className="fab-freq-count">{q.total}</span>
                </li>
              ))}
            </ol>
          )}

          <h3 className="fab-h3">Thèmes abordés · 30 jours</h3>
          {stats?.par_categorie?.length ? (
            <HBarChart
              items={stats.par_categorie.map((c) => ({ id: c.categorie, label: c.categorie, value: c.total, detail: `${c.total} question(s)` }))}
            />
          ) : (
            <p className="fab-empty">Pas encore de données.</p>
          )}
          <p className="fab-hint">
            Les réponses « hors ligne » sont données sans IA (clé OpenAI absente, quota ou réseau) :
            FAB’IA cite alors directement les fiches les plus proches.
          </p>
        </section>
      </div>

      {/* ---------- Base de connaissances ---------- */}
      <section className="fab-card fab-base">
        <header className="fab-card-head">
          <div>
            <h2>Base de connaissances</h2>
            <p>{base?.connaissances?.length || 0} fiche(s){nbACompleter > 0 && ` · ${nbACompleter} à compléter`}</p>
          </div>
          <button type="button" className="parcours-add" onClick={() => ouvrirFiche(null)}>+ Nouvelle fiche</button>
        </header>

        <div className="fab-filters">
          <input
            type="search"
            className="fab-input"
            placeholder="Rechercher dans les fiches…"
            value={filtreTexte}
            onChange={(e) => setFiltreTexte(e.target.value)}
          />
          <select className="fab-input" value={filtreCat} onChange={(e) => setFiltreCat(e.target.value)} aria-label="Catégorie">
            <option value="">Toutes les catégories</option>
            {categories.map((c) => <option key={c.code} value={c.code}>{c.label}</option>)}
          </select>
          <label className="fab-check">
            <input type="checkbox" checked={seulementACompleter} onChange={(e) => setSeulementACompleter(e.target.checked)} />
            À compléter uniquement
          </label>
        </div>

        {fiches.length === 0 ? (
          <p className="fab-empty">Aucune fiche ne correspond.</p>
        ) : (
          <div className="fab-fiches">
            {fiches.map((f) => (
              <article key={f.id} className={`fab-fiche${f.actif ? '' : ' is-off'}`}>
                <div className="fab-fiche-top">
                  <span className="fab-tag">{libelleCat[f.categorie] || f.categorie}</span>
                  {f.a_valider && <span className="fab-tag fab-tag-warn">À compléter</span>}
                  {!f.actif && <span className="fab-tag fab-tag-off">Désactivée</span>}
                  {f.etablissement_id === null && <span className="fab-tag fab-tag-common">Commune</span>}
                </div>
                <h3>{f.titre}</h3>
                <p className="fab-fiche-content">{f.contenu}</p>
                {f.questions_types && <p className="fab-fiche-q">{f.questions_types.split('|').map((q) => q.trim()).filter(Boolean).join(' · ')}</p>}
                {peutModifier(f) ? (
                  <div className="fab-fiche-actions">
                    <button type="button" className="bene-filter" onClick={() => ouvrirFiche(f)}>Modifier</button>
                    <button type="button" className="bene-filter" onClick={() => basculerActif(f)}>{f.actif ? 'Désactiver' : 'Activer'}</button>
                    <button type="button" className="bene-filter fab-danger" onClick={() => supprimerFiche(f)}>Supprimer</button>
                  </div>
                ) : (
                  <p className="fab-hint">Fiche commune à tous les FabLabs : modifiable par le super administrateur.</p>
                )}
              </article>
            ))}
          </div>
        )}
      </section>

      {/* ---------- Formulaire fiche ---------- */}
      <Modal open={!!edition} title={edition?.id ? 'Modifier la fiche' : 'Nouvelle fiche'} onClose={() => setEdition(null)} className="fab-modal">
        {edition && (
          <form className="fab-form" onSubmit={enregistrerFiche}>
            <label>
              Catégorie
              <select className="fab-input" value={edition.categorie} onChange={(e) => setEdition({ ...edition, categorie: e.target.value })}>
                {categories.map((c) => <option key={c.code} value={c.code}>{c.label}</option>)}
              </select>
              {erreursForm.categorie && <span className="field-error">{erreursForm.categorie}</span>}
            </label>
            <label>
              Titre
              <input className="fab-input" value={edition.titre} maxLength={255} onChange={(e) => setEdition({ ...edition, titre: e.target.value })} required />
              {erreursForm.titre && <span className="field-error">{erreursForm.titre}</span>}
            </label>
            <label>
              Contenu <small>(ce que FAB’IA doit savoir)</small>
              <textarea className="fab-input" rows={7} value={edition.contenu} maxLength={5000} onChange={(e) => setEdition({ ...edition, contenu: e.target.value })} required />
              {erreursForm.contenu && <span className="field-error">{erreursForm.contenu}</span>}
            </label>
            <label>
              Questions types <small>(séparées par « | »)</small>
              <input className="fab-input" value={edition.questions_types} maxLength={500} placeholder="Où se trouve le FabLab ? | Comment venir ?" onChange={(e) => setEdition({ ...edition, questions_types: e.target.value })} />
            </label>
            <label>
              Mots-clés <small>(séparés par des virgules, utilisés en mode hors ligne)</small>
              <input className="fab-input" value={edition.mots_cles} maxLength={500} onChange={(e) => setEdition({ ...edition, mots_cles: e.target.value })} />
            </label>
            <div className="fab-form-checks">
              <label className="fab-check">
                <input type="checkbox" checked={edition.a_valider} onChange={(e) => setEdition({ ...edition, a_valider: e.target.checked })} />
                Information incomplète ou à confirmer
              </label>
              <label className="fab-check">
                <input type="checkbox" checked={edition.actif} onChange={(e) => setEdition({ ...edition, actif: e.target.checked })} />
                Fiche active
              </label>
            </div>
            <div className="fab-form-actions">
              <button type="button" className="bene-filter" onClick={() => setEdition(null)}>Annuler</button>
              <button type="submit" className="parcours-add" disabled={enregistrement}>
                {enregistrement ? <Spinner size={16} light /> : 'Enregistrer'}
              </button>
            </div>
          </form>
        )}
      </Modal>

      {confirmationDialog}
    </Layout>
  );
}
