<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Etablissement;
use App\Models\User;
use App\Support\Roles;
use App\Support\Rules;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    // Inscription publique d'un bénéficiaire (mobile) : le rôle est TOUJOURS "beneficiaire"
    public function register(Request $request)
    {
        Rules::clean($request);

        $validated = $request->validate([
            'nom' => Rules::nomPersonne(),
            'email' => Rules::email(unique: true),
            'telephone' => Rules::telephone(),
            'adresse' => Rules::adresse(),
            'password' => Rules::password(),
            'etablissement_id' => ['required', 'exists:etablissements,id'],
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
            'actif' => true,
            'photo' => $request->hasFile('photo') ? $request->file('photo')->store('photos', 'local') : null,
        ]);

        $token = $user->createToken('akoro-token')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token], 201);
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
                'message' => 'Votre compte est en attente de validation ou désactivé. Contactez un Super Admin.',
            ], 403);
        }

        $token = $user->createToken('akoro-token')->plainTextToken;

        return response()->json(['user' => $user, 'token' => $token]);
    }

    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => ['required', 'string', 'current_password'],
            'password' => Rules::password(confirm: true),
        ], Rules::messages());

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

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnecté avec succès.']);
    }
}
