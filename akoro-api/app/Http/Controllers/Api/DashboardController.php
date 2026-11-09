<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Devoir;
use App\Models\Etablissement;
use App\Models\Lecon;
use App\Models\Message;
use App\Models\Parcours;
use App\Models\Presence;
use App\Models\ResultatQuiz;
use App\Models\Seance;
use App\Models\Soumission;
use App\Models\User;
use App\Services\AbsenceGenerator;
use App\Support\Roles;
use Carbon\Carbon;
use Carbon\CarbonPeriod;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Tableau de bord FabManager / Super Admin.
 * Tout est renvoyé en un seul appel pour limiter les allers-retours.
 */
class DashboardController extends Controller
{
    public function index(Request $request, AbsenceGenerator $generator)
    {
        $request->validate([
            'periode' => ['nullable', Rule::in(['semaine', 'mois'])],
            'etablissement_id' => ['nullable', 'integer', 'exists:etablissements,id'],
        ]);

        $user = $request->user();
        $estGlobal = $user->role === Roles::ADMIN_GLOBAL;

        // Le Super Admin peut consulter n'importe quel établissement
        $etabId = $estGlobal && $request->filled('etablissement_id')
            ? (int) $request->query('etablissement_id')
            : ($user->etablissement_id ?? Etablissement::value('id'));

        $etablissement = Etablissement::find($etabId, ['id', 'nom']);

        $periode = $request->query('periode', 'semaine');
        $jours = $periode === 'mois' ? 30 : 7;
        $aujourdhui = now()->toDateString();
        $debut = now()->subDays($jours - 1)->toDateString();

        // Les absences des séances terminées doivent être à jour avant les calculs
        $generator->generer($etabId);

        $parcoursIds = Parcours::where('etablissement_id', $etabId)->pluck('id');
        $beneficiaires = User::where('role', Roles::BENEFICIAIRE)->where('etablissement_id', $etabId);

        $presenceJour = $this->presenceDuJour($etabId, $parcoursIds, $aujourdhui);
        $notes = $this->notesParBeneficiaire($etabId);

        return [
            'etablissement' => $etablissement,
            'etablissements' => $estGlobal ? Etablissement::orderBy('nom')->get(['id', 'nom']) : null,
            'periode' => ['code' => $periode, 'debut' => $debut, 'fin' => $aujourdhui],

            'kpis' => [
                'beneficiaires' => [
                    'total' => (clone $beneficiaires)->count(),
                    'actifs' => (clone $beneficiaires)->where('actif', true)->count(),
                    'inactifs' => (clone $beneficiaires)->where('actif', false)->count(),
                ],
                'parcours' => $parcoursIds->count(),
                'lecons' => Lecon::whereIn('parcours_id', $parcoursIds)->count(),
                'devoirs_actifs' => Devoir::where('etablissement_id', $etabId)
                    ->whereIn('statut', ['programme', 'en_cours'])->count(),
            ],

            'parcours' => $this->parcours($etabId, $debut, $aujourdhui, $notes),
            'presences' => [
                'aujourdhui' => $presenceJour['liste'],
                'resume_jour' => [
                    'presents' => $presenceJour['presents'],
                    'attendus' => $presenceJour['attendus'],
                ],
                'courbe' => $this->courbePresence($parcoursIds, $debut, $aujourdhui),
                'plus_absents' => $this->plusAbsents($etabId, $debut),
            ],
            'devoirs' => $this->devoirs($etabId, $notes),
            'activite_messages' => $this->activiteMessages($etabId, $debut, $aujourdhui),
            'comparaison' => $estGlobal ? $this->comparaison($debut, $aujourdhui) : null,
            'fabia' => FabiaController::statistiques($etabId, $debut),
        ];
    }

    // ------------------------------------------------------------------
    // Présences
    // ------------------------------------------------------------------

