import { useEffect, useState } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner from '../components/Spinner';
import { ActionIconButton, ActionIconLink } from '../components/ActionIcon';
import useToast from '../components/useToast';
import useConfirmation from '../components/useConfirmation';
import { typeSearch } from '../utils/validators';
import { can, getStoredUser } from '../utils/permissions';
import './Beneficiaires.css';
import './BeneficiairesExtra.css';

export default function Beneficiaires() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();
  const [data, setData] = useState({ data: [], current_page: 1, last_page: 1, total: 0 });
  const [parcoursList, setParcoursList] = useState([]);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [parcoursFilter, setParcoursFilter] = useState('');
  const [statutFilter, setStatutFilter] = useState('');
  const [page, setPage] = useState(1);
  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');

  const role = getStoredUser()?.role;
  const showVoir = can.beneficiaireDetail(role);
  // Seul le Super Admin valide une nouvelle inscription (faite depuis l'application mobile)
  const peutValider = role === 'admin_global';
  // Le formateur et le gérant consultent les fiches sans activer ni désactiver les comptes
  const peutGerer = can.manageBeneficiaires(role);
  const afficheActions = showVoir || peutGerer;
  const nbColonnes = afficheActions ? 6 : 5;

  const load = () => {
    setRefreshing(true);
    api.get('/beneficiaires', {
      params: {
        search: search || undefined,
        parcours_id: parcoursFilter || undefined,
        statut: statutFilter || undefined,
        page,
      },
    })
      .then((res) => setData(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Erreur de chargement.'))
      .finally(() => {
        setInitialLoading(false);
        setRefreshing(false);
      });
  };

  useEffect(() => {
    api.get('/parcours').then((res) => setParcoursList(res.data));
  }, []);

  // Attend la fin de la frappe avant de lancer la recherche
  useEffect(() => {
    const timer = setTimeout(() => {
      setPage(1);
      setSearch(searchInput.trim());
    }, 350);
    return () => clearTimeout(timer);
  }, [searchInput]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, parcoursFilter, statutFilter, page]);

  const toggleActif = async (b) => {
    const action = b.en_attente ? 'Valider' : b.actif ? 'Désactiver' : 'Activer';
    if (!(await confirm({
      title: b.en_attente ? 'Valider cette inscription ?' : `Confirmer : ${action.toLowerCase()} le compte ?`,
      message: b.en_attente
        ? `${b.name} (${b.parcours?.nom || 'sans parcours'}) pourra se connecter à l'application mobile.`
        : `Le compte de ${b.name} sera ${b.actif ? 'désactivé' : 'activé'}.`,
      confirmLabel: action,
      variant: b.actif ? 'warning' : 'info',
    }))) return;
    setError('');
    try {
      await api.put(`/beneficiaires/${b.id}`, { actif: !b.actif });
      showToast(b.en_attente ? 'Inscription validée : le compte est actif.'
        : b.actif ? 'Compte désactivé avec succès.' : 'Compte activé avec succès.');
      load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la mise à jour.');
    }
  };

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Bénéficiaires</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        {peutGerer
          ? 'Gérer les profils et inscriptions des participants du FabLab'
          : 'Consulter les participants du FabLab'}
      </p>

      <div className="bene-toolbar" style={{ alignItems: 'center' }}>
        <input
          className="bene-search"
          placeholder="Rechercher par nom, email..."
          value={searchInput}
          onChange={(e) => setSearchInput(typeSearch(e.target.value))}
          maxLength={100}
        />
        <select
          className="bene-filter"
          value={parcoursFilter}
          onChange={(e) => { setPage(1); setParcoursFilter(e.target.value); }}
        >
          <option value="">Parcours : Tous</option>
          {parcoursList.map((p) => (
            <option key={p.id} value={p.id}>{p.nom}</option>
          ))}
        </select>
        <select
          className="bene-filter"
          value={statutFilter}
          onChange={(e) => { setPage(1); setStatutFilter(e.target.value); }}
          aria-label="Statut"
        >
          <option value="">Statut : Tous</option>
          <option value="en_attente">En attente de validation</option>
        </select>
        {refreshing && !initialLoading && <Spinner size={20} />}
      </div>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="bene-table-wrap">
        <table className="bene-table" style={{ opacity: refreshing && !initialLoading ? 0.65 : 1 }}>
          <thead>
            <tr>
              <th>Nom</th>
              <th>Email</th>
              <th>Parcours</th>
              <th>Statut</th>
              <th>Date d'inscription</th>
              {afficheActions && <th>Actions</th>}
            </tr>
          </thead>
          <tbody>
            {initialLoading ? (
              <tr>
                <td colSpan={nbColonnes}>
                  <div className="table-loader"><Spinner size={30} /></div>
                </td>
              </tr>
            ) : data.data.length === 0 ? (
              <tr><td colSpan={nbColonnes}>Aucun bénéficiaire trouvé.</td></tr>
            ) : (
              data.data.map((b) => (
                <tr key={b.id}>
                  <td>
                    <div className="bene-name-cell">
                      <Avatar name={b.name} url={b.photo_url} size={36} />
                      <span>{b.name}</span>
                    </div>
                  </td>
                  <td>{b.email}</td>
                  <td>{b.parcours?.nom || '—'}</td>
                  <td>
                    <span className={`bene-badge ${b.en_attente ? 'bene-badge-attente' : b.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                      {b.en_attente ? 'En attente' : b.actif ? 'Actif' : 'Inactif'}
                    </span>
                  </td>
                  <td>{new Date(b.created_at).toLocaleDateString('fr-FR')}</td>
                  {afficheActions && (
                    <td>
                      <div className="bene-actions">
                        {showVoir && (
                          <ActionIconLink
                            icon="eye"
                            label="Voir"
                            className="bene-action bene-view"
                            to={`/beneficiaires/${b.id}`}
                          />
                        )}
                        {b.en_attente ? (
                          peutValider && (
                            <ActionIconButton
                              icon="check"
                              label="Valider l'inscription"
                              className="bene-action bene-validate"
                              onClick={() => toggleActif(b)}
                            />
                          )
                        ) : (
                          peutGerer && (
                            <ActionIconButton
                              icon="power"
                              label={b.actif ? 'Désactiver' : 'Activer'}
                              className="bene-action"
                              onClick={() => toggleActif(b)}
                            />
                          )
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data.last_page > 1 && (
        <div className="bene-pagination">
          <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Précédent</button>
          <span>Page {data.current_page} / {data.last_page} — {data.total} bénéficiaires</span>
          <button disabled={page >= data.last_page} onClick={() => setPage((p) => p + 1)}>Suivant</button>
        </div>
      )}
      {confirmationDialog}
    </Layout>
  );
}