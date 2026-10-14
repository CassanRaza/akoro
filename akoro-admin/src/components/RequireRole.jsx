import { Navigate } from 'react-router-dom';
import { can, getStoredUser, homePath } from '../utils/permissions';

// Protège une page : non connecté ou non admin → connexion ; rôle sans droit → page d'accueil du rôle
export default function RequireRole({ allow, children }) {
  const user = getStoredUser();
  const token = localStorage.getItem('akoro_token');

  if (!user || !token || !can.isAdmin(user.role)) {
    return <Navigate to="/login" replace />;
  }

  if (allow && !can[allow](user.role)) {
    return <Navigate to={homePath(user.role)} replace />;
  }

  return children;
}

// Renvoie vers la page d'accueil du rôle (pages inconnues)
export function HomeRedirect() {
  const user = getStoredUser();
  return <Navigate to={homePath(user?.role)} replace />;
}