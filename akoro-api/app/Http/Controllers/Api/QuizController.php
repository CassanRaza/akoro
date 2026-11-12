<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Choix;
use App\Models\Devoir;
use App\Models\Question;
use App\Models\Reponse;
use App\Models\ResultatQuiz;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Passage d'un QCM par un bénéficiaire (application mobile).
 * Une seule tentative ; chaque réponse validée est enregistrée tout de suite (pas de perte si le réseau coupe) ;
 * la note est visible par l'équipe dans les résultats du devoir, comme pour le web.
 */
class QuizController extends Controller
{
    // Délai de tolérance réseau après l'échéance
    private const TOLERANCE_SECONDES = 30;

    /** 'a_venir' | 'ouvert' | 'ferme' selon le statut et les dates du devoir. */
    public static function etatOuverture(Devoir $d): string
    {
        $now = now();
        if ($d->statut === 'termine' || ($d->date_limite && $d->date_limite->lte($now))) {
            return 'ferme';
        }
        if ($d->date_debut && $d->date_debut->gt($now)) {
            return 'a_venir';
        }

        return in_array($d->statut, ['programme', 'en_cours'], true) ? 'ouvert' : 'ferme';
    }

    /** Résumé d'un quiz pour un bénéficiaire (liste des quiz d'une formation). */
    public static function resume(Devoir $d, User $user): array
    {
        $r = ResultatQuiz::where('devoir_id', $d->id)->where('user_id', $user->id)->first();
        if ($r && $r->statut === 'en_cours' && self::echeance($d, $r)?->lt(now()->subSeconds(self::TOLERANCE_SECONDES))) {
            $r = self::finaliser($r);
        }

        $ouverture = self::etatOuverture($d);
        $etat = match (true) {
            $r?->statut === 'termine' => 'termine',
            $r?->statut === 'en_cours' && $ouverture === 'ouvert' => 'en_cours',
            $ouverture === 'ouvert' => 'disponible',
            $ouverture === 'a_venir' => 'a_venir',
            default => 'manque',
        };

        return [
            'id' => $d->id,
            'titre' => $d->titre,
            'description' => $d->description,
            'nb_questions' => $d->questions_count ?? $d->questions()->count(),
            'duree_minutes' => $d->duree_minutes,
            'date_debut' => $d->date_debut?->toIso8601String(),
            'date_limite' => $d->date_limite?->toIso8601String(),
            'etat' => $etat,
            'resultat' => $r?->statut === 'termine' ? self::formatResultat($r) : null,
        ];
    }

    // ---------- Toutes les évaluations QCM de mon parcours (onglet Quiz) ----------
    public function index(Request $request)
    {
        $user = $request->user();
        if (! $user->parcours_id) {
            return [];
        }

        return Devoir::query()
            ->where('type', 'qcm')
            ->where('parcours_id', $user->parcours_id)
            ->whereIn('statut', ['programme', 'en_cours', 'termine'])
            ->has('questions')
            ->with(['lecon:id,titre', 'lecons:id,titre'])
            ->withCount('questions')
            ->orderByRaw('date_debut IS NULL, date_debut')
            ->get()
            ->map(fn (Devoir $d) => [
                ...self::resume($d, $user),
                'formation' => $d->lecon?->titre ?? $d->lecons->first()?->titre,
            ])
            ->values();
    }

    // ---------- Ouvrir le quiz : démarre la tentative (ou la reprend) ----------
    public function afficher(Request $request, Devoir $devoir)
    {
        $user = $request->user();
        $this->autoriser($user, $devoir);
        $devoir->loadCount('questions');

        $resultat = ResultatQuiz::where('devoir_id', $devoir->id)->where('user_id', $user->id)->first();

        if (! $resultat || $resultat->statut === 'non_commence') {
            abort_unless(self::etatOuverture($devoir) === 'ouvert', 422, match (self::etatOuverture($devoir)) {
                'a_venir' => 'Ce quiz n’est pas encore ouvert.',
                default => 'Ce quiz est fermé : la date limite est passée.',
            });

            $resultat = ResultatQuiz::updateOrCreate(
                ['devoir_id' => $devoir->id, 'user_id' => $user->id],
                [
                    'score' => 0,
                    'score_max' => (int) $devoir->questions()->sum('points'),
                    'statut' => 'en_cours',
                    'commence_le' => now(),
                ]
            );
        }

        if ($resultat->statut === 'en_cours' && $this->tempsEcoule($devoir, $resultat)) {
            $resultat = self::finaliser($resultat);
        }

        if ($resultat->statut === 'termine') {
            return ['quiz' => self::resume($devoir, $user), 'termine' => true, 'resultat' => self::formatResultat($resultat)];
        }

        $repondues = $resultat->reponses()->pluck('choix_id', 'question_id');

        return [
            'quiz' => self::resume($devoir, $user),
            'termine' => false,
            'echeance' => self::echeance($devoir, $resultat)?->toIso8601String(),
            // Jamais la bonne réponse : seulement l'énoncé et les choix
            'questions' => $devoir->questions()->with('choix:id,question_id,texte,ordre')->get()->map(fn (Question $q) => [
                'id' => $q->id,
                'enonce' => $q->enonce,
                'points' => $q->points,
                'choix' => $q->choix->map(fn ($c) => ['id' => $c->id, 'texte' => $c->texte])->values(),
                'reponse_choix_id' => $repondues[$q->id] ?? null,
            ])->values(),
        ];
    }

