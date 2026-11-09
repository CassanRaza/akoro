import { useCallback, useEffect, useRef, useState } from 'react';
import QRCode from 'qrcode';
import api from '../services/api';
import Modal from './Modal';
import Avatar from './Avatar';
import Spinner from './Spinner';
import useConfirmation from './useConfirmation';
import useToast from './useToast';
import './SeanceQrModal.css';

const ETATS = {
  a_venir: { label: 'Pas encore ouvert', className: 'qr-etat-attente' },
  ouverte: { label: 'Pointage ouvert', className: 'qr-etat-ouvert' },
  terminee: { label: 'Pointage terminé', className: 'qr-etat-ferme' },
};

const formatDate = (v) =>
  new Date(`${v}T00:00:00`).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });

/**
 * QR de présence d'une séance : à projeter ou imprimer pour que les bénéficiaires le scannent
 * avec l'application mobile. Les pointages s'affichent en direct.
 */
export default function SeanceQrModal({ seanceId, onClose }) {
  const showToast = useToast();
  const { confirm, confirmationDialog } = useConfirmation();
  const [data, setData] = useState(null);
  const [image, setImage] = useState('');
  const [error, setError] = useState('');
  const [regenerating, setRegenerating] = useState(false);
  const zoneRef = useRef(null);

  const charger = useCallback(async () => {
    try {
      const res = await api.get(`/seances/${seanceId}/qr`);
      setData(res.data);
      setError('');
    } catch (err) {
      setError(err.response?.data?.message || 'Impossible de charger le QR de la séance.');
    }
  }, [seanceId]);

  // Chargement + pointages en direct (toutes les 8 s, onglet visible)
  useEffect(() => {
    let actif = true;
    api.get(`/seances/${seanceId}/qr`)
      .then((res) => actif && setData(res.data))
      .catch((err) => actif && setError(err.response?.data?.message || 'Impossible de charger le QR de la séance.'));
    const timer = setInterval(() => {
      if (!document.hidden) charger();
    }, 8000);
    return () => {
      actif = false;
      clearInterval(timer);
    };
  }, [seanceId, charger]);

  // Image du QR (haute résolution pour la projection et l'impression)
  useEffect(() => {
    if (!data?.qr) return undefined;
    let actif = true;
    QRCode.toDataURL(data.qr, { width: 720, margin: 1, errorCorrectionLevel: 'M', color: { dark: '#14171c', light: '#ffffff' } })
      .then((url) => actif && setImage(url))
      .catch(() => actif && setError('Le QR code n’a pas pu être dessiné.'));
    return () => {
      actif = false;
    };
  }, [data?.qr]);

  const pleinEcran = () => zoneRef.current?.requestFullscreen?.();

  const imprimer = () => {
    document.body.classList.add('qr-impression');
    window.print();
    document.body.classList.remove('qr-impression');
  };

  const regenerer = async () => {
    if (!(await confirm({
      title: 'Générer un nouveau QR ?',
      message: 'L’ancien QR code et son code ne fonctionneront plus. Utile si une photo du QR a circulé. Les pointages déjà faits sont conservés.',
      confirmLabel: 'Générer',
      variant: 'warning',
    }))) return;
    setRegenerating(true);
    try {
      const res = await api.post(`/seances/${seanceId}/qr/regenerer`);
      setData(res.data);
      showToast('Nouveau QR code généré.');
    } catch (err) {
      showToast(err.response?.data?.message || 'Erreur lors de la génération.');
    } finally {
      setRegenerating(false);
    }
  };

  const s = data?.seance;
  const etat = ETATS[data?.etat] || ETATS.a_venir;

  return (
    <Modal open title="QR de présence" onClose={onClose} className="qr-modal">
      {error && <p className="qr-error">{error}</p>}
      {!data ? (
        !error && <div className="qr-loading"><Spinner size={28} /></div>
      ) : (
        <div className="qr-layout">
          {/* ---------- QR à projeter ---------- */}
          <div className="qr-zone" ref={zoneRef}>
            <div className="qr-entete">
              <span className="qr-parcours">{s.parcours}</span>
              <h3>{s.lecon || 'Séance libre'}</h3>
              <p>
                <span className="qr-date">{formatDate(s.date)}</span> · {s.heure_debut} – {s.heure_fin}
              </p>
            </div>

            <div className="qr-image">
              {image ? <img src={image} alt={`QR code de présence de la séance du ${formatDate(s.date)}`} /> : <Spinner size={28} />}
            </div>

            <p className="qr-consigne">Scannez ce QR avec l’application AKORO : <strong>Présence → Scanner</strong></p>
            <div className="qr-code-manuel" aria-label={`Code de secours : ${data.code.split('').join(' ')}`}>
              <span>Code</span>
              <strong>{data.code.slice(0, 3)} {data.code.slice(3)}</strong>
            </div>
            <span className={`qr-etat ${etat.className}`}>
              {etat.label}
              {data.etat === 'a_venir' && ` · ouvre à ${data.ouverture}`}
              {data.etat === 'ouverte' && ` · jusqu’à ${data.fermeture}`}
            </span>
          </div>

          {/* ---------- Pointages en direct ---------- */}
          <aside className="qr-pointages">
            <div className="qr-pointages-head">
              <h4>Pointages</h4>
              <span className="qr-compteur">
                <strong>{data.presents}</strong> / {data.attendus}
              </span>
            </div>
            <div className="qr-barre" aria-hidden="true">
              <span style={{ width: `${data.attendus ? (data.presents / data.attendus) * 100 : 0}%` }} />
            </div>
            {data.pointages.length === 0 ? (
              <p className="qr-vide">Aucun bénéficiaire actif dans ce parcours.</p>
            ) : (
              <ul className="qr-liste">
                {data.pointages.map((p) => (
                  <li key={p.id} className={p.arrivee ? 'is-present' : ''}>
                    <Avatar name={p.name} url={p.photo_url} size={30} />
                    <span className="qr-nom">{p.name}</span>
                    <span className="qr-heure">
                      {p.arrivee ? (
                        <>
                          {p.arrivee}
                          {p.depart && ` → ${p.depart}`}
                        </>
                      ) : (
                        'en attente'
                      )}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            <p className="qr-hint">Mise à jour automatique toutes les 8 secondes.</p>
          </aside>
        </div>
      )}

      {data && (
        <div className="qr-actions">
          <button type="button" className="parcours-add" onClick={pleinEcran}>Plein écran</button>
          <button type="button" className="bene-filter" onClick={imprimer}>Imprimer</button>
          <button type="button" className="bene-filter" onClick={regenerer} disabled={regenerating}>
            {regenerating ? <Spinner size={14} /> : null} Nouveau QR
          </button>
        </div>
      )}
      {confirmationDialog}
    </Modal>
  );
}
