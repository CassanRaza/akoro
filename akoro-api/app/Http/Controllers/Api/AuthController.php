<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Etablissement;
use App\Models\Parcours;
use App\Models\User;
use App\Support\Roles;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    // Inscription publique d'un bénéficiaire (mobile) : le rôle est TOUJOURS "beneficiaire".
    // Compte créé EN ATTENTE, sans token : le Super Admin le valide depuis la liste des bénéficiaires (web).
    public function register(Request $request)
    {
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => Rules::nomPersonne(),
            'email' => Rules::email(unique: true),
            'telephone' => Rules::telephone(),
            'adresse' => Rules::adresse(),
            'password' => Rules::password(confirm: true),
            'etablissement_id' => ['required', Rule::exists('etablissements', 'id')->where('actif', true)],
            'parcours_id' => [
                'nullable',
                Rule::exists('parcours', 'id')->where('etablissement_id', $request->input('etablissement_id')),
            ],
            'photo' => Rules::photo(),
        ], Rules::messages());

        $user = User::create([
            'name' => $validated['nom'],
            'email' => $validated['email'],
            'telephone' => $validated['telephone'],
            'adresse' => $validated['adresse'],
            'password' => Hash::make($validated['password']),
            'etablissement_id' => $validated['etablissement_id'],
            'parcours_id' => $validated['parcours_id'] ?? null,
            'role' => Roles::BENEFICIAIRE,
            'actif' => false,
            'valide_le' => null,
            'photo' => $request->hasFile('photo') ? $request->file('photo')->store('photos', 'local') : null,
        ]);

        return response()->json([
            'message' => 'Inscription envoyée. Le Super Admin doit valider votre compte avant votre première connexion.',
        ], 201);
    }

    // Choix proposés au formulaire d'inscription bénéficiaire (mobile) : FabLabs actifs et leurs parcours
    public function optionsInscription()
    {
        return Etablissement::where('actif', true)
            ->orderBy('nom')
            ->get(['id', 'nom', 'adresse'])
            ->map(fn ($e) => [
                'id' => $e->id,
                'nom' => $e->nom,
                'adresse' => $e->adresse,
                'parcours' => Parcours::where('etablissement_id', $e->id)->orderBy('nom')->get(['id', 'nom']),
            ]);
    }

    // Inscription publique d'un admin (web) : compte créé EN ATTENTE, sans token.
    // Le rôle choisi est une demande : le Super Admin le confirme ou le change à la validation.
    public function registerAdmin(Request $request)
    {
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => Rules::nomPersonne(),
            'email' => Rules::email(unique: true),
            'telephone' => Rules::telephone(),
            'adresse' => Rules::adresse(),
            'role' => ['bail', 'required', Rule::in(Roles::CHOISISSABLES)],
            'password' => Rules::password(confirm: true),
            'photo' => Rules::photo(),
        ], Rules::messages());

        // Pour l'instant il n'y a qu'un FabLab : la demande est rattachée au premier établissement actif.
        $etablissement = Etablissement::where('actif', true)->orderBy('id')->first();

        if (! $etablissement) {
            return response()->json(['message' => 'Aucun établissement disponible pour le moment.'], 422);
        }

        User::create([
            'name' => $validated['nom'],
            'email' => $validated['email'],
            'telephone' => $validated['telephone'],
            'adresse' => $validated['adresse'],
            'password' => Hash::make($validated['password']),
            'etablissement_id' => $etablissement->id,
            'role' => $validated['role'],
            'actif' => false,
            'photo' => $request->hasFile('photo') ? $request->file('photo')->store('photos', 'local') : null,
        ]);

        return response()->json([
            'message' => 'Demande envoyée. Un Super Admin doit valider votre compte et confirmer votre rôle avant votre première connexion.',
        ], 201);
    }

    public function login(Request $request)
    {
        Rules::clean($request);

        $credentials = $request->validate([
            'email' => ['bail', 'required', 'string', 'email'],
            'password' => ['required', 'string'],
        ], Rules::messages());

        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Identifiants incorrects.'],
            ]);
        }

        if (! $user->actif) {
            return response()->json([
                'message' => $user->valide_le === null
                    ? 'Votre inscription est en attente de validation par le Super Admin. Vous pourrez vous connecter dès qu’il aura activé votre compte.'
                    : 'Votre compte est désactivé. Contactez l’équipe du FabLab.',
                'en_attente' => $user->valide_le === null,
            ], 403);
        }

        $token = $user->createToken('akoro-token')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token]);
    }

    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => ['required', 'string', 'current_password'],
            'password' => [...Rules::password(confirm: true), 'different:current_password'],
        ], [
            ...Rules::messages(),
            'current_password.required' => 'Saisissez votre mot de passe actuel.',
            'current_password.current_password' => 'Le mot de passe actuel est incorrect.',
            'password.different' => 'Le nouveau mot de passe doit être différent de l’actuel.',
        ]);

        $request->user()->update([
            'password' => Hash::make($request->input('password')),
        ]);

        return response()->json(['message' => 'Mot de passe mis à jour avec succès.']);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $request->merge(['nom' => $request->input('name')]);
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => Rules::nomPersonne(),
            'email' => [
                ...Rules::email(),
                Rule::unique('users', 'email')->ignore($user->id),
            ],
            'telephone' => Rules::telephone(),
            'adresse' => Rules::adresse(),
        ], Rules::messages());

        $user->update([
            'name' => $validated['nom'],
            'email' => $validated['email'],
            'telephone' => $validated['telephone'],
            'adresse' => $validated['adresse'],
        ]);

        return $user->fresh();
    }

    // Ma photo de profil (tous les rôles, application mobile comprise)
    public function uploadPhoto(Request $request)
    {
        $request->validate([
            'photo' => ['bail', 'required', ...array_slice(Rules::photo(), 1)],
        ], Rules::messages());

        $user = $request->user();
        if ($user->photo) {
            Storage::disk('local')->delete($user->photo);
        }
        $user->update(['photo' => $request->file('photo')->store('photos', 'local')]);

        return $user->fresh();
    }

    public function deletePhoto(Request $request)
    {
        $user = $request->user();
        if ($user->photo) {
            Storage::disk('local')->delete($user->photo);
            $user->update(['photo' => null]);
        }

        return $user->fresh();
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnecté avec succès.']);
    }
}
