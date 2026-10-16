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
import { calculateQcmDeadline, toDateTimeLocal, toIsoDateTime } from '../utils/devoirDates';
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

const CHOIX_VIDES = [
  { texte: '', est_correct: true },
  { texte: '', est_correct: false },
  { texte: '', est_correct: false },
];

const creerQuestionVide = () => ({
  enonce: '',
  points: 1,
  choix: CHOIX_VIDES.map((choix) => ({ ...choix })),
});

const NOMBRE_QUESTIONS_MINIMUM = 5;
const NOMBRE_QUESTIONS_MAXIMUM = 20;

export default function DevoirDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { confirm, confirmationDialog } = useConfirmation();
  const showToast = useToast();

  const [devoir, setDevoir] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('infos');
  const [editingDeadline, setEditingDeadline] = useState(false);
  const [deadlineInput, setDeadlineInput] = useState('');
  const [savingDeadline, setSavingDeadline] = useState(false);

  const [showQuestionModal, setShowQuestionModal] = useState(false);
  const [questionsForm, setQuestionsForm] = useState([]);
  const [savingQuestion, setSavingQuestion] = useState(false);

  const [generating, setGenerating] = useState(false);
  const [nbQuestionsIA, setNbQuestionsIA] = useState(5);

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
    setQuestionsForm(
      Array.from({ length: NOMBRE_QUESTIONS_MINIMUM }, creerQuestionVide)
    );
    setShowQuestionModal(true);
  };

  const updateQuestion = (questionIndex, field, value) => {
    setQuestionsForm((current) =>
      current.map((question, index) =>
        index === questionIndex ? { ...question, [field]: value } : question
      )
    );
  };

  const updateChoix = (questionIndex, choixIndex, field, value) => {
    setQuestionsForm((current) =>
      current.map((question, index) => {
        if (index !== questionIndex) return question;
        const choix = question.choix.map((choice) => ({ ...choice }));
        if (field === 'est_correct' && value === true) {
          choix.forEach((c, i) => {
            c.est_correct = i === choixIndex;
          });
        } else {
          choix[choixIndex] = { ...choix[choixIndex], [field]: value };
        }
        return { ...question, choix };
      })
    );
  };

  const ajouterQuestionManuelle = () => {
    setQuestionsForm((current) =>
      current.length < NOMBRE_QUESTIONS_MAXIMUM
        ? [...current, creerQuestionVide()]
        : current
    );
  };

  const supprimerQuestionManuelle = (questionIndex) => {
    setQuestionsForm((current) =>
      current.length > NOMBRE_QUESTIONS_MINIMUM
        ? current.filter((_, index) => index !== questionIndex)
        : current
    );
  };

  const submitQuestion = async (e) => {
    e.preventDefault();

    if (
      questionsForm.length < NOMBRE_QUESTIONS_MINIMUM
      || questionsForm.length > NOMBRE_QUESTIONS_MAXIMUM
    ) {
      showToast(`Le questionnaire doit contenir entre ${NOMBRE_QUESTIONS_MINIMUM} et ${NOMBRE_QUESTIONS_MAXIMUM} questions.`);
      return;
    }

    const questionInvalide = questionsForm.findIndex((question) =>
      !question.enonce.trim()
      || question.choix.length !== 3
      || question.choix.some((choice) => !choice.texte.trim())
      || question.choix.filter((choice) => choice.est_correct).length !== 1
    );
    if (questionInvalide !== -1) {
      showToast(`Complétez la question ${questionInvalide + 1} et sélectionnez une seule bonne réponse.`);
      return;
    }

    setSavingQuestion(true);
    try {
      await api.post(`/devoirs/${id}/questions`, {
        questions: questionsForm.map((question) => ({
          enonce: question.enonce.trim(),
          points: Number(question.points) || 1,
          choix: question.choix.map((choice) => ({
            texte: choice.texte.trim(),
            est_correct: choice.est_correct,
          })),
        })),
      });
      setShowQuestionModal(false);
      showToast(`Questionnaire enregistré (${questionsForm.length} questions).`);
      await load();
    } catch (err) {
      const validationError = Object.values(err.response?.data?.errors || {}).flat()[0];
      showToast(validationError || err.response?.data?.message || 'Erreur lors de l’ajout.');
    } finally {
      setSavingQuestion(false);
    }
  };

  const genererParIA = async () => {
    if (
      !(await confirm({
        title: 'Générer des questions par IA ?',
        message: `${nbQuestionsIA} question(s) seront créées à partir du contenu des fichiers liés aux leçons de ce devoir (3 choix chacune).`,
        confirmLabel: 'Générer',
        variant: 'info',
      }))
    ) {
      return;
    }

    setGenerating(true);
    try {
      const response = await api.post(`/devoirs/${id}/generer-questions`, {
        nombre: nbQuestionsIA,
      });
      await load();
      setTab('questions');
      showToast(
        response.data.generation_source === 'local'
          ? 'Questions générées à partir du texte des documents. Configurez une clé OpenAI valide pour obtenir des questions rédigées par l’IA.'
          : 'Questions générées avec succès.'
      );
    } catch (err) {
      showToast(
        err.response?.data?.errors?.ia?.[0]
          || err.response?.data?.message
          || 'Erreur lors de la génération IA.'
      );
    } finally {
      setGenerating(false);
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
    ) {
      return;
    }

    try {
      await api.put(`/devoirs/${id}`, { statut: nouveauStatut });
      showToast('Statut mis à jour.');
      await load();
    } catch (err) {
      setError(err.response?.data?.message || 'Erreur.');
    }
  };

  const saveDeadline = async (event) => {
    event.preventDefault();
    setSavingDeadline(true);
    setError('');
    try {
      const response = await api.put(`/devoirs/${id}`, {
        date_limite: toIsoDateTime(deadlineInput),
      });
      setDevoir(response.data);
      setEditingDeadline(false);
      showToast('Date limite mise à jour.');
    } catch (err) {
      setError(
        err.response?.data?.errors?.date_limite?.[0]
          || err.response?.data?.message
          || 'Erreur lors de la mise à jour de la date limite.'
      );
    } finally {
      setSavingDeadline(false);
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
  const leconsRef = devoir.lecons || [];

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
          <div className="dd-label">
            {devoir.type === 'qcm' ? 'Date et heure de début' : 'Date limite de rendu'}
          </div>
          <div className="dd-value">
            {devoir.type === 'qcm' ? (
              formatDateTime(devoir.date_debut)
            ) : editingDeadline ? (
              <form className="dd-deadline-editor" onSubmit={saveDeadline}>
                <input
                  type="datetime-local"
                  value={deadlineInput}
                  onChange={(event) => setDeadlineInput(event.target.value)}
                  required
                />
                <button type="submit" className="parcours-add" disabled={savingDeadline}>
                  {savingDeadline ? <Spinner size={16} light /> : null}
                  Enregistrer
                </button>
                <button
                  type="button"
                  className="bene-filter"
                  onClick={() => setEditingDeadline(false)}
                  disabled={savingDeadline}
                >
                  Annuler
                </button>
              </form>
            ) : (
              <>
                <div>{formatDateTime(devoir.date_limite)}</div>
                <button
                  type="button"
                  className="bene-filter dd-deadline-edit"
                  onClick={() => {
                    setDeadlineInput(toDateTimeLocal(devoir.date_limite));
                    setEditingDeadline(true);
                  }}
                >
                  Modifier
                </button>
              </>
            )}
          </div>
        </div>

        {devoir.type === 'qcm' && (
          <div>
            <div className="dd-label">Date limite (fin du QCM)</div>
            <div className="dd-value">
              {formatDateTime(
                devoir.date_limite || calculateQcmDeadline(devoir.date_debut, devoir.duree_minutes)
              )}
            </div>
          </div>
        )}

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
          <div className="dd-label">Leçon(s) de référence</div>
          <div className="dd-value">
            {leconsRef.length > 0
              ? leconsRef.map((l) => l.titre).join(', ')
              : devoir.lecon?.titre || '—'}
          </div>
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
          <div className="dd-questions-toolbar">
            <button className="parcours-add" onClick={openQuestionModal}>
              Créer un questionnaire
            </button>

            <div className="dd-ia-block">
              <input
                type="number"
                min={1}
                max={20}
                value={nbQuestionsIA}
                onChange={(e) => setNbQuestionsIA(Number(e.target.value) || 5)}
                className="dd-ia-number"
                title="Nombre de questions à générer"
              />
              <button
                className="parcours-add dd-ia-btn"
                onClick={genererParIA}
                disabled={generating}
              >
                {generating ? <Spinner size={16} light /> : null}
                Générer par IA
              </button>
            </div>
          </div>

          {questions.length === 0 ? (
            <div className="bd-empty">
              Aucune question pour le moment. Ajoutez-en manuellement ou générez-les par IA.
            </div>
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
        title={`Créer un questionnaire (${NOMBRE_QUESTIONS_MINIMUM} questions minimum)`}
        onClose={() => setShowQuestionModal(false)}
        className="dd-questionnaire-modal"
      >
        <form onSubmit={submitQuestion} className="devoir-form">
          <p className="dd-questionnaire-hint">
            Préparez au moins {NOMBRE_QUESTIONS_MINIMUM} questions. Chaque question comporte trois réponses et une seule bonne réponse.
          </p>
          <div className="dd-manual-questions">
            {questionsForm.map((question, questionIndex) => (
              <fieldset className="dd-manual-question" key={questionIndex}>
                <legend>Question {questionIndex + 1}</legend>
                {questionsForm.length > NOMBRE_QUESTIONS_MINIMUM && (
                  <button
                    type="button"
                    className="dd-remove-question"
                    onClick={() => supprimerQuestionManuelle(questionIndex)}
                  >
                    Retirer
                  </button>
                )}
                <div className="devoir-form-row">
                  <label htmlFor={`manual-question-${questionIndex}`}>Énoncé *</label>
                  <textarea
                    id={`manual-question-${questionIndex}`}
                    value={question.enonce}
                    onChange={(e) => updateQuestion(questionIndex, 'enonce', e.target.value)}
                    required
                    minLength={5}
                    rows={2}
                  />
                </div>
                <div className="devoir-form-row">
                  <label htmlFor={`manual-points-${questionIndex}`}>Points</label>
                  <input
                    id={`manual-points-${questionIndex}`}
                    type="number"
                    min={1}
                    max={20}
                    value={question.points}
                    onChange={(e) => updateQuestion(questionIndex, 'points', e.target.value)}
                  />
                </div>
                <div className="devoir-form-row">
                  <label>Choix de réponses (3 obligatoires) *</label>
                  {question.choix.map((choice, choiceIndex) => (
                    <div key={choiceIndex} className="dd-choix-row">
                      <input
                        type="radio"
                        name={`bonne-${questionIndex}`}
                        checked={choice.est_correct}
                        onChange={() => updateChoix(questionIndex, choiceIndex, 'est_correct', true)}
                        aria-label={`Choix ${choiceIndex + 1} : bonne réponse`}
                      />
                      <textarea
                        placeholder={`Choix ${choiceIndex + 1}`}
                        value={choice.texte}
                        onChange={(e) => updateChoix(questionIndex, choiceIndex, 'texte', e.target.value)}
                        required
                        rows={2}
                        aria-label={`Texte du choix ${choiceIndex + 1} pour la question ${questionIndex + 1}`}
                      />
                    </div>
                  ))}
                  <p className="dd-questionnaire-hint">
                    Sélectionnez la pastille de la bonne réponse.
                  </p>
                </div>
              </fieldset>
            ))}
          </div>
          {questionsForm.length < NOMBRE_QUESTIONS_MAXIMUM && (
            <button
              type="button"
              className="bene-filter dd-add-question"
              onClick={ajouterQuestionManuelle}
            >
              Ajouter une question
            </button>
          )}
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
              Enregistrer le questionnaire
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