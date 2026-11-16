import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import RequireRole, { HomeRedirect } from './components/RequireRole';
import { ToastProvider } from './components/ToastProvider';
import { PageLoader } from './components/Spinner';
import Login from './pages/Login';
import Register from './pages/Register';
// Chaque page est chargée à part : la première ouverture du site est plus rapide.
// Les autres pages sont ensuite téléchargées en arrière-plan, quand le navigateur est libre,
// pour qu'aucun écran de chargement n'apparaisse en changeant de page.
const pages = {
  Dashboard: () => import('./pages/Dashboard'),
  Parcours: () => import('./pages/Parcours'),
  ParcoursDetail: () => import('./pages/ParcoursDetail'),
  Beneficiaires: () => import('./pages/Beneficiaires'),
  BeneficiaireDetail: () => import('./pages/BeneficiaireDetail'),
  Absences: () => import('./pages/Absences'),
  Administrateurs: () => import('./pages/Administrateurs'),
  AdminDetail: () => import('./pages/AdminDetail'),
  Devoirs: () => import('./pages/Devoirs'),
  DevoirDetail: () => import('./pages/DevoirDetail'),
  Parametres: () => import('./pages/Parametres'),
  Discussion: () => import('./pages/Discussion'),
  Fabia: () => import('./pages/Fabia'),
};
const Dashboard = lazy(pages.Dashboard);
const Parcours = lazy(pages.Parcours);
const ParcoursDetail = lazy(pages.ParcoursDetail);
const Beneficiaires = lazy(pages.Beneficiaires);
const BeneficiaireDetail = lazy(pages.BeneficiaireDetail);
const Absences = lazy(pages.Absences);
const Administrateurs = lazy(pages.Administrateurs);
const AdminDetail = lazy(pages.AdminDetail);
const Devoirs = lazy(pages.Devoirs);
const DevoirDetail = lazy(pages.DevoirDetail);
const Parametres = lazy(pages.Parametres);
const Discussion = lazy(pages.Discussion);
const Fabia = lazy(pages.Fabia);

const preloadPages = () => Object.values(pages).forEach((load) => load().catch(() => {}));
if ('requestIdleCallback' in window) window.requestIdleCallback(preloadPages, { timeout: 4000 });
else setTimeout(preloadPages, 2000);

function App() {
  return (
    <ToastProvider>
      <BrowserRouter>
        <Suspense fallback={<PageLoader fullscreen />}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/discussion" element={<RequireRole><Discussion /></RequireRole>} />
          <Route
            path="/dashboard"
            element={<RequireRole allow="dashboard"><Dashboard /></RequireRole>}
          />

          <Route path="/parcours" element={<RequireRole><Parcours /></RequireRole>} />
          <Route path="/parcours/:id" element={<RequireRole><ParcoursDetail /></RequireRole>} />
          <Route path="/beneficiaires" element={<RequireRole><Beneficiaires /></RequireRole>} />
          <Route path="/absences" element={<RequireRole><Absences /></RequireRole>} />
          <Route path="/fabia" element={<RequireRole allow="manageFabia"><Fabia /></RequireRole>} />
          <Route path="/administrateurs" element={<RequireRole allow="manageAdmins"><Administrateurs /></RequireRole>} />
          <Route path="/administrateurs/:id" element={<RequireRole ownAdminProfile><AdminDetail /></RequireRole>} />

          <Route
            path="/beneficiaires/:id"
            element={<RequireRole allow="beneficiaireDetail"><BeneficiaireDetail /></RequireRole>}
          />

          {/* Devoirs */}
          <Route path="/devoirs" element={<RequireRole><Devoirs /></RequireRole>} />
          <Route path="/devoirs/:id" element={<RequireRole><DevoirDetail /></RequireRole>} />
          <Route path="/parametres" element={<RequireRole><Parametres /></RequireRole>} />

          <Route path="/" element={<Navigate to="/login" />} />
          <Route path="*" element={<RequireRole><HomeRedirect /></RequireRole>} />
        </Routes>
        </Suspense>
      </BrowserRouter>
    </ToastProvider>
  );
}

export default App;