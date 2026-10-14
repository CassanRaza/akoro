import { useEffect, useState } from 'react';
import api from '../services/api';
import Layout from '../components/Layout';
import Spinner from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { ActionIconButton, ActionIconLink } from '../components/ActionIcon';
import { typeLabel, checkLabel } from '../utils/validators';
import './Beneficiaires.css';
import './Parcours.css';

export default function Parcours() {
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();
  const [parcours, setParcours] = useState([]);
  const [nom, setNom] = useState('');
  const [description, setDescription] = useState('');
  const [fieldErrors, setFieldErrors] = useState({ nom: '', description: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const loadParcours = () => {
    api.get('/parcours')
      .then((res) => setParcours(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Erreur de chargement.'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadParcours();
  }, []);

  const handleCreate = async (e) => {
    e.preventDefault();
    setError('');

    const errors = {
      nom: checkLabel(nom),
      description: description.length > 500 ? 'La description est trop longue (500 caractères maximum).' : '',
    };
    setFieldErrors(errors);
    if (errors.nom || errors.description) return;

    if (!(await confirm({
      title: 'Ajouter ce parcours ?',
      message: `Le parcours « ${nom.trim()} » sera créé.`,
      confirmLabel: 'Ajouter',
      variant: 'info',
    }))) return;

    setSaving(true);
    try {
      await api.post('/parcours', { nom: nom.trim(), description: description.trim() });
      setNom('');
      setDescription('');
      showToast('Parcours ajouté avec succès.');
      loadParcours();
    } catch (err) {
      const serverErrors = err.response?.data?.errors;
      if (serverErrors) {
        setFieldErrors({
          nom: serverErrors.nom?.[0] || '',
          description: serverErrors.description?.[0] || '',
        });
      } else {
        setError(err.response?.data?.message || 'Erreur lors de la création.');
      }
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (p) => {
    const message = p.lecons_count > 0
      ? `Supprimer ce parcours ? Ses ${p.lecons_count} leçon(s) et leurs documents seront aussi supprimés.`
      : 'Supprimer ce parcours ?';
    if (!(await confirm({
      title: 'Supprimer ce parcours ?',
      message,
      confirmLabel: 'Supprimer',
      variant: 'danger',
    }))) return;

    setError('');
    try {
      await api.delete(`/parcours/${p.id}`);
      showToast('Parcours supprimé avec succès.');
      loadParcours();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la suppression.');
    }
  };

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Parcours & Leçons</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        Gérer la structure des formations, modules et cours du FabLab
      </p>

      <form onSubmit={handleCreate} className="parcours-form" noValidate>
        <div className="parcours-field">
          <input
            className="bene-search"
            placeholder="Nom du parcours"
            value={nom}
            onChange={(e) => {
              setNom(typeLabel(e.target.value));
              setFieldErrors((f) => ({ ...f, nom: '' }));
            }}
            maxLength={100}
          />
          {fieldErrors.nom && <span className="parcours-field-error">{fieldErrors.nom}</span>}
        </div>

        <div className="parcours-field">
          <input
            className="bene-search"
            placeholder="Description"
            value={description}
            onChange={(e) => {
              setDescription(e.target.value.replace(/^\s+/, '').replace(/\s{2,}/g, ' '));
              setFieldErrors((f) => ({ ...f, description: '' }));
            }}
            maxLength={500}
          />
          {fieldErrors.description && (
            <span className="parcours-field-error">{fieldErrors.description}</span>
          )}
        </div>

        <button type="submit" className="parcours-add" disabled={saving}>
          {saving ? <Spinner size={16} light /> : null}
          Ajouter
        </button>
      </form>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="bene-table-wrap">
        <table className="bene-table">
          <thead>
            <tr>
              <th>Nom</th>
              <th>Description</th>
              <th>Leçons</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={4}>
                  <div className="table-loader"><Spinner size={30} /></div>
                </td>
              </tr>
            ) : parcours.length === 0 ? (
              <tr><td colSpan={4}>Aucun parcours pour le moment.</td></tr>
            ) : (
              parcours.map((p) => (
                <tr key={p.id}>
                  <td><strong>{p.nom}</strong></td>
                  <td>{p.description || 'Sans description'}</td>
                  <td>{p.lecons_count} leçon{p.lecons_count > 1 ? 's' : ''}</td>
                  <td>
                    <div className="parcours-actions">
                      <ActionIconLink
                        icon="eye"
                        label="Visionner"
                        className="bene-action parcours-view"
                        to={`/parcours/${p.id}`}
                      />
                      <ActionIconLink
                        icon="plus"
                        label="Ajouter une leçon"
                        className="bene-action"
                        to={`/parcours/${p.id}?ajout=1`}
                      />
                      <ActionIconButton
                        icon="trash"
                        label="Supprimer"
                        className="bene-action parcours-delete"
                        onClick={() => handleDelete(p)}
                      />
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {confirmationDialog}
    </Layout>
  );
}