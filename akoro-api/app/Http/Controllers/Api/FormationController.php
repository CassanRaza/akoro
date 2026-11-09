<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Devoir;
use App\Models\Lecon;
use App\Models\Progression;
use App\Models\Ressource;
use App\Models\ResultatQuiz;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\URL;

/**
 * Formations côté bénéficiaire (application mobile).
 * Formation = leçon ; chapitres = documents de la leçon ; quiz = devoirs QCM liés à la leçon.
 */
class FormationController extends Controller
{
    // ---------- Catalogue : leçons de tout l'établissement (celles des autres parcours sont verrouillées) ----------
    public function index(Request $request)
    {
        $user = $request->user();

        $lecons = Lecon::query()
            ->whereHas('parcours', fn ($q) => $q->where('etablissement_id', $user->etablissement_id))
            ->with('parcours:id,nom')
            ->withCount('ressources')
            ->get()
            // Mon parcours d'abord, dans l'ordre du programme
            ->sortBy(fn ($l) => [$l->parcours_id === $user->parcours_id ? 0 : 1, $l->parcours?->nom, $l->ordre])
            ->values();

        $termines = Progression::where('user_id', $user->id)
            ->selectRaw('lecon_id, COUNT(*) as total')
            ->groupBy('lecon_id')
            ->pluck('total', 'lecon_id');

        $quiz = $this->quizParLecon($user, $lecons->pluck('id'));

        return $lecons->map(function (Lecon $l) use ($user, $termines, $quiz) {
            $accessible = $l->parcours_id === $user->parcours_id;
            $total = $l->ressources_count;
            $faits = $accessible ? min((int) ($termines[$l->id] ?? 0), $total) : 0;

            return [
                'id' => $l->id,
                'titre' => $l->titre,
                'description' => $l->description,
                'parcours' => ['id' => $l->parcours_id, 'nom' => $l->parcours?->nom],
                'accessible' => $accessible,
                'chapitres_total' => $total,
                'chapitres_termines' => $faits,
                'pourcentage' => $total > 0 ? (int) round($faits / $total * 100) : 0,
                'statut' => $this->statut($faits, $total),
                'quiz_ouverts' => $accessible ? ($quiz[$l->id] ?? 0) : 0,
            ];
        });
    }

    // ---------- Détail d'une formation : chapitres + quiz ----------
    public function show(Request $request, Lecon $lecon)
    {
        $user = $request->user();
        $this->autoriser($user, $lecon);

        $lecon->load('parcours:id,nom');
        $chapitres = $lecon->ressources()->orderBy('created_at')->orderBy('id')->get();
        $faits = Progression::where('user_id', $user->id)->where('lecon_id', $lecon->id)->pluck('termine_le', 'ressource_id');

        $precedentTermine = true;
        $liste = $chapitres->values()->map(function (Ressource $r, int $i) use ($faits, &$precedentTermine) {
            $termine = $faits->has($r->id);
            // Progression guidée : un chapitre s'ouvre quand le précédent est terminé
            $accessible = $i === 0 || $precedentTermine || $termine;
            $precedentTermine = $termine;

            return [
                'id' => $r->id,
                'numero' => $i + 1,
                'titre' => $r->titre,
                'type' => strtolower($r->type),
                'nom_fichier' => $r->nom_fichier,
                'taille' => $r->taille,
                // Liens relatifs signés : l'appli les complète avec l'adresse du serveur qu'elle utilise
                'url' => URL::temporarySignedRoute('files.ressource.mobile', now()->addHours(2), ['ressource' => $r->id], absolute: false),
                'download_url' => URL::temporarySignedRoute('files.ressource.mobile', now()->addHours(2), ['ressource' => $r->id, 'download' => 1], absolute: false),
                'termine' => $termine,
                'accessible' => $accessible,
            ];
        });

        $nbFaits = $liste->where('termine', true)->count();

        return [
            'id' => $lecon->id,
            'titre' => $lecon->titre,
            'description' => $lecon->description,
            'parcours' => ['id' => $lecon->parcours_id, 'nom' => $lecon->parcours?->nom],
            'chapitres' => $liste,
            'chapitres_total' => $liste->count(),
            'chapitres_termines' => $nbFaits,
            'pourcentage' => $liste->count() > 0 ? (int) round($nbFaits / $liste->count() * 100) : 0,
            'statut' => $this->statut($nbFaits, $liste->count()),
            'quiz' => $this->quizDeLecon($user, $lecon),
        ];
    }

    // ---------- Marquer un chapitre comme terminé ----------
    public function terminerChapitre(Request $request, Ressource $ressource)
    {
        $user = $request->user();
        $lecon = $ressource->lecon;
        $this->autoriser($user, $lecon);

        // Le chapitre précédent doit être terminé (même règle que l'affichage)
        $ordre = $lecon->ressources()->orderBy('created_at')->orderBy('id')->pluck('id')->values();
        $position = $ordre->search($ressource->id);
        if ($position > 0) {
            $precedent = $ordre[$position - 1];
            abort_unless(
                Progression::where('user_id', $user->id)->where('ressource_id', $precedent)->exists(),
                422,
                'Terminez d’abord le chapitre précédent.'
            );
        }

        Progression::firstOrCreate(
            ['user_id' => $user->id, 'ressource_id' => $ressource->id],
            ['lecon_id' => $lecon->id, 'termine_le' => now()]
        );

        return $this->show($request, $lecon);
    }

    // ---------- Outils ----------

    private function autoriser(User $user, ?Lecon $lecon): void
    {
        abort_unless($lecon, 404);
        abort_unless(
            $lecon->parcours_id === $user->parcours_id,
            403,
            'Cette formation fait partie d’un autre parcours. Contactez l’équipe du FabLab pour y accéder.'
        );
    }

    private function statut(int $faits, int $total): string
    {
        if ($total === 0) {
            return 'vide';
        }

        return $faits === 0 ? 'a_commencer' : ($faits >= $total ? 'termine' : 'en_cours');
    }

    /** QCM de la leçon (lien direct ou multiple), hors brouillons et archives. */
    private function requeteQuiz(User $user, $leconIds)
    {
        return Devoir::query()
            ->where('type', 'qcm')
            ->where('parcours_id', $user->parcours_id)
            ->whereIn('statut', ['programme', 'en_cours', 'termine'])
            ->where(fn ($q) => $q->whereIn('lecon_id', $leconIds)
                ->orWhereHas('lecons', fn ($q2) => $q2->whereIn('lecons.id', $leconIds)))
            ->has('questions');
    }

    private function quizParLecon(User $user, Collection $leconIds): array
    {
        if (! $user->parcours_id || $leconIds->isEmpty()) {
            return [];
        }

        $faits = ResultatQuiz::where('user_id', $user->id)->where('statut', 'termine')->pluck('devoir_id')->all();
        $compte = [];

        foreach ($this->requeteQuiz($user, $leconIds)->with('lecons:id')->get() as $d) {
            if (in_array($d->id, $faits, true) || QuizController::etatOuverture($d) !== 'ouvert') {
                continue;
            }
            foreach (collect([$d->lecon_id])->concat($d->lecons->pluck('id'))->filter()->unique() as $id) {
                $compte[$id] = ($compte[$id] ?? 0) + 1;
            }
        }

        return $compte;
    }

    private function quizDeLecon(User $user, Lecon $lecon): Collection
    {
        return $this->requeteQuiz($user, [$lecon->id])
            ->withCount('questions')
            ->orderByRaw('date_debut IS NULL, date_debut')
            ->get()
            ->map(fn (Devoir $d) => QuizController::resume($d, $user));
    }
}
