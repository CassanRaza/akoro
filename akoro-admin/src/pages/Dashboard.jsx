import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getStoredUser } from '../utils/permissions';
import Layout from '../components/Layout';
import { PageLoader } from '../components/Spinner';

export default function Dashboard() {
  // Profil déjà en mémoire depuis la connexion : affichage immédiat
  const [user] = useState(getStoredUser);
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) navigate('/login');
  }, [user, navigate]);

  if (!user) return <PageLoader fullscreen />;

  return (
    <Layout>
      <h1 style={{ margin: 0, fontSize: 24 }}>Tableau de bord</h1>
      <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
        Suivi général des activités et statistiques du FabLab
      </p>
      <p style={{ marginTop: 24 }}>
        Bonjour {user.name}  (établissement #{user.etablissement_id})
      </p>
    </Layout>
  );
}