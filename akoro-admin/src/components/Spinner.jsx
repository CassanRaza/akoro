import logo from '../assets/logo.jpg';
import './Spinner.css';

// Petit cercle qui tourne (boutons, listes)
export default function Spinner({ size = 20, light = false }) {
  return (
    <span
      className={'spinner' + (light ? ' spinner-light' : '')}
      style={{ width: size, height: size }}
      role="status"
      aria-label="Chargement"
    />
  );
}

// Chargement de page : logo qui pulse dans un anneau qui tourne
export function PageLoader({ fullscreen = false }) {
  return (
    <div
      className={'page-loader' + (fullscreen ? ' page-loader-full' : '')}
      role="status"
      aria-label="Chargement"
    >
      <div className="page-loader-ring">
        <img src={logo} alt="" className="page-loader-logo" />
      </div>
    </div>
  );
}