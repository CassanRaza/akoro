<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lecon;
use App\Models\Parcours;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class LeconController extends Controller
{
    // Leçons d'un parcours avec leurs documents (lecture : tout utilisateur connecté de l'établissement)
    public function index(Request $request, Parcours $parcour)
    {
        $this->authorizeParcours($request, $parcour);

        return $parcour->lecons()
            ->with(['ressources' => fn ($q) => $q->orderBy('created_at')])
            ->orderBy('ordre')
            ->get();
    }

    public function store(Request $request, Parcours $parcour)
    {
        $this->authorizeParcours($request, $parcour);
        Rules::clean($request);

        $validated = $request->validate([
            'titre' => [
                ...Rules::libelle(),
                Rule::unique('lecons', 'titre')->where('parcours_id', $parcour->id),
            ],
            'description' => ['nullable', 'string', 'max:1000'],
        ], Rules::messagesTitre());

        $lecon = $parcour->lecons()->create([
            ...$validated,
            'ordre' => ($parcour->lecons()->max('ordre') ?? 0) + 1,
        ]);

        return response()->json($lecon->load('ressources'), 201);
    }

    public function update(Request $request, Lecon $lecon)
    {
        $this->authorizeLecon($request, $lecon);
        Rules::clean($request);

        $validated = $request->validate([
            'titre' => [
                'sometimes',
                ...Rules::libelle(),
                Rule::unique('lecons', 'titre')
                    ->where('parcours_id', $lecon->parcours_id)
                    ->ignore($lecon->id),
            ],
            'description' => ['nullable', 'string', 'max:1000'],
        ], Rules::messagesTitre());

        $lecon->update($validated);

        return $lecon->load('ressources');
    }

    public function destroy(Request $request, Lecon $lecon)
    {
        $this->authorizeLecon($request, $lecon);

        foreach ($lecon->ressources as $ressource) {
            Storage::disk('local')->delete($ressource->chemin);
        }

        $lecon->delete();

        return response()->json(['message' => 'Leçon supprimée.']);
    }

    private function authorizeParcours(Request $request, Parcours $parcours): void
    {
        if ($parcours->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Ce parcours n'appartient pas à votre établissement.");
        }
    }

    private function authorizeLecon(Request $request, Lecon $lecon): void
    {
        $this->authorizeParcours($request, $lecon->parcours);
    }
}