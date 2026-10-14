import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import RequireRole, { HomeRedirect } from './components/RequireRole';
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import Parcours from './pages/Parcours';
import ParcoursDetail from './pages/ParcoursDetail';
import Beneficiaires from './pages/Beneficiaires';
import BeneficiaireDetail from './pages/BeneficiaireDetail';
import Absences from './pages/Absences';
import Administrateurs from './pages/Administrateurs';
import AdminDetail from './pages/AdminDetail';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />

        {/* Tableau de bord : manager et super admin */}
        <Route
          path="/dashboard"
          element={<RequireRole allow="dashboard"><Dashboard /></RequireRole>}
        />

        {/* Pages ouvertes à tous les administrateurs */}
        <Route path="/parcours" element={<RequireRole><Parcours /></RequireRole>} />
        <Route path="/parcours/:id" element={<RequireRole><ParcoursDetail /></RequireRole>} />
        <Route path="/beneficiaires" element={<RequireRole><Beneficiaires /></RequireRole>} />
        <Route path="/absences" element={<RequireRole><Absences /></RequireRole>} />
        <Route path="/administrateurs" element={<RequireRole><Administrateurs /></RequireRole>} />
        <Route path="/administrateurs/:id" element={<RequireRole><AdminDetail /></RequireRole>} />

        {/* Fiche détaillée d'un bénéficiaire : manager et super admin */}
        <Route
          path="/beneficiaires/:id"
          element={<RequireRole allow="beneficiaireDetail"><BeneficiaireDetail /></RequireRole>}
        />

        <Route path="/" element={<Navigate to="/login" />} />
        <Route path="*" element={<RequireRole><HomeRedirect /></RequireRole>} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;