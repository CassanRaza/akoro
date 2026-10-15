import { useEffect, useState } from 'react';
import { Link, useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import Layout from '../components/Layout';
import Avatar from '../components/Avatar';
import Spinner, { PageLoader } from '../components/Spinner';
import Modal from '../components/Modal';
import useConfirmation from '../components/useConfirmation';
import useToast from '../components/useToast';
import { ActionIconButton } from '../components/ActionIcon';
import './Beneficiaires.css';
import './Devoirs.css';
import './DevoirDetail.css';

const formatDateTime = (value) => {
  if (!value) return '—';
  return new Date(value).toLocaleString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const typeLabel = (t) => (t === 'qcm' ? 'QCM programmé' : 'Rendu PDF');

const statutLabel = (s) =>
  ({
    brouillon: 'Brouillon',
    programme: 'Programmé',
    en_cours: 'En cours',
    termine: 'Terminé',
    archive: 'Archivé',
  }[s] || s);

export default function DevoirDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();

  const [devoir, setDevoir] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('infos');

  const [showQuestionModal, setShowQuestionModal] = useState(false);
  const [questionForm, setQuestionForm] = useState({
    enonce: '',
    points: 1,
    choix: [
      { texte: '', est_correct: true },
      { texte: '', est_correct: false },
    ],
  });
  const [savingQuestion, setSavingQuestion] = useState(false);

  const [modalSoumission, setModalSoumission] = useState(null);
  const [note, setNote] = useState('');
  const [commentaire, setCommentaire] = useState('');
  const [savingNote, setSavingNote] = useState(false);

  const load = () => api.get(`/devoirs/${id}`).then((res) => setDevoir(res.data));

  useEffect(() => {
    load()
      .catch((err) => {
        if ([403, 404].includes(err.response?.status)) {
          navigate('/devoirs', { replace: true });
        } else {
          setError(err.response?.data?.message || 'Erreur de chargement.');
        }
      })
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const openQuestionModal = () => {
    setQuestionForm({
      enonce: '',
      points: 1,
      choix: [
        { texte: '', est_correct: true },
        { texte: '', est_correct: false },
      ],
    });
    setShowQuestionModal(true);
  };

  const addChoix = () => {
    setQuestionForm((f) => ({
      ...f,
      choix: [...f.choix, { texte: '', est_correct: false }],
    }));
  };

  const updateChoix = (index, field, value) => {
    setQuestionForm((f) => {
      const choix = [...f.choix];
      if (field === 'est_correct' && value === true) {
        choix.forEach((c, i) => {
          c.est_correct = i === index;
        });
      } else {
        choix[index] = { ...choix[index], [field]: value };
      }
      return { ...f, choix };
    });
  };

  const removeChoix = (index) => {
    setQuestionForm((f) => ({
      ...f,
      choix: f.choix.filter((_, i) => i !== index),
    }));
  };

  const submitQuestion = async (e) => {
    e.preventDefault();
    if (questionForm.choix.filter((c) => c.est_correct).length !== 1) {
      showToast('Il doit y avoir exactement une bonne réponse.');
      return;
    }

    setSavingQuestion(true);
    try {
      await api.post(`/devoirs/${id}/questions`, {
        questions: [
          {
            enonce: questionForm.enonce.trim(),
            points: Number(questionForm.points) || 1,
            choix: questionForm.choix.map((c) => ({
              texte: c.texte.trim(),
              est_correct: c.est_correct,
            })),
          },
        ],
      });
      setShowQuestionModal(false);
      showToast('Question ajoutée.');
      await load();
    } catch (err) {
      showToast(err.response?.data?.message || 'Erreur lors de l’ajout.');
    } finally {
      setSavingQuestion(false);
    }
  };

  const changerStatut = async (nouveauStatut) => {
    const labels = {
      programme: 'Programmer ce devoir',
      en_cours: 'Lancer la session',
      termine: 'Terminer ce devoir',
    };
    if (
      !(await confirm({
        title: labels[nouveauStatut] || 'Changer le statut ?',
        message: `Le statut passera à « ${statutLabel(nouveauStatut)} ».`,
        confirmLabel: 'Confirmer',
        variant: 'info',
      }))
    )
      return;

    try {
      await api.put(`/devoirs/${id}`, { statut: nouveauStatut });
      showToast('Statut mis à jour.');
      await load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur.');
    }
  };

  const openCorrection = (s) => {
    setModalSoumission(s);
    setNote(s.note ?? '');
    setCommentaire(s.commentaire || '');
  };

  const submitCorrection = async (e) => {
    e.preventDefault();
    setSavingNote(true);
    try {
      await api.put(`/soumissions/${modalSoumission.id}/corriger`, {
        note: Number(note),
        commentaire: commentaire.trim() || null,
      });
      setModalSoumission(null);
      showToast('Note enregistrée.');
      await load();
    } catch (err) {
      showToast(err.response?.data?.message || 'Erreur lors de la correction.');
    } finally {
      setSavingNote(false);
    }
  };

  if (loading) {
    return (
      <Layout>
        <PageLoader />
      </Layout>
    );
  }

  if (!devoir) {
    return (
      <Layout>
        <Link to="/devoirs" className="bd-back">
          ← Devoirs
        </Link>
        <p style={{ color: 'var(--error-text)' }}>{error || 'Devoir introuvable.'}</p>
      </Layout>
    );
  }

  const questions = devoir.questions || [];
  const resultats = devoir.resultats || [];
  const soumissions = devoir.soumissions || [];

  return (
    <Layout>
      <Link to="/devoirs" className="bd-back">
        ← Devoirs
      </Link>

      {error && <p style={{ color: 'var(--error-text)' }}>{error}</p>}

      <div className="dd-header">
        <div>
          <h1 style={{ margin: 0, fontSize: 24 }}>{devoir.titre}</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 6 }}>
            {typeLabel(devoir.type)} · {devoir.parcours?.nom || '—'}
          </p>
        </div>
        <div className="dd-header-actions">
          <span className={`devoir-statut devoir-statut-${devoir.statut}`}>
            {statutLabel(devoir.statut)}
          </span>
          {devoir.statut === 'brouillon' && (
            <button className="parcours-add" onClick={() => changerStatut('programme')}>
              Programmer
            </button>
          )}
          {devoir.statut === 'programme' && devoir.type === 'qcm' && (
            <button className="parcours-add" onClick={() => changerStatut('en_cours')}>
              Lancer la session
            </button>
          )}
        </div>
      </div>

      <div className="dd-info-grid">
        <div>
          <div className="dd-label">Date / Limite</div>
          <div className="dd-value">
            {devoir.type === 'qcm'
              ? formatDateTime(devoir.date_debut)
              : formatDateTime(devoir.date_limite)}
          </div>
        </div>
        {devoir.type === 'qcm' && (
          <div>
            <div className="dd-label">Durée</div>
            <div className="dd-value">{devoir.duree_minutes} min</div>
          </div>
        )}
        <div>
          <div className="dd-label">Créé par</div>
          <div className="dd-value">{devoir.createur?.name || '—'}</div>
        </div>
        <div>
          <div className="dd-label">Leçon liée</div>
          <div className="dd-value">{devoir.lecon?.titre || '—'}</div>
        </div>
      </div>

      <div className="bd-tabs">
        <button
          className={'bd-tab' + (tab === 'infos' ? ' bd-tab-active' : '')}
          onClick={() => setTab('infos')}
        >
          Informations
        </button>
        {devoir.type === 'qcm' && (
          <button
            className={'bd-tab' + (tab === 'questions' ? ' bd-tab-active' : '')}
            onClick={() => setTab('questions')}
          >
            Questions ({questions.length})
          </button>
        )}
        {devoir.type === 'qcm' && (
          <button
            className={'bd-tab' + (tab === 'resultats' ? ' bd-tab-active' : '')}
            onClick={() => setTab('resultats')}
          >
            Résultats ({resultats.length})
          </button>
        )}
        {devoir.type === 'rendu' && (
          <button
            className={'bd-tab' + (tab === 'soumissions' ? ' bd-tab-active' : '')}
            onClick={() => setTab('soumissions')}
          >
            Soumissions ({soumissions.length})
          </button>
        )}
      </div>

      {tab === 'infos' && (
        <div className="dd-description">
          <h3>Description</h3>
          <p>{devoir.description || 'Aucune description.'}</p>

          {devoir.type === 'rendu' && devoir.fichier_consigne && (
            <div className="dd-consigne">
              <h3>Fichier de consigne</h3>
              <a
                href={`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/storage/${devoir.fichier_consigne}`}
                target="_blank"
                rel="noreferrer"
                className="parcours-add"
                style={{ display: 'inline-block', marginTop: 8 }}
              >
                Télécharger le PDF de consigne
              </a>
            </div>
          )}
        </div>
      )}

      {tab === 'questions' && (
        <>
          <div style={{ marginBottom: 16 }}>
            <button className="parcours-add" onClick={openQuestionModal}>
              + Ajouter une question
            </button>
          </div>
          {questions.length === 0 ? (
            <div className="bd-empty">Aucune question pour le moment.</div>
          ) : (
            <div className="dd-questions">
              {questions.map((q, i) => (
                <div key={q.id} className="dd-question-card">
                  <div className="dd-question-header">
                    <strong>Question {i + 1}</strong>
                    <span>
                      {q.points} pt{q.points > 1 ? 's' : ''}
                    </span>
                  </div>
                  <p>{q.enonce}</p>
                  <ul className="dd-choix-list">
                    {(q.choix || []).map((c) => (
                      <li key={c.id} className={c.est_correct ? 'correct' : ''}>
                        {c.texte}
                        {c.est_correct && (
                          <span className="dd-badge-correct">Bonne réponse</span>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {tab === 'resultats' &&
        (resultats.length === 0 ? (
          <div className="bd-empty">Aucun résultat pour le moment.</div>
        ) : (
          <div className="bene-table-wrap">
            <table className="bene-table">
              <thead>
                <tr>
                  <th>Bénéficiaire</th>
                  <th>Score</th>
                  <th>%</th>
                  <th>Statut</th>
                  <th>Terminé le</th>
                </tr>
              </thead>
              <tbody>
                {resultats.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <div className="abs-who">
                        <Avatar name={r.user?.name || ''} url={r.user?.photo_url} size={32} />
                        <span>{r.user?.name}</span>
                      </div>
                    </td>
                    <td>
                      {r.score} / {r.score_max}
                    </td>
                    <td>{r.pourcentage != null ? `${r.pourcentage} %` : '—'}</td>
                    <td>{r.statut}</td>
                    <td>{formatDateTime(r.termine_le)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}

      {tab === 'soumissions' &&
        (soumissions.length === 0 ? (
          <div className="bd-empty">Aucune soumission pour le moment.</div>
        ) : (
          <div className="bene-table-wrap">
            <table className="bene-table">
              <thead>
                <tr>
                  <th>Bénéficiaire</th>
                  <th>Fichier</th>
                  <th>Date de rendu</th>
                  <th>Note</th>
                  <th>Statut</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {soumissions.map((s) => (
                  <tr key={s.id}>
                    <td>
                      <div className="abs-who">
                        <Avatar name={s.user?.name || ''} url={s.user?.photo_url} size={32} />
                        <span>{s.user?.name}</span>
                      </div>
                    </td>
                    <td>{s.nom_fichier || '—'}</td>
                    <td>{formatDateTime(s.date_soumission)}</td>
                    <td>{s.note != null ? s.note : '—'}</td>
                    <td>{s.statut}</td>
                    <td>
                      {s.statut !== 'corrige' && (
                        <ActionIconButton
                          icon="edit"
                          label="Évaluer"
                          className="bene-action"
                          onClick={() => openCorrection(s)}
                        />
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}

      <Modal
        open={showQuestionModal}
        title="Ajouter une question"
        onClose={() => setShowQuestionModal(false)}
      >
        <form onSubmit={submitQuestion} className="devoir-form">
          <div className="devoir-form-row">
            <label>Énoncé *</label>
            <textarea
              value={questionForm.enonce}
              onChange={(e) => setQuestionForm({ ...questionForm, enonce: e.target.value })}
              required
              rows={3}
            />
          </div>
          <div className="devoir-form-row">
            <label>Points</label>
            <input
              type="number"
              min={1}
              max={20}
              value={questionForm.points}
              onChange={(e) => setQuestionForm({ ...questionForm, points: e.target.value })}
            />
          </div>
          <div className="devoir-form-row">
            <label>Choix de réponses *</label>
            {questionForm.choix.map((c, i) => (
              <div key={i} className="dd-choix-row">
                <input
                  type="radio"
                  name="bonne"
                  checked={c.est_correct}
                  onChange={() => updateChoix(i, 'est_correct', true)}
                  title="Bonne réponse"
                />
                <input
                  type="text"
                  placeholder={`Choix ${i + 1}`}
                  value={c.texte}
                  onChange={(e) => updateChoix(i, 'texte', e.target.value)}
                  required
                />
                {questionForm.choix.length > 2 && (
                  <button type="button" className="bene-action" onClick={() => removeChoix(i)}>
                    ✕
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              className="bene-filter"
              onClick={addChoix}
              style={{ marginTop: 8 }}
            >
              + Ajouter un choix
            </button>
          </div>
          <div className="devoir-form-actions">
            <button
              type="button"
              className="bene-filter"
              onClick={() => setShowQuestionModal(false)}
            >
              Annuler
            </button>
            <button type="submit" className="parcours-add" disabled={savingQuestion}>
              {savingQuestion ? <Spinner size={16} light /> : null}
              Ajouter
            </button>
          </div>
        </form>
      </Modal>

      <Modal
        open={!!modalSoumission}
        title="Évaluer la soumission"
        onClose={() => setModalSoumission(null)}
      >
        {modalSoumission && (
          <form onSubmit={submitCorrection} className="devoir-form">
            <p>
              <strong>{modalSoumission.user?.name}</strong>
            </p>
            <div className="devoir-form-row">
              <label>Note (/20) *</label>
              <input
                type="number"
                min={0}
                max={20}
                step={0.5}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                required
              />
            </div>
            <div className="devoir-form-row">
              <label>Commentaire</label>
              <textarea
                value={commentaire}
                onChange={(e) => setCommentaire(e.target.value)}
                rows={3}
              />
            </div>
            <div className="devoir-form-actions">
              <button
                type="button"
                className="bene-filter"
                onClick={() => setModalSoumission(null)}
              >
                Annuler
              </button>
              <button type="submit" className="parcours-add" disabled={savingNote}>
                {savingNote ? <Spinner size={16} light /> : null}
                Enregistrer la note
              </button>
            </div>
          </form>
        )}
      </Modal>

      {confirmationDialog}
    </Layout>
  );
}