    /**
     * Pointages du jour. « Attendus » = bénéficiaires actifs dont le parcours a une séance aujourd'hui.
     * Les bénéficiaires pointés sans séance prévue apparaissent aussi (présents).
     */
    private function presenceDuJour(int $etabId, Collection $parcoursIds, string $jour): array
    {
        $parcoursAvecSeance = Seance::whereIn('parcours_id', $parcoursIds)
            ->whereDate('date', $jour)
            ->pluck('parcours_id')
            ->unique();

        $pointages = Presence::whereDate('date', $jour)
            ->whereHas('user', fn ($q) => $q->where('etablissement_id', $etabId))
            ->get()
            ->keyBy('user_id');

        $users = User::where('role', Roles::BENEFICIAIRE)
            ->where('etablissement_id', $etabId)
            ->where('actif', true)
            ->where(function ($q) use ($parcoursAvecSeance, $pointages) {
                $q->whereIn('parcours_id', $parcoursAvecSeance)->orWhereIn('id', $pointages->keys());
            })
            ->with('parcours:id,nom')
            ->orderBy('name')
            ->get(['id', 'name', 'parcours_id']);

        $liste = $users->map(function ($u) use ($pointages, $parcoursAvecSeance) {
            $p = $pointages->get($u->id);
            $statut = match (true) {
                $p && $p->heure_depart => 'parti',
                (bool) $p => 'present',
                default => 'absent',
            };

            return [
                'id' => $u->id,
                'name' => $u->name,
                'parcours' => $u->parcours?->nom,
                'attendu' => $parcoursAvecSeance->contains($u->parcours_id),
                'heure_arrivee' => $p ? substr($p->heure_arrivee, 0, 5) : null,
                'heure_depart' => $p && $p->heure_depart ? substr($p->heure_depart, 0, 5) : null,
                'statut' => $statut,
            ];
        })->sortBy(fn ($l) => ['absent' => 0, 'present' => 1, 'parti' => 2][$l['statut']])->values();

        $attendus = $liste->where('attendu', true);

        return [
            'attendus' => $attendus->count(),
            'presents' => $attendus->where('statut', '!=', 'absent')->count(),
            'liste' => $liste,
        ];
    }

    /**
     * Taux de présence par jour, calculé sur les séances déjà traitées :
     * (attendus − absences) / attendus.
     */
    private function courbePresence(Collection $parcoursIds, string $debut, string $fin): array
    {
        $seances = Seance::whereIn('parcours_id', $parcoursIds)
            ->whereNotNull('absences_generees_le')
            ->whereBetween('date', [$debut, $fin])
            ->withCount('absences')
            ->get(['id', 'date', 'attendus']);

        $parJour = $seances->groupBy(fn ($s) => $s->date->format('Y-m-d'));

        $points = [];
        foreach (CarbonPeriod::create($debut, $fin) as $jour) {
            $cle = $jour->format('Y-m-d');
            $lot = $parJour->get($cle, collect());
            $attendus = (int) $lot->sum('attendus');
            $absents = (int) $lot->sum('absences_count');
            $points[] = [
                'date' => $cle,
                'attendus' => $attendus,
                'presents' => max(0, $attendus - $absents),
                'taux' => $attendus > 0 ? $this->taux($attendus - $absents, $attendus) : null,
            ];
        }

        return $points;
    }

    // Bénéficiaires cumulant le plus d'absences non justifiées sur la période (risque de décrochage)
    private function plusAbsents(int $etabId, string $debut): Collection
    {
        return Absence::query()
            ->join('users', 'users.id', '=', 'absences.user_id')
            ->leftJoin('parcours', 'parcours.id', '=', 'users.parcours_id')
            ->where('users.etablissement_id', $etabId)
            ->whereIn('absences.statut', ['non_justifiee', 'refusee', 'a_valider'])
            ->where('absences.date', '>=', $debut)
            ->groupBy('users.id', 'users.name', 'parcours.nom')
            ->orderByDesc('total')
            ->limit(5)
            ->get([
                'users.id',
                'users.name',
                'parcours.nom as parcours',
                DB::raw('COUNT(absences.id) as total'),
            ]);
    }

    // ------------------------------------------------------------------
    // Parcours
    // ------------------------------------------------------------------

