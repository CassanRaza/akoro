<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcours;
use App\Models\Seance;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SeanceController extends Controller
{
    // Séances d'un parcours, classées par date et heure (lecture : tout utilisateur de l'établissement)
    public function index(Request $request, Parcours $parcour)
    {
        $this->authorizeParcours($request, $parcour);

        return Seance::where('parcours_id', $parcour->id)
            ->with('lecon:id,titre')
            ->orderBy('date')
            ->orderBy('heure_debut')
            ->get();
    }

    public function store(Request $request, Parcours $parcour)
    {
        $this->authorizeParcours($request, $parcour);

        $validated = $request->validate([
            'lecon_id' => [
                'nullable',
                Rule::exists('lecons', 'id')->where('parcours_id', $parcour->id),
            ],
            // « aujourd'hui » à l'heure du FabLab (le serveur est en UTC)
            'date' => ['bail', 'required', 'date_format:Y-m-d', 'after_or_equal:'.Seance::maintenant()->toDateString()],
            'heure_debut' => ['bail', 'required', 'date_format:H:i'],
            'heure_fin' => ['bail', 'required', 'date_format:H:i', 'after:heure_debut'],
        ], Rules::messagesSeance());

        // Pas deux séances qui se chevauchent dans le même parcours
        $conflit = Seance::where('parcours_id', $parcour->id)
            ->where('date', $validated['date'])
            ->where('heure_debut', '<', $validated['heure_fin'])
            ->where('heure_fin', '>', $validated['heure_debut'])
            ->exists();

        if ($conflit) {
            throw ValidationException::withMessages([
                'heure_debut' => ['Une séance existe déjà sur ce créneau pour ce parcours.'],
            ]);
        }

        $seance = Seance::create([
            ...$validated,
            'parcours_id' => $parcour->id,
        ]);

        return response()->json($seance->load('lecon:id,titre'), 201);
    }

    // QR code de la séance (équipe uniquement) + pointages en direct
    public function qr(Request $request, Seance $seance)
    {
        $this->authorizeParcours($request, $seance->parcours);
        $seance->loadMissing(['lecon:id,titre', 'parcours:id,nom']);
        [$ouverture, $fermeture] = $seance->fenetrePointage();
        $pointages = PresenceController::pointagesSeance($seance);

        return [
            'seance' => [
                'id' => $seance->id,
                'date' => $seance->date->toDateString(),
                'heure_debut' => substr($seance->heure_debut, 0, 5),
                'heure_fin' => substr($seance->heure_fin, 0, 5),
                'lecon' => $seance->lecon?->titre,
                'parcours' => $seance->parcours?->nom,
            ],
            'qr' => $seance->contenuQr(),
            'code' => $seance->code,
            'etat' => $seance->etatPointage(),
            'ouverture' => $ouverture->format('H:i'),
            'fermeture' => $fermeture->format('H:i'),
            'pointages' => $pointages,
            'presents' => collect($pointages)->whereNotNull('arrivee')->count(),
            'attendus' => count($pointages),
        ];
    }

    // Nouveau QR (si l'ancien a circulé) : l'ancien ne fonctionne plus
    public function regenererQr(Request $request, Seance $seance)
    {
        $this->authorizeParcours($request, $seance->parcours);
        $seance->update(['qr_token' => Seance::nouveauToken(), 'code' => Seance::nouveauCode()]);

        return $this->qr($request, $seance);
    }

    public function destroy(Request $request, Seance $seance)
    {
        $this->authorizeParcours($request, $seance->parcours);

        $seance->delete();

        return response()->json(['message' => 'Séance supprimée.']);
    }

    private function authorizeParcours(Request $request, Parcours $parcours): void
    {
        if ($parcours->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Ce parcours n'appartient pas à votre établissement.");
        }
    }
}