    // ---------- Valider la réponse à une question (définitive) ----------
    public function repondre(Request $request, Devoir $devoir)
    {
        $user = $request->user();
        $this->autoriser($user, $devoir);

        $data = $request->validate([
            'question_id' => ['required', 'integer'],
            'choix_id' => ['required', 'integer'],
        ], [
            'choix_id.required' => 'Choisissez une réponse.',
        ]);

        $resultat = ResultatQuiz::where('devoir_id', $devoir->id)->where('user_id', $user->id)->first();
        abort_unless($resultat && $resultat->statut === 'en_cours', 422, 'Ce quiz n’est pas en cours.');

        if ($this->tempsEcoule($devoir, $resultat)) {
            self::finaliser($resultat);
            abort(422, 'Le temps est écoulé : vos réponses déjà validées ont été enregistrées.');
        }

        $question = Question::where('devoir_id', $devoir->id)->findOrFail($data['question_id']);
        $choix = Choix::where('question_id', $question->id)->findOrFail($data['choix_id']);

        abort_if(
            $resultat->reponses()->where('question_id', $question->id)->exists(),
            422,
            'Vous avez déjà répondu à cette question.'
        );

        Reponse::create([
            'resultat_quiz_id' => $resultat->id,
            'question_id' => $question->id,
            'choix_id' => $choix->id,
            'est_correcte' => (bool) $choix->est_correct,
        ]);

        $repondues = $resultat->reponses()->count();
        $total = $devoir->questions()->count();

        return ['repondues' => $repondues, 'total' => $total];
    }

    // ---------- Terminer : calcul de la note ----------
    public function terminer(Request $request, Devoir $devoir)
    {
        $user = $request->user();
        $this->autoriser($user, $devoir);

        $resultat = ResultatQuiz::where('devoir_id', $devoir->id)->where('user_id', $user->id)->first();
        abort_unless($resultat && $resultat->statut !== 'non_commence', 422, 'Ce quiz n’a pas été commencé.');

        if ($resultat->statut === 'en_cours') {
            $resultat = self::finaliser($resultat);
        }

        return ['quiz' => self::resume($devoir, $user), 'resultat' => self::formatResultat($resultat)];
    }

    // ---------- Outils ----------

    private function autoriser(User $user, Devoir $devoir): void
    {
        abort_unless(
            $devoir->type === 'qcm'
                && $devoir->parcours_id === $user->parcours_id
                && in_array($devoir->statut, ['programme', 'en_cours', 'termine'], true),
            403,
            'Ce quiz ne fait pas partie de votre parcours.'
        );
    }

    private static function echeance(Devoir $d, ResultatQuiz $r): ?Carbon
    {
        $fins = array_filter([
            $d->duree_minutes && $r->commence_le ? $r->commence_le->copy()->addMinutes($d->duree_minutes) : null,
            $d->date_limite,
        ]);

        return $fins ? collect($fins)->min() : null;
    }

    private function tempsEcoule(Devoir $d, ResultatQuiz $r): bool
    {
        return (bool) self::echeance($d, $r)?->lt(now()->subSeconds(self::TOLERANCE_SECONDES));
    }

    private static function finaliser(ResultatQuiz $r): ResultatQuiz
    {
        return DB::transaction(function () use ($r) {
            $score = (int) Reponse::where('resultat_quiz_id', $r->id)
                ->where('est_correcte', true)
                ->join('questions', 'questions.id', '=', 'reponses.question_id')
                ->sum('questions.points');
            $max = (int) Question::where('devoir_id', $r->devoir_id)->sum('points');

            $r->update([
                'score' => $score,
                'score_max' => $max,
                'pourcentage' => $max > 0 ? round($score / $max * 100, 2) : 0,
                'statut' => 'termine',
                'termine_le' => now(),
            ]);

            return $r->fresh();
        });
    }

    private static function formatResultat(ResultatQuiz $r): array
    {
        return [
            'score' => $r->score,
            'score_max' => $r->score_max,
            'pourcentage' => $r->pourcentage !== null ? (int) round((float) $r->pourcentage) : null,
            'note' => $r->score_max > 0 ? round($r->score / $r->score_max * 20, 1) : null,
            'reussi' => $r->score_max > 0 && $r->score / $r->score_max >= 0.5,
            'termine_le' => $r->termine_le?->toIso8601String(),
        ];
    }
}