    private function parcours(int $etabId, string $debut, string $fin, Collection $notes): Collection
    {
        $parcours = Parcours::where('etablissement_id', $etabId)
            ->withCount([
                'lecons',
                'utilisateurs as beneficiaires' => fn ($q) => $q->where('role', Roles::BENEFICIAIRE),
            ])
            ->orderBy('nom')
            ->get(['id', 'nom']);

        // Présence par parcours sur la période (séances déjà traitées)
        $presence = Seance::whereIn('parcours_id', $parcours->pluck('id'))
            ->whereNotNull('absences_generees_le')
            ->whereBetween('date', [$debut, $fin])
            ->withCount('absences')
            ->get(['id', 'parcours_id', 'attendus'])
            ->groupBy('parcours_id');

        $parcoursDesNotes = User::whereIn('id', $notes->keys())->pluck('parcours_id', 'id');

        return $parcours->map(function ($p) use ($presence, $notes, $parcoursDesNotes) {
            $lot = $presence->get($p->id, collect());
            $attendus = (int) $lot->sum('attendus');
            $absents = (int) $lot->sum('absences_count');
            $notesParcours = $notes->filter(fn ($n, $userId) => $parcoursDesNotes->get($userId) === $p->id);

            return [
                'id' => $p->id,
                'nom' => $p->nom,
                'beneficiaires' => $p->beneficiaires,
                'lecons' => $p->lecons_count,
                'taux_presence' => $attendus > 0 ? $this->taux($attendus - $absents, $attendus) : null,
                'note_moyenne' => $notesParcours->isEmpty() ? null : round($notesParcours->avg('moyenne'), 1),
                'progression_moyenne' => null,
            ];
        });
    }

    // ------------------------------------------------------------------
    // Devoirs
    // ------------------------------------------------------------------

    /**
     * Moyenne (en %) de chaque bénéficiaire : QCM terminés + rendus corrigés (note /20 ramenée en %).
     * Clé = user_id.
     */
    private function notesParBeneficiaire(int $etabId): Collection
    {
        $qcm = ResultatQuiz::where('statut', 'termine')
            ->whereNotNull('pourcentage')
            ->whereHas('devoir', fn ($q) => $q->where('etablissement_id', $etabId))
            ->get(['user_id', 'pourcentage'])
            ->map(fn ($r) => ['user_id' => $r->user_id, 'pct' => (float) $r->pourcentage]);

        $rendus = Soumission::where('statut', 'corrige')
            ->whereNotNull('note')
            ->whereHas('devoir', fn ($q) => $q->where('etablissement_id', $etabId))
            ->get(['user_id', 'note'])
            ->map(fn ($s) => ['user_id' => $s->user_id, 'pct' => (float) $s->note * 5]);

        return $qcm->concat($rendus)
            ->groupBy('user_id')
            ->map(fn ($lignes) => [
                'moyenne' => round($lignes->avg('pct'), 1),
                'evaluations' => $lignes->count(),
            ]);
    }

