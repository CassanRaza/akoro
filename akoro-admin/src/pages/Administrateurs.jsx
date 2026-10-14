import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Modal from '../components/Modal';
import Spinner from '../components/Spinner';
import useConfirmation from '../components/useConfirmation';
import { CHOIX_ROLES, ROLE_DESCRIPTIONS, can, getStoredUser, roleLabel } from '../utils/permissions';
import './Beneficiaires.css';
import './BeneficiairesExtra.css';
import './Parcours.css';
import './Administrateurs.css';

export default function Administrateurs() {
  const { confirm, confirmationDialog } = useConfirmation();
  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Fenêtre "Valider" / "Modifier le rôle"
  const [modal, setModal] = useState(null); // { admin, mode: 'valider' | 'role' }
  const [role, setRole] = useState('fabmanager');
  const [modalError, setModalError] = useState('');
  const [modalSaving, setModalSaving] = useState(false);

  const me = getStoredUser();
  const canManage = can.manageAdmins(me?.role);

  const load = () => {
    api.get('/administrateurs')
      .then((res) => setAdmins(res.data))
      .catch((err) => setError(err.response?.data?.message || 'Erreur de chargement.'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    load();
  }, []);

  const openModal = (admin, mode) => {
    setModal({ admin, mode });
    setRole(CHOIX_ROLES.includes(admin.role) ? admin.role : 'fabmanager');
    setModalError('');
  };

  const closeModal = () => setModal(null);

  // Valide la demande (avec le rôle choisi) ou change simplement le rôle
  const submitRole = async (e) => {
    e.preventDefault();
    const action = modal.mode === 'valider' ? 'Valider le compte' : 'Modifier le rôle';
    if (!(await confirm({
      title: `${action} ?`,
      message: modal.mode === 'valider'
        ? `Le compte de ${modal.admin.name} sera activé avec le rôle ${roleLabel(role)}.`
        : `Le rôle de ${modal.admin.name} sera remplacé par ${roleLabel(role)}.`,
      confirmLabel: action,
      variant: 'info',
    }))) return;

    setModalSaving(true);
    setModalError('');

    try {
      const payload = modal.mode === 'valider' ? { role, actif: true } : { role };
      await api.put(`/administrateurs/${modal.admin.id}`, payload);
      setModal(null);
      load();
    } catch (err) {
      setModalError(
        err.response?.data?.errors?.role?.[0] || err.response?.data?.message || 'Erreur lors de la mise à jour.'
      );
    } finally {
      setModalSaving(false);
    }
  };

  const desactiver = async (a) => {
    if (!(await confirm({
      title: 'Désactiver cet accès ?',
      message: `L'accès de ${a.name} à l'administration sera désactivé.`,
      confirmLabel: 'Désactiver',
      variant: 'warning',
    }))) return;
    setError('');
    try {
      await api.put(`/administrateurs/${a.id}`, { actif: false });
      load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur lors de la mise à jour.');
    }
  };

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Administrateurs</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        Valider les demandes d'inscription, attribuer les rôles et gérer les accès des administrateurs
      </p>

      {!canManage && (
        <p
          style={{
            background: 'var(--accent-soft)',
            color: 'var(--teal)',
            padding: '10px 14px',
            borderRadius: 8,
            fontSize: 13,
            marginTop: 16,
          }}
        >
          Seul un Super Admin peut valider, désactiver un administrateur ou changer son rôle.
        </p>
      )}

      {error && <p style={{ color: 'var(--error-text)', marginTop: 16 }}>{error}</p>}

      <div className="bene-table-wrap" style={{ marginTop: 24 }}>
        <table className="bene-table">
          <thead>
            <tr>
              <th>Administrateur</th>
              <th>Email</th>
              <th>Rôle</th>
              <th>Statut</th>
              <th>Date de demande</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6}>
                  <div className="table-loader"><Spinner size={30} /></div>
                </td>
              </tr>
            ) : admins.length === 0 ? (
              <tr><td colSpan={6}>Aucun administrateur.</td></tr>
            ) : (
              admins.map((a) => (
                <tr key={a.id}>
                  <td>
                    <div className="bene-name-cell">
                      <Avatar name={a.name} url={a.photo_url} size={36} />
                      <span>{a.name}</span>
                    </div>
                  </td>
                  <td>{a.email}</td>
                  <td><span className="adm-role-badge">{roleLabel(a.role)}</span></td>
                  <td>
                    <span className={`bene-badge ${a.actif ? 'bene-badge-actif' : 'bene-badge-inactif'}`}>
                      {a.actif ? 'Actif' : 'En attente'}
                    </span>
                  </td>
                  <td>{new Date(a.created_at).toLocaleDateString('fr-FR')}</td>
                  <td>
                    <div className="bene-actions">
                      <Link className="bene-action bene-view" to={`/administrateurs/${a.id}`}>
                        Voir
                      </Link>

                      {canManage && a.id !== me?.id && (
                        a.actif ? (
                          <>
                            {a.role !== 'admin_global' && (
                              <button className="bene-action" onClick={() => openModal(a, 'role')}>
                                Modifier le rôle
                              </button>
                            )}
                            <button className="bene-action" onClick={() => desactiver(a)}>
                              Désactiver
                            </button>
                          </>
                        ) : (
                          <button className="bene-action bene-view" onClick={() => openModal(a, 'valider')}>
                            Valider
                          </button>
                        )
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <Modal
        open={!!modal}
        title={modal?.mode === 'valider' ? "Valider l'administrateur" : 'Modifier le rôle'}
        onClose={closeModal}
      >
        {modal && (
          <form onSubmit={submitRole} noValidate>
            <p style={{ margin: '0 0 14px', color: 'var(--text-muted)', fontSize: 14 }}>
              {modal.admin.name} — rôle demandé : {roleLabel(modal.admin.role)}
            </p>

            <label className="adm-form-label">Rôle attribué</label>
            <select className="adm-select" value={role} onChange={(e) => setRole(e.target.value)}>
              {CHOIX_ROLES.map((r) => (
                <option key={r} value={r}>{roleLabel(r)}</option>
              ))}
            </select>
            <p className="adm-role-desc">{ROLE_DESCRIPTIONS[role]}</p>

            {modalError && <p className="adm-error">{modalError}</p>}

            <div className="modal-actions">
              <button type="submit" className="parcours-add" disabled={modalSaving}>
                {modalSaving ? <Spinner size={16} light /> : null}
                {modal.mode === 'valider' ? 'Valider le compte' : 'Enregistrer'}
              </button>
              <button type="button" className="bene-action" onClick={closeModal}>Annuler</button>
            </div>
          </form>
        )}
      </Modal>
      {confirmationDialog}
    </Layout>
  );
}