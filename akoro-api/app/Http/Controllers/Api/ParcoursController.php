<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Parcours;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ParcoursController extends Controller
{
    // Liste des parcours de l'établissement de l'utilisateur connecté, avec le nombre de leçons
    public function index(Request $request)
    {
        return Parcours::where('etablissement_id', $request->user()->etablissement_id)
            ->withCount('lecons')
            ->orderBy('nom')
            ->get();
    }

    // Création d'un parcours (réservé au FabManager, voir routes)
    public function store(Request $request)
    {
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => [
                ...Rules::libelle(),
                Rule::unique('parcours', 'nom')->where('etablissement_id', $request->user()->etablissement_id),
            ],
            'description' => ['nullable', 'string', 'max:500'],
        ], Rules::messagesLibelle());

        $parcours = Parcours::create([
            ...$validated,
            'etablissement_id' => $request->user()->etablissement_id,
        ]);

        return response()->json($parcours, 201);
    }

    public function show(Request $request, Parcours $parcour)
    {
        $this->authorizeTenant($request, $parcour);
        return $parcour;
    }

    public function update(Request $request, Parcours $parcour)
    {
        $this->authorizeTenant($request, $parcour);
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => [
                'sometimes',
                ...Rules::libelle(),
                Rule::unique('parcours', 'nom')
                    ->where('etablissement_id', $request->user()->etablissement_id)
                    ->ignore($parcour->id),
            ],
            'description' => ['nullable', 'string', 'max:500'],
        ], Rules::messagesLibelle());

        $parcour->update($validated);
        return $parcour;
    }

    public function destroy(Request $request, Parcours $parcour)
    {
        $this->authorizeTenant($request, $parcour);

        // La base supprime les leçons en cascade, mais pas les fichiers : on les efface ici
        foreach ($parcour->lecons()->with('ressources')->get() as $lecon) {
            foreach ($lecon->ressources as $ressource) {
                Storage::disk('local')->delete($ressource->chemin);
            }
        }

        $parcour->delete();
        return response()->json(['message' => 'Parcours supprimé.']);
    }

    // Empêche un FabManager d'un autre établissement de toucher ce parcours
    private function authorizeTenant(Request $request, Parcours $parcour): void
    {
        if ($parcour->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Ce parcours n'appartient pas à votre établissement.");
        }
    }
}