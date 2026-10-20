<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ConversationController extends Controller
{
    // ---------- Liste des conversations de l'utilisateur connecté ----------
    public function index(Request $request)
    {
        $user = $request->user();

        $conversations = $user->conversations()
            ->with(['dernierMessage.auteur:id,name', 'users:id,name,photo', 'parcours:id,nom'])
            ->withCount(['messages as unread_count' => function ($q) use ($user) {
                $q->where('auteur_id', '!=', $user->id)
                  ->where(function ($q2) use ($user) {
                      $q2->whereNull('conversation_user.last_read_at')
                         ->orWhereColumn('messages.created_at', '>', 'conversation_user.last_read_at');
                  });
            }])
            ->orderByDesc(
                Message::select('created_at')
                    ->whereColumn('conversation_id', 'conversations.id')
                    ->latest()
                    ->limit(1)
            )
            ->get()
            ->map(function ($conv) use ($user) {
                return [
                    'id'              => $conv->id,
                    'type'            => $conv->type,
                    'nom'             => $this->nomConversation($conv, $user),
                    'parcours'        => $conv->parcours?->nom,
                    'dernier_message' => $conv->dernierMessage ? [
                        'contenu'    => $conv->dernierMessage->contenu,
                        'auteur'     => $conv->dernierMessage->auteur?->name,
                        'created_at' => $conv->dernierMessage->created_at,
                    ] : null,
                    'unread_count'    => $conv->unread_count,
                    'membres'         => $conv->users->map(fn ($u) => [
                        'id'   => $u->id,
                        'name' => $u->name,
                    ]),
                ];
            });

        return $conversations;
    }

    // ---------- Messages d'une conversation ----------
    public function messages(Request $request, Conversation $conversation)
    {
        $this->authorizeConversation($request, $conversation);

        $messages = $conversation->messages()
            ->with('auteur:id,name,photo')
            ->orderBy('created_at')
            ->paginate(50);

        // Marquer comme lu
        $request->user()->conversations()->updateExistingPivot($conversation->id, [
            'last_read_at' => now(),
        ]);

        return $messages;
    }

    // ---------- Envoyer un message ----------
    public function storeMessage(Request $request, Conversation $conversation)
    {
        $this->authorizeConversation($request, $conversation);

        $validated = $request->validate([
            'contenu' => ['required', 'string', 'min:1', 'max:2000'],
        ]);

        $message = $conversation->messages()->create([
            'auteur_id' => $request->user()->id,
            'contenu'   => strip_tags($validated['contenu']),
        ]);

        // Mettre à jour last_read_at de l'auteur
        $request->user()->conversations()->updateExistingPivot($conversation->id, [
            'last_read_at' => now(),
        ]);

        return $message->load('auteur:id,name,photo');
    }

    // ---------- Ouvrir / créer une conversation privée ----------
    public function ouvrirPrivee(Request $request)
    {
        $validated = $request->validate([
            'user_id' => [
                'required',
                'integer',
                Rule::exists('users', 'id')->where('etablissement_id', $request->user()->etablissement_id),
            ],
        ]);

        $autreUserId = (int) $validated['user_id'];
        $moi = $request->user();

        if ($autreUserId === $moi->id) {
            return response()->json(['message' => 'Impossible de créer une conversation avec soi-même.'], 422);
        }

        // Chercher une conversation privée existante entre les deux
        $conversation = Conversation::where('type', 'privee')
            ->where('etablissement_id', $moi->etablissement_id)
            ->whereHas('users', fn ($q) => $q->where('users.id', $moi->id))
            ->whereHas('users', fn ($q) => $q->where('users.id', $autreUserId))
            ->first();

        if (! $conversation) {
            $conversation = DB::transaction(function () use ($moi, $autreUserId) {
                $conv = Conversation::create([
                    'etablissement_id' => $moi->etablissement_id,
                    'type'             => 'privee',
                ]);
                $conv->users()->attach([$moi->id, $autreUserId]);
                return $conv;
            });
        }

        return $conversation->load(['users:id,name,photo', 'dernierMessage']);
    }

    // ---------- Créer / récupérer le groupe général de l'établissement ----------
    public function groupeGeneral(Request $request)
    {
        $user = $request->user();

        $conversation = Conversation::firstOrCreate(
            [
                'etablissement_id' => $user->etablissement_id,
                'type'             => 'groupe_general',
            ],
            ['nom' => 'Groupe général']
        );

        // S'assurer que l'utilisateur est membre
        if (! $conversation->users()->where('users.id', $user->id)->exists()) {
            $conversation->users()->attach($user->id);
        }

        return $conversation->load(['users:id,name', 'dernierMessage']);
    }

    // ---------- Créer / récupérer le groupe d'un parcours ----------
    public function groupeParcours(Request $request, $parcoursId)
    {
        $user = $request->user();

        $parcours = \App\Models\Parcours::where('id', $parcoursId)
            ->where('etablissement_id', $user->etablissement_id)
            ->firstOrFail();

        $conversation = Conversation::firstOrCreate(
            [
                'etablissement_id' => $user->etablissement_id,
                'parcours_id'      => $parcours->id,
                'type'             => 'groupe_parcours',
            ],
            ['nom' => 'Groupe ' . $parcours->nom]
        );

        // Ajouter tous les membres du parcours + l'utilisateur courant
        $membresIds = User::where('etablissement_id', $user->etablissement_id)
            ->where(function ($q) use ($parcours) {
                $q->where('parcours_id', $parcours->id)
                  ->orWhereIn('role', ['fabmanager', 'admin', 'admin_global', 'formateur', 'manager']);
            })
            ->where('actif', true)
            ->pluck('id')
            ->push($user->id)
            ->unique();

        $conversation->users()->syncWithoutDetaching($membresIds);

        return $conversation->load(['users:id,name', 'dernierMessage']);
    }

    // ---------- Helpers ----------
    private function authorizeConversation(Request $request, Conversation $conversation): void
    {
        $estMembre = $conversation->users()
            ->where('users.id', $request->user()->id)
            ->exists();

        if (! $estMembre || $conversation->etablissement_id !== $request->user()->etablissement_id) {
            abort(403, 'Vous n\'êtes pas membre de cette conversation.');
        }
    }

    private function nomConversation(Conversation $conv, User $user): string
    {
        if ($conv->type === 'groupe_general') {
            return $conv->nom ?? 'Groupe général';
        }
        if ($conv->type === 'groupe_parcours') {
            return $conv->nom ?? ('Groupe ' . ($conv->parcours?->nom ?? ''));
        }
        // Privée : nom de l'autre personne
        $autre = $conv->users->firstWhere('id', '!=', $user->id);
        return $autre?->name ?? 'Conversation privée';
    }
}