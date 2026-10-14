import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import { PageLoader } from '../components/Spinner';

export default function Dashboard() {
  const [user, setUser] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    api.get('/user')
      .then((res) => setUser(res.data))
      .catch(() => navigate('/login'));
  }, []);

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