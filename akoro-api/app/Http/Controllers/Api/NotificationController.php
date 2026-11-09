<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Devoir;
use App\Models\Message;
use App\Models\Parcours;
use App\Models\Seance;
use App\Models\Soumission;
use App\Models\User;
use App\Support\Roles;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Cloche de notifications + icône de messagerie de l'interface admin.
 * Appel léger, fait depuis toutes les pages.
 */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $etabId = $user->etablissement_id;
        $voitFiches = in_array($user->role, Roles::COMPLETS, true);

        return [
            'alertes' => $etabId ? $this->alertes($etabId, $voitFiches) : [],
            'messagerie' => $this->messagerie($user),
        ];
    }

    // Chaque alerte a un id stable : le navigateur s'en sert pour savoir ce qui a déjà été vu.
    private function alertes(int $etabId, bool $voitFiches): Collection
    {
        $dansEtab = fn ($q) => $q->where('etablissement_id', $etabId);
        $alertes = collect();

        Absence::where('statut', 'a_valider')
            ->whereHas('user', $dansEtab)
            ->with(['user:id,name', 'lecon:id,titre'])
            ->orderByDesc('updated_at')
            ->limit(10)
            ->get()
            ->each(fn ($a) => $alertes->push([
                'id' => "abs-{$a->id}-{$a->updated_at?->timestamp}",
                'type' => 'justificatif',
                'titre' => "Justificatif d'absence · {$a->user?->name}",
                'texte' => trim(($a->lecon?->titre ? "{$a->lecon->titre} — " : '') . ($a->motif ? "« {$a->motif} »" : '')),
                'date' => $a->updated_at,
                'lien' => '/absences',
            ]));

        Soumission::where('statut', 'rendu')
            ->whereHas('devoir', $dansEtab)
            ->with(['user:id,name', 'devoir:id,titre'])
            ->orderByDesc('date_soumission')
            ->limit(10)
            ->get()
            ->each(fn ($s) => $alertes->push([
                'id' => "sou-{$s->id}",
                'type' => 'correction',
                'titre' => "Rendu à corriger · {$s->user?->name}",
                'texte' => $s->devoir?->titre,
                'date' => $s->date_soumission ?? $s->updated_at,
                'lien' => "/devoirs/{$s->devoir_id}",
            ]));

        User::where('role', Roles::BENEFICIAIRE)
            ->where('etablissement_id', $etabId)
            ->where(fn ($q) => $q->where('created_at', '>=', now()->subDays(7))
                ->orWhere(fn ($q2) => $q2->where('actif', false)->whereNull('valide_le')))
            ->with('parcours:id,nom')
            ->latest()
            ->limit(10)
            ->get(['id', 'name', 'parcours_id', 'actif', 'valide_le', 'created_at'])
            ->each(fn ($u) => $alertes->push([
                'id' => "insc-{$u->id}",
                'type' => 'inscription',
                'titre' => ($u->en_attente ? 'Inscription à valider · ' : 'Nouvelle inscription · ').$u->name,
                'texte' => $u->parcours?->nom ?? 'Sans parcours',
                'date' => $u->created_at,
                'lien' => $voitFiches ? "/beneficiaires/{$u->id}" : '/beneficiaires',
            ]));

        Devoir::where('etablissement_id', $etabId)
            ->whereIn('statut', ['programme', 'en_cours'])
            ->whereNotNull('date_limite')
            ->where('date_limite', '<=', now()->addDays(3))
            ->with('parcours:id,nom')
            ->orderBy('date_limite')
            ->limit(10)
            ->get(['id', 'titre', 'parcours_id', 'date_limite'])
            ->each(function ($d) use ($alertes) {
                $echu = $d->date_limite->isPast();
                $alertes->push([
                    'id' => ($echu ? 'echu-' : 'ech-') . $d->id,
                    'type' => $echu ? 'echu' : 'echeance',
                    'titre' => ($echu ? 'Échéance dépassée · ' : 'Échéance proche · ') . $d->titre,
                    'texte' => $d->parcours?->nom,
                    'date' => $d->date_limite,
                    'lien' => "/devoirs/{$d->id}",
                ]);
            });

        // Séances des prochaines 48 h
        Seance::whereIn('parcours_id', Parcours::where('etablissement_id', $etabId)->select('id'))
            ->whereBetween('date', [now()->toDateString(), now()->addDays(2)->toDateString()])
            ->with(['parcours:id,nom', 'lecon:id,titre'])
            ->orderBy('date')
            ->orderBy('heure_debut')
            ->limit(5)
            ->get()
            ->filter(fn ($s) => $s->date->format('Y-m-d') . ' ' . $s->heure_fin >= now()->format('Y-m-d H:i:s'))
            ->each(fn ($s) => $alertes->push([
                'id' => "sea-{$s->id}",
                'type' => 'seance',
                'titre' => "Séance · {$s->parcours?->nom}",
                'texte' => ($s->lecon?->titre ? "{$s->lecon->titre} — " : '') . substr($s->heure_debut, 0, 5) . '–' . substr($s->heure_fin, 0, 5),
                'date' => $s->date->format('Y-m-d') . 'T' . $s->heure_debut,
                'lien' => "/parcours/{$s->parcours_id}",
            ]));

        return $alertes->values();
    }

    private function messagerie(User $user): array
    {
        $pivot = DB::table('conversation_user')->where('user_id', $user->id);

        // Conversations ayant au moins un message reçu après la dernière lecture
        $nonLues = (clone $pivot)
            ->whereExists(function ($q) use ($user) {
                $q->select(DB::raw(1))
                    ->from('messages')
                    ->whereColumn('messages.conversation_id', 'conversation_user.conversation_id')
                    ->where('messages.auteur_id', '!=', $user->id)
                    ->where(fn ($q2) => $q2->whereNull('conversation_user.last_read_at')
                        ->orWhereColumn('messages.created_at', '>', 'conversation_user.last_read_at'));
            })
            ->pluck('conversation_id');

        $lectures = (clone $pivot)->pluck('last_read_at', 'conversation_id');

        $derniers = Message::whereIn('conversation_id', (clone $pivot)->select('conversation_id'))
            ->where('auteur_id', '!=', $user->id)
            ->with(['auteur:id,name,photo', 'conversation:id,type,nom'])
            ->latest()
            ->limit(6)
            ->get(['id', 'conversation_id', 'auteur_id', 'contenu', 'created_at']);

        return [
            'non_lues' => $nonLues->count(),
            'derniers' => $derniers->map(function ($m) use ($lectures) {
                $lu = $lectures[$m->conversation_id] ?? null;

                return [
                    'id' => $m->id,
                    'conversation_id' => $m->conversation_id,
                    'auteur' => $m->auteur?->name,
                    'photo_url' => $m->auteur?->photo_url,
                    'conversation' => $m->conversation?->type === 'privee' ? null : $m->conversation?->nom,
                    'contenu' => mb_strimwidth((string) $m->contenu, 0, 110, '…'),
                    'created_at' => $m->created_at,
                    'non_lu' => ! $lu || $m->created_at->gt($lu),
                ];
            }),
        ];
    }
}
