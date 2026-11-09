<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Services\FabiaAssistant;
use App\Support\Roles;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ConversationController extends Controller
{
    // ---------- Liste des conversations de l'utilisateur connecté ----------
    public function index(Request $request)
    {
        $user = $request->user();

        return $user->conversations()
            ->with(['dernierMessage.auteur:id,name', 'users:id,name,photo,role', 'parcours:id,nom'])
            ->withCount(['messages as unread_count' => function ($q) use ($user) {
                $q->where('auteur_id', '!=', $user->id)
                  ->whereNull('supprime_le')
                  ->where(function ($q2) {
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
                $autre = $conv->type === 'privee' ? $conv->users->firstWhere('id', '!=', $user->id) : null;
                $dernier = $conv->dernierMessage;

                return [
                    'id'              => $conv->id,
                    'type'            => $conv->type,
                    'nom'             => $this->nomConversation($conv, $user),
                    'parcours'        => $conv->parcours?->nom,
                    'avatar_url'      => $autre?->photo_url,
                    'interlocuteur_admin' => $autre ? in_array($autre->role, Roles::ADMINS, true) : false,
                    'dernier_message' => $dernier ? [
                        'contenu'    => $dernier->supprime_le ? 'Message supprimé' : $dernier->contenu,
                        'supprime'   => (bool) $dernier->supprime_le,
                        'auteur'     => $dernier->auteur_id === $user->id ? 'Vous' : $dernier->auteur?->name,
                        'created_at' => $dernier->created_at,
                    ] : null,
                    'unread_count'    => $conv->unread_count,
                    'membres'         => $conv->users->map(fn ($u) => [
                        'id'    => $u->id,
                        'name'  => $u->name,
                        'admin' => in_array($u->role, Roles::ADMINS, true),
                    ]),
                ];
            });
    }

    // ---------- Messages : les 150 plus récents, du plus ancien au plus récent ----------
    public function messages(Request $request, Conversation $conversation)
    {
        $this->authorizeConversation($request, $conversation);
        $user = $request->user();

        $messages = $conversation->messages()
            ->reorder()
            ->with([
                'auteur:id,name,photo,role',
                'replyTo:id,auteur_id,contenu,supprime_le',
                'replyTo.auteur:id,name',
                'reactions.user:id,name',
            ])
            ->latest()
            ->latest('id')
            ->limit(150)
            ->get()
            ->reverse()
            ->values();

        // Marquer comme lu
        $user->conversations()->updateExistingPivot($conversation->id, ['last_read_at' => now()]);

        // Dernière lecture des autres membres (indicateur « Vu »)
        $lectures = $conversation->users()
            ->where('users.id', '!=', $user->id)
            ->get(['users.id', 'users.name'])
            ->map(fn ($u) => [
                'user_id'      => $u->id,
                'name'         => $u->name,
                'last_read_at' => $u->pivot->last_read_at,
            ])
            ->filter(fn ($l) => $l['last_read_at'])
            ->values();

        return [
            'messages'              => $messages->map(fn ($m) => $this->formatMessage($m, $user)),
            'lectures'              => $lectures,
            'reactions_disponibles' => Message::REACTIONS,
            'delai_modification'    => Message::DELAI_MODIFICATION_MINUTES,
        ];
    }

    // ---------- Envoyer un message ----------
    public function storeMessage(Request $request, Conversation $conversation)
    {
        $this->authorizeConversation($request, $conversation);

        $validated = $request->validate([
            'contenu'     => ['required', 'string', 'min:1', 'max:2000'],
            'reply_to_id' => [
                'nullable',
                'integer',
                Rule::exists('messages', 'id')->where('conversation_id', $conversation->id),
            ],
        ], [
            'contenu.required' => 'Le message est vide.',
            'contenu.max'      => 'Le message est trop long (2000 caractères maximum).',
        ]);

        $message = $conversation->messages()->create([
            'auteur_id'   => $request->user()->id,
            'reply_to_id' => $validated['reply_to_id'] ?? null,
            'contenu'     => strip_tags($validated['contenu']),
        ]);

        $request->user()->conversations()->updateExistingPivot($conversation->id, ['last_read_at' => now()]);

        return $this->formatMessage(
            $message->load(['auteur:id,name,photo,role', 'replyTo:id,auteur_id,contenu,supprime_le', 'replyTo.auteur:id,name', 'reactions']),
            $request->user()
        );
    }

    // ---------- Modifier son message (dans les 15 minutes) ----------
    public function updateMessage(Request $request, Message $message)
    {
        $this->authorizeConversation($request, $message->conversation);
        abort_unless(
            $message->modifiablePar($request->user()),
            403,
            'Vous ne pouvez modifier que vos propres messages, dans les '.Message::DELAI_MODIFICATION_MINUTES.' minutes qui suivent leur envoi.'
        );

        $validated = $request->validate([
            'contenu' => ['required', 'string', 'min:1', 'max:2000'],
        ], ['contenu.required' => 'Le message ne peut pas être vide.']);

        $contenu = strip_tags($validated['contenu']);
        if ($contenu !== $message->contenu) {
            $message->update(['contenu' => $contenu, 'modifie_le' => now()]);
        }

        return $this->formatMessage(
            $message->fresh(['auteur:id,name,photo,role', 'replyTo.auteur:id,name', 'reactions.user:id,name']),
            $request->user()
        );
    }

    // ---------- Supprimer un message pour tout le monde ----------
    public function destroyMessage(Request $request, Message $message)
    {
        $conversation = $message->conversation;
        $this->authorizeConversation($request, $conversation);
        $user = $request->user();

        // L'auteur, ou un responsable du FabLab pour modérer un groupe
        $moderation = $conversation->type !== 'privee' && in_array($user->role, Roles::COMPLETS, true);
        abort_unless($message->auteur_id === $user->id || $moderation, 403, 'Vous ne pouvez supprimer que vos propres messages.');

        if (! $message->estSupprime()) {
            $message->reactions()->delete();
            $message->update(['contenu' => '', 'supprime_le' => now()]);
        }

        return $this->formatMessage($message->fresh(['auteur:id,name,photo,role', 'reactions']), $user);
    }

    // ---------- Réagir à un message (même emoji = retirer la réaction) ----------
    public function reagir(Request $request, Message $message)
    {
        $this->authorizeConversation($request, $message->conversation);
        abort_if($message->estSupprime(), 422, 'Ce message a été supprimé.');

        $validated = $request->validate(['emoji' => ['required', 'string', 'max:16']]);

        $user = $request->user();
        $existante = $message->reactions()->where('user_id', $user->id)->first();

        if ($existante && $existante->emoji === $validated['emoji']) {
            $existante->delete();
        } else {
            $message->reactions()->updateOrCreate(['user_id' => $user->id], ['emoji' => $validated['emoji']]);
        }

        return $this->formatMessage(
            $message->fresh(['auteur:id,name,photo,role', 'replyTo.auteur:id,name', 'reactions.user:id,name']),
            $user
        );
    }

    // ---------- Résumé de la conversation par FAB'IA ----------
    public function resumer(Request $request, Conversation $conversation, FabiaAssistant $fabia)
    {
        $this->authorizeConversation($request, $conversation);

        return $fabia->resumerConversation($request->user(), $conversation);
    }

    // ---------- Personnes joignables en privé (tout l'établissement) ----------
    public function contacts(Request $request)
    {
        $moi = $request->user();

        return User::where('etablissement_id', $moi->etablissement_id)
            ->where('id', '!=', $moi->id)
            ->where('actif', true)
            ->with('parcours:id,nom')
            ->orderByRaw("CASE WHEN role = 'beneficiaire' THEN 1 ELSE 0 END")
            ->orderBy('name')
            ->get(['id', 'name', 'role', 'photo', 'parcours_id'])
            ->map(fn ($u) => [
                'id'        => $u->id,
                'name'      => $u->name,
                'photo_url' => $u->photo_url,
                'admin'     => in_array($u->role, Roles::ADMINS, true),
                'detail'    => in_array($u->role, Roles::ADMINS, true) ? 'Équipe du FabLab' : ($u->parcours?->nom ?? 'Bénéficiaire'),
            ]);
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
    private function formatMessage(Message $m, User $user): array
    {
        $supprime = $m->estSupprime();

        return [
            'id'              => $m->id,
            'conversation_id' => $m->conversation_id,
            'auteur_id'       => $m->auteur_id,
            'auteur'          => $m->auteur ? [
                'id'        => $m->auteur->id,
                'name'      => $m->auteur->name,
                'photo_url' => $m->auteur->photo_url,
                'admin'     => in_array($m->auteur->role, Roles::ADMINS, true),
            ] : null,
            'contenu'       => $supprime ? null : $m->contenu,
            'supprime'      => $supprime,
            'modifie'       => (bool) $m->modifie_le,
            'created_at'    => $m->created_at,
            'peut_modifier' => $m->modifiablePar($user),
            'reply_to'      => $m->replyTo ? [
                'id'       => $m->replyTo->id,
                'auteur'   => $m->replyTo->auteur?->name,
                'extrait'  => $m->replyTo->supprime_le ? null : Str::limit($m->replyTo->contenu, 120),
                'supprime' => (bool) $m->replyTo->supprime_le,
            ] : null,
            'reactions' => $m->reactions->groupBy('emoji')->map(fn ($lot, $emoji) => [
                'emoji' => $emoji,
                'total' => $lot->count(),
                'noms'  => $lot->map(fn ($r) => $r->user_id === $user->id ? 'Vous' : $r->user?->name)->filter()->values(),
                'moi'   => $lot->contains('user_id', $user->id),
            ])->values(),
        ];
    }

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