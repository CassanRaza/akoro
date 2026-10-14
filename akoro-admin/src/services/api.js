import axios from 'axios';

const api = axios.create({
  baseURL: 'http://127.0.0.1:8000/api',
});

// Ajoute automatiquement le token à chaque requête, s'il existe
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('akoro_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Session expirée ou compte désactivé : retour à la page de connexion
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const onPublicPage = ['/login', '/register'].includes(window.location.pathname);

    if (error.response?.status === 401 && !onPublicPage) {
      localStorage.removeItem('akoro_token');
      localStorage.removeItem('akoro_user');
      window.location.href = '/login';
    }

    return Promise.reject(error);
  }
);

export default api;