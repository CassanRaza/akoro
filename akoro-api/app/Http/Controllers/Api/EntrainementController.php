<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lecon;
use App\Services\QuestionGenerator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

/**
 * Entraînement libre du bénéficiaire (application mobile) : quiz rapide généré par l'IA
 * à partir des documents d'une formation, jouable à tout moment.
 * Rien n'est enregistré : les réponses sont corrigées sur le téléphone et le score n'est pas visible par l'équipe.
 */
class EntrainementController extends Controller
{
    // Questions préparées d'un coup par formation, puis tirées au hasard à chaque partie
    private const TAILLE_RESERVE = 10;

    private const DUREE_RESERVE_HEURES = 6;

    public function generer(Request $request, QuestionGenerator $generator)
    {
        $user = $request->user();

        $data = $request->validate([
            'lecon_id' => ['required', 'integer'],
            'nombre' => ['nullable', 'integer', Rule::in([5, 10])],
        ], [
            'lecon_id.required' => 'Choisissez une formation.',
            'nombre.in' => 'Choisissez 5 ou 10 questions.',
        ]);

        $lecon = Lecon::with(['ressources', 'parcours:id,nom'])->find($data['lecon_id']);
        abort_unless(
            $lecon && $lecon->parcours_id === $user->parcours_id,
            403,
            'Cette formation ne fait pas partie de votre parcours.'
        );
        abort_if(
            $lecon->ressources->isEmpty(),
            422,
            'Cette formation n’a pas encore de document : l’entraînement sera possible dès que l’équipe en aura publié un.'
        );

        $nombre = $data['nombre'] ?? 5;

        // La réserve est refaite si un document de la formation change
        $empreinte = $lecon->ressources->map(fn ($r) => $r->id.'-'.$r->updated_at?->timestamp)->implode(',');
        $cle = 'entrainement:'.$lecon->id.':'.md5($empreinte);

        $reserve = Cache::get($cle);
        if (! is_array($reserve) || count($reserve) < $nombre) {
            // La première préparation peut prendre plus d'une minute
            set_time_limit(300);

            try {
                $reserve = $generator->genererPourLecons(collect([$lecon]), self::TAILLE_RESERVE, $lecon->parcours?->nom);
            } catch (\RuntimeException $e) {
                Log::warning('Entraînement : génération impossible', ['lecon' => $lecon->id, 'erreur' => $e->getMessage()]);
                abort(422, 'FAB’IA n’a pas pu préparer ce quiz pour le moment. Réessayez dans une minute ou choisissez une autre formation.');
            }

            Cache::put($cle, $reserve, now()->addHours(self::DUREE_RESERVE_HEURES));
        }

        return [
            'formation' => $lecon->titre,
            'questions' => collect($reserve)->shuffle()->take($nombre)->map(fn (array $q) => [
                'enonce' => $q['enonce'],
                'choix' => collect($q['choix'])->shuffle()->map(fn (array $c) => [
                    'texte' => $c['texte'],
                    'est_correct' => (bool) $c['est_correct'],
                ])->values(),
            ])->values(),
        ];
    }
}
