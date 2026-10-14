import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import { typeSearch } from '../utils/validators';
import { can, getStoredUser } from '../utils/permissions';
import './Beneficiaires.css';
import './BeneficiairesExtra.css';

export default function Beneficiaires() {
  const { confirm, confirmationDialog } = useConfirmation();
  const [data, setData] = useState({ data: [], current_page: 1, last_page: 1, total: 0 });
  const [parcoursList, setParcoursList] = useState([]);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [parcoursFilter, setParcoursFilter] = useState('');
  const [page, setPage] = useState(1);
  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');

  const showVoir = can.beneficiaireDetail(getStoredUser()?.role);

  const load = () => {
    setRefreshing(true);
    api.get('/beneficiaires', {
      params: {
        search: search || undefined,
        parcours_id: parcoursFilter || undefined,
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
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, parcoursFilter, page]);

  const toggleActif = async (b) => {
    const action = b.actif ? 'Désactiver' : 'Activer';
    if (!(await confirm({
      title: `Confirmer : ${action.toLowerCase()} le compte ?`,
      message: `Le compte de ${b.name} sera ${b.actif ? 'désactivé' : 'activé'}.`,
      confirmLabel: action,
      variant: b.actif ? 'warning' : 'info',
    }))) return;
    setError('');
    try {
      await api.put(`/beneficiaires/${b.id}`, { actif: !b.actif });
      load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la mise à jour.');
    }
  };

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Bénéficiaires</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        Gérer les profils et inscriptions des participants du FabLab
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
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {initialLoading ? (
              <tr>
                <td colSpan={6}>
                  <div className="table-loader"><Spinner size={30} /></div>
                </td>
              </tr>
            ) : data.data.length === 0 ? (
              <tr><td colSpan={6}>Aucun bénéficiaire trouvé.</td></tr>
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
                    <span className={`bene-badge ${b.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                      {b.actif ? 'Actif' : 'Inactif'}
                    </span>
                  </td>
                  <td>{new Date(b.created_at).toLocaleDateString('fr-FR')}</td>
                  <td>
                    <div className="bene-actions">
                      {showVoir && (
                        <Link className="bene-action bene-view" to={`/beneficiaires/${b.id}`}>
                          Voir
                        </Link>
                      )}
                      <button className="bene-action" onClick={() => toggleActif(b)}>
                        {b.actif ? 'Désactiver' : 'Activer'}
                      </button>
                    </div>
                  </td>
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