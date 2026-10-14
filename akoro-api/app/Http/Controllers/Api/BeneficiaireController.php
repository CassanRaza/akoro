<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\AbsenceGenerator;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class BeneficiaireController extends Controller
{
    // Liste paginée des bénéficiaires de l'établissement, avec recherche et filtre
    public function index(Request $request)
    {
        $query = User::where('etablissement_id', $request->user()->etablissement_id)
            ->where('role', 'beneficiaire')
            ->with('parcours');

        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($parcoursId = $request->query('parcours_id')) {
            $query->where('parcours_id', $parcoursId);
        }

        return $query->orderBy('created_at', 'desc')->paginate(10);
    }

    // Fiche détaillée : profil, parcours, photo, absences et présences
    public function show(Request $request, User $beneficiaire, AbsenceGenerator $generator)
    {
        $this->authorizeBeneficiaire($request, $beneficiaire);

        // Met à jour les absences des séances terminées avant d'afficher
        $generator->generer($beneficiaire->etablissement_id);

        $beneficiaire->load('parcours:id,nom');

        $absences = $beneficiaire->absences()
            ->with(['lecon:id,titre', 'seance:id,heure_debut,heure_fin'])
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->get();

        $presences = $beneficiaire->presences()
            ->orderByDesc('date')
            ->limit(30)
            ->get();

        return [
            ...$beneficiaire->toArray(),
            'absences' => $absences,
            'presences' => $presences,
        ];
    }

    public function update(Request $request, User $beneficiaire)
    {
        $this->authorizeBeneficiaire($request, $beneficiaire);

        $validated = $request->validate([
            'parcours_id' => [
                'nullable',
                Rule::exists('parcours', 'id')->where('etablissement_id', $request->user()->etablissement_id),
            ],
            'actif' => 'sometimes|boolean',
        ], Rules::messages());

        $beneficiaire->update($validated);

        // Un compte désactivé perd immédiatement ses sessions ouvertes (mobile compris)
        if (array_key_exists('actif', $validated) && ! $beneficiaire->actif) {
            $beneficiaire->tokens()->delete();
        }

        return $beneficiaire->load('parcours');
    }

    // Ajoute ou remplace la photo (stockée dans l'espace privé)
    public function uploadPhoto(Request $request, User $beneficiaire)
    {
        $this->authorizeBeneficiaire($request, $beneficiaire);

        $request->validate([
            'photo' => ['bail', 'required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
        ], $this->messagesPhoto());

        if ($beneficiaire->photo) {
            Storage::disk('local')->delete($beneficiaire->photo);
        }

        $beneficiaire->update([
            'photo' => $request->file('photo')->store('photos', 'local'),
        ]);

        return $beneficiaire->fresh()->load('parcours');
    }

    public function deletePhoto(Request $request, User $beneficiaire)
    {
        $this->authorizeBeneficiaire($request, $beneficiaire);

        if ($beneficiaire->photo) {
            Storage::disk('local')->delete($beneficiaire->photo);
            $beneficiaire->update(['photo' => null]);
        }

        return $beneficiaire->fresh()->load('parcours');
    }

    // Un FabManager ne touche que les bénéficiaires de son établissement
    private function authorizeBeneficiaire(Request $request, User $beneficiaire): void
    {
        if ($beneficiaire->role !== 'beneficiaire'
            || $beneficiaire->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Ce bénéficiaire n'appartient pas à votre établissement.");
        }
    }

    private function messagesPhoto(): array
    {
        return [
            'photo.required' => 'Veuillez choisir une photo.',
            'photo.image' => 'Le fichier doit être une image.',
            'photo.mimes' => 'Formats acceptés : JPG, PNG ou WEBP.',
            'photo.max' => 'La photo est trop volumineuse (2 Mo maximum).',
            'photo.uploaded' => "La photo n'a pas pu être envoyée (trop volumineuse pour le serveur).",
        ];
    }
}