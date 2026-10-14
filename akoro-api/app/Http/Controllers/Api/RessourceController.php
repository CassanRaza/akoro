<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Lecon;
use App\Models\Ressource;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class RessourceController extends Controller
{
    // Ajoute un document (PDF, Word, PowerPoint, image...) à une leçon
    public function store(Request $request, Lecon $lecon)
    {
        $this->authorizeLecon($request, $lecon);

        $request->validate([
            'fichier' => Rules::fichier(),
        ], Rules::messagesFichier());

        $fichier = $request->file('fichier');
        $nomOriginal = Str::limit($fichier->getClientOriginalName(), 150, '');
        $extension = strtolower($fichier->getClientOriginalExtension());
        $titre = Str::limit(pathinfo($nomOriginal, PATHINFO_FILENAME), 100, '');
        $taille = $fichier->getSize();

        // Stocké dans un espace privé (jamais accessible par une URL publique)
        $chemin = $fichier->store('ressources', 'local');

        $ressource = $lecon->ressources()->create([
            'titre' => $titre !== '' ? $titre : 'Document',
            'type' => $extension,
            'chemin' => $chemin,
            'nom_fichier' => $nomOriginal,
            'taille' => $taille,
        ]);

        return response()->json($ressource, 201);
    }

    public function destroy(Request $request, Ressource $ressource)
    {
        $this->authorizeLecon($request, $ressource->lecon);

        Storage::disk('local')->delete($ressource->chemin);
        $ressource->delete();

        return response()->json(['message' => 'Document supprimé.']);
    }

    private function authorizeLecon(Request $request, Lecon $lecon): void
    {
        if ($lecon->parcours->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Cette leçon n'appartient pas à votre établissement.");
        }
    }
}