    private function devoirs(int $etabId, Collection $notes): array
    {
        $base = Devoir::where('etablissement_id', $etabId);
        $colonnes = ['id', 'titre', 'type', 'statut', 'parcours_id', 'date_debut', 'date_limite'];

        // Taux de réussite des 5 derniers devoirs ayant des résultats (≥ 50 % = réussi)
        $derniers = (clone $base)
            ->whereIn('statut', ['en_cours', 'termine'])
            ->with('parcours:id,nom')
            ->orderByDesc(DB::raw('COALESCE(date_limite, date_debut, created_at)'))
            ->limit(5)
            ->get($colonnes)
            ->map(function ($d) {
                $scores = $d->type === 'qcm'
                    ? ResultatQuiz::where('devoir_id', $d->id)->where('statut', 'termine')->pluck('pourcentage')->map(fn ($v) => (float) $v)
                    : Soumission::where('devoir_id', $d->id)->where('statut', 'corrige')->whereNotNull('note')->pluck('note')->map(fn ($v) => (float) $v * 5);

                return [
                    'id' => $d->id,
                    'titre' => $d->titre,
                    'parcours' => $d->parcours?->nom,
                    'participants' => $scores->count(),
                    'moyenne' => $scores->isEmpty() ? null : round($scores->avg(), 1),
                    'taux_reussite' => $scores->isEmpty() ? null : $this->taux($scores->filter(fn ($s) => $s >= 50)->count(), $scores->count()),
                ];
            });

        $avecScores = $derniers->whereNotNull('taux_reussite');

        $enDifficulte = $notes
            ->filter(fn ($n) => $n['moyenne'] < 50)
            ->sortBy('moyenne')
            ->take(5);

        $users = User::whereIn('id', $enDifficulte->keys())->with('parcours:id,nom')->get(['id', 'name', 'parcours_id'])->keyBy('id');

        return [
            'a_venir' => (clone $base)->where('statut', 'programme')
                ->with('parcours:id,nom')->orderBy('date_debut')->limit(5)->get($colonnes),
            'en_cours' => (clone $base)->where('statut', 'en_cours')
                ->with('parcours:id,nom')->orderBy('date_limite')->limit(5)->get($colonnes),
            'derniers' => $derniers,
            'taux_reussite_moyen' => $avecScores->isEmpty() ? null : round($avecScores->avg('taux_reussite'), 1),
            'en_difficulte' => $enDifficulte->map(fn ($n, $userId) => [
                'id' => $userId,
                'name' => $users->get($userId)?->name,
                'parcours' => $users->get($userId)?->parcours?->nom,
                'moyenne' => $n['moyenne'],
                'evaluations' => $n['evaluations'],
            ])->values(),
        ];
    }

    // ------------------------------------------------------------------
    // Messagerie
    // ------------------------------------------------------------------

    private function messagesQuery(int $etabId)
    {
        return Message::join('conversations', 'conversations.id', '=', 'messages.conversation_id')
            ->where('conversations.etablissement_id', $etabId);
    }

    // Nombre de messages échangés par jour dans l'établissement
    private function activiteMessages(int $etabId, string $debut, string $fin): array
    {
        $parJour = $this->messagesQuery($etabId)
            ->whereDate('messages.created_at', '>=', $debut)
            ->groupBy(DB::raw('DATE(messages.created_at)'))
            ->pluck(DB::raw('COUNT(*) as total'), DB::raw('DATE(messages.created_at) as jour'));

        $activite = [];
        foreach (CarbonPeriod::create($debut, $fin) as $jour) {
            $cle = $jour->format('Y-m-d');
            $activite[] = ['date' => $cle, 'total' => (int) ($parJour[$cle] ?? 0)];
        }

        return $activite;
    }

    // ------------------------------------------------------------------
    // Vue comparée (Super Admin)
    // ------------------------------------------------------------------

    private function comparaison(string $debut, string $fin): Collection
    {
        $users = User::select('etablissement_id', 'role', DB::raw('COUNT(*) as total'))
            ->whereNotNull('etablissement_id')
            ->groupBy('etablissement_id', 'role')
            ->get()
            ->groupBy('etablissement_id');

        $presence = Seance::join('parcours', 'parcours.id', '=', 'seances.parcours_id')
            ->whereNotNull('seances.absences_generees_le')
            ->whereBetween('seances.date', [$debut, $fin])
            ->withCount('absences')
            ->get(['seances.id', 'seances.attendus', 'parcours.etablissement_id'])
            ->groupBy('etablissement_id');

        return Etablissement::orderBy('nom')->get(['id', 'nom'])->map(function ($e) use ($users, $presence) {
            $roles = $users->get($e->id, collect());
            $lot = $presence->get($e->id, collect());
            $attendus = (int) $lot->sum('attendus');
            $absents = (int) $lot->sum('absences_count');

            return [
                'id' => $e->id,
                'nom' => $e->nom,
                'beneficiaires' => (int) $roles->where('role', Roles::BENEFICIAIRE)->sum('total'),
                'administrateurs' => (int) $roles->whereIn('role', Roles::ADMINS)->sum('total'),
                'taux_presence' => $attendus > 0 ? $this->taux($attendus - $absents, $attendus) : null,
            ];
        });
    }

    private function taux(int|float $part, int|float $total): ?float
    {
        return $total > 0 ? round($part / $total * 100, 1) : null;
    }
}
