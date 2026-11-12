<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Message;
use Illuminate\Http\Request;

/**
 * Cloche de l'application mobile : avis enregistrés (devoir programmé, devoir corrigé,
 * justificatif traité…) + nombre de messages non lus.
 */
class MesNotificationsController extends Controller
{
    private const TITRES = [
        'devoir_programme' => 'Nouveau devoir',
        'devoir_corrige' => 'Devoir corrigé',
        'absence_traitee' => 'Justificatif d’absence',
    ];

    public function index(Request $request)
    {
        $user = $request->user();

        return [
            'notifications' => $user->notifications()->latest()->limit(30)->get()->map(function ($n) {
                $data = $n->data;
                $type = $data['type'] ?? 'info';

                return [
                    'id' => $n->id,
                    'type' => $type,
                    'titre' => $data['titre_avis'] ?? (self::TITRES[$type] ?? 'Information'),
                    'message' => $data['message'] ?? '',
                    'devoir_id' => $data['devoir_id'] ?? null,
                    'devoir_type' => $data['devoir_type'] ?? null,
                    'lu' => $n->read_at !== null,
                    'date' => $n->created_at?->toIso8601String(),
                ];
            })->values(),
            'non_lues' => $user->unreadNotifications()->count(),
            'messages_non_lus' => $this->messagesNonLus($user->id),
        ];
    }

    // Ouverture de la liste : tout est considéré comme lu
    public function marquerLues(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();

        return response()->noContent();
    }

    // Même calcul que l'accueil et la liste des conversations
    private function messagesNonLus(int $userId): int
    {
        return Message::query()
            ->join('conversation_user as cu', function ($j) use ($userId) {
                $j->on('cu.conversation_id', '=', 'messages.conversation_id')->where('cu.user_id', $userId);
            })
            ->where('messages.auteur_id', '!=', $userId)
            ->whereNull('messages.supprime_le')
            ->where(fn ($q) => $q->whereNull('cu.last_read_at')->orWhereColumn('messages.created_at', '>', 'cu.last_read_at'))
            ->count();
    }
}
