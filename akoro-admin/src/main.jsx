import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { installLinkPrefetch } from './services/prefetch'

// Précharge les données d'une page dès le survol de son lien
installLinkPrefetch()

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
