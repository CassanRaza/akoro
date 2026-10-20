<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\Roles;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    // Liste des admins de l'établissement (comptes en attente en premier). Réservée au Super Admin.
    public function index(Request $request)
    {
        return User::where('etablissement_id', $request->user()->etablissement_id)
            ->whereIn('role', Roles::ADMINS)
            ->orderBy('actif')
            ->orderBy('created_at', 'desc')
            ->get();
    }

    // Fiche accessible au Super Admin et à l'administrateur concerné.
    public function show(Request $request, User $admin)
    {
        $this->authorizeAdmin($request, $admin);

        return $admin;
    }

    // Valider, désactiver ou changer le rôle : réservé au Super Admin (vérifié ici ET dans les routes)
    public function update(Request $request, User $admin)
    {
        $current = $request->user();

        if ($current->role !== Roles::ADMIN_GLOBAL) {
            abort(403, "Seul un Super Admin peut valider, désactiver ou changer le rôle d'un administrateur.");
        }

        $this->authorizeAdmin($request, $admin);

        if ($admin->id === $current->id) {
            abort(422, 'Vous ne pouvez pas modifier votre propre compte.');
        }

        $validated = $request->validate([
            'actif' => ['sometimes', 'boolean'],
            'role' => ['sometimes', Rule::in(Roles::CHOISISSABLES)],
        ], Rules::messages());

        if (! $validated) {
            abort(422, 'Aucune modification demandée.');
        }

        if (isset($validated['role']) && $admin->role === Roles::ADMIN_GLOBAL) {
            abort(422, "Le rôle d'un Super Admin ne peut pas être modifié ici.");
        }

        $admin->update($validated);

        // Un admin désactivé perd immédiatement ses sessions ouvertes
        if (array_key_exists('actif', $validated) && ! $admin->actif) {
            $admin->tokens()->delete();
        }

        return $admin->fresh();
    }

    // Photo de profil : chacun la sienne, ou le Super Admin pour tous
    public function uploadPhoto(Request $request, User $admin)
    {
        $this->authorizePhoto($request, $admin);

        $request->validate([
            'photo' => ['bail', 'required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:2048'],
        ], Rules::messages());

        if ($admin->photo) {
            Storage::disk('local')->delete($admin->photo);
        }

        $admin->update([
            'photo' => $request->file('photo')->store('photos', 'local'),
        ]);

        return $admin->fresh();
    }

    public function deletePhoto(Request $request, User $admin)
    {
        $this->authorizePhoto($request, $admin);

        if ($admin->photo) {
            Storage::disk('local')->delete($admin->photo);
            $admin->update(['photo' => null]);
        }

        return $admin->fresh();
    }

    private function authorizeAdmin(Request $request, User $admin): void
    {
        if (! in_array($admin->role, Roles::ADMINS, true)
            || $admin->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, "Cet administrateur n'appartient pas à votre établissement.");
        }

        if ($request->user()->id !== $admin->id
            && $request->user()->role !== Roles::ADMIN_GLOBAL) {
            abort(403, "Seul un Super Admin peut consulter la fiche d'un autre administrateur.");
        }
    }

    private function authorizePhoto(Request $request, User $admin): void
    {
        $this->authorizeAdmin($request, $admin);

        $current = $request->user();

        if ($current->id !== $admin->id && $current->role !== Roles::ADMIN_GLOBAL) {
            abort(403, 'Vous ne pouvez modifier que votre propre photo.');
        }
    }
}