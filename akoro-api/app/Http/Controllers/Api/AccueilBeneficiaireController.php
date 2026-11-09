<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Devoir;
use App\Models\Etablissement;
use App\Models\Lecon;
use App\Models\Message;
use App\Models\Presence;
use App\Models\Progression;
use App\Models\Ressource;
use App\Models\ResultatQuiz;
use App\Models\Seance;
use App\Models\Soumission;
use App\Services\AbsenceGenerator;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * Écran d'accueil du bénéficiaire (application mobile) : tout en un seul appel.
 * Uniquement des données réelles ; la progression = chapitres terminés / chapitres du parcours
 * (même calcul que l'onglet Formations).
 */
class AccueilBeneficiaireController extends Controller
{
    private const FUSEAU = 'Indian/Antananarivo';

    public function index(Request $request, AbsenceGenerator $generator)
    {
        $user = $request->user();
        // Absences des séances terminées à jour, comme dans « Mes absences »
        $generator->generer($user->etablissement_id);

        $maintenant = now(self::FUSEAU);
        $parcours = $user->parcours;

        return [
            'utilisateur' => [
                'name' => $user->name,
                'photo_url' => $user->photo_url,
            ],
            'etablissement' => Etablissement::find($user->etablissement_id, ['id', 'nom', 'adresse']),
            'parcours' => $parcours ? ['id' => $parcours->id, 'nom' => $parcours->nom] : null,
            'progression' => $parcours ? $this->progression($user->id, $parcours->id) : null,
            'presences' => $this->presences($user->id, $parcours?->id, $maintenant),
            'prochaine_seance' => $parcours ? $this->prochaineSeance($parcours->id, $maintenant) : null,
            'devoirs' => $parcours ? $this->devoirs($user->id, $parcours->id) : ['a_faire' => 0, 'liste' => []],
            'absences_a_justifier' => Absence::where('user_id', $user->id)
                ->whereIn('statut', ['non_justifiee', 'refusee'])
                ->count(),
            'messages_non_lus' => $this->messagesNonLus($user->id),
            'activite' => $this->activite($user->id),
        ];
    }

    // ---------- Séances passées : terminées avant maintenant ----------
    private function seancesPassees(int $parcoursId, Carbon $maintenant)
    {
        $jour = $maintenant->toDateString();

        return Seance::where('parcours_id', $parcoursId)
            ->where(fn ($q) => $q->whereDate('date', '<', $jour)
                ->orWhere(fn ($q2) => $q2->whereDate('date', $jour)->where('heure_fin', '<=', $maintenant->format('H:i:s'))));
    }

    private function progression(int $userId, int $parcoursId): array
    {
        $leconIds = Lecon::where('parcours_id', $parcoursId)->pluck('id');
        $total = Ressource::whereIn('lecon_id', $leconIds)->count();
        $faits = Progression::where('user_id', $userId)->whereIn('lecon_id', $leconIds)->count();

        // Formations (leçons) dont tous les chapitres sont terminés
        $parLecon = Ressource::whereIn('lecon_id', $leconIds)->selectRaw('lecon_id, COUNT(*) n')->groupBy('lecon_id')->pluck('n', 'lecon_id');
        $faitsParLecon = Progression::where('user_id', $userId)->whereIn('lecon_id', $leconIds)
            ->selectRaw('lecon_id, COUNT(*) n')->groupBy('lecon_id')->pluck('n', 'lecon_id');
        $leconsTerminees = $parLecon->filter(fn ($n, $id) => ($faitsParLecon[$id] ?? 0) >= $n)->count();

        return [
            'chapitres_total' => $total,
            'chapitres_termines' => min($faits, $total),
            'lecons_total' => $leconIds->count(),
            'lecons_terminees' => $leconsTerminees,
            'pourcentage' => $total > 0 ? (int) round(min($faits, $total) / $total * 100) : null,
        ];
    }

    private function presences(int $userId, ?int $parcoursId, Carbon $maintenant): array
    {
        $debutMois = $maintenant->copy()->startOfMonth()->toDateString();

        // Jours de séance déjà passés ce mois-ci (un pointage par jour)
        $joursSeance = $parcoursId
            ? (clone $this->seancesPassees($parcoursId, $maintenant))
                ->whereDate('date', '>=', $debutMois)
                ->pluck('date')
                ->map(fn ($d) => $d->toDateString())
                ->unique()
                ->values()
            : collect();

        $presentsMois = $joursSeance->isEmpty() ? 0 : Presence::where('user_id', $userId)
            ->whereIn('date', $joursSeance->all())
            ->count();

        $aujourdhui = Presence::where('user_id', $userId)->whereDate('date', $maintenant->toDateString())->first();
        $seanceAujourdhui = $parcoursId
            ? Seance::where('parcours_id', $parcoursId)->whereDate('date', $maintenant->toDateString())->exists()
            : false;

        return [
            'mois_presents' => $presentsMois,
            'mois_jours_seance' => $joursSeance->count(),
            'mois_taux' => $joursSeance->isNotEmpty() ? (int) round($presentsMois / $joursSeance->count() * 100) : null,
            'total' => Presence::where('user_id', $userId)->count(),
            'aujourdhui' => [
                'seance_prevue' => $seanceAujourdhui,
                'heure_arrivee' => $aujourdhui ? substr($aujourdhui->heure_arrivee, 0, 5) : null,
                'heure_depart' => $aujourdhui?->heure_depart ? substr($aujourdhui->heure_depart, 0, 5) : null,
            ],
        ];
    }

    private function prochaineSeance(int $parcoursId, Carbon $maintenant): ?array
    {
        $jour = $maintenant->toDateString();
        $heure = $maintenant->format('H:i:s');

        $s = Seance::where('parcours_id', $parcoursId)
            ->where(fn ($q) => $q->whereDate('date', '>', $jour)
                ->orWhere(fn ($q2) => $q2->whereDate('date', $jour)->where('heure_fin', '>', $heure)))
            ->with('lecon:id,titre')
            ->orderBy('date')
            ->orderBy('heure_debut')
            ->first();

        if (! $s) {
            return null;
        }

        return [
            'id' => $s->id,
            'date' => $s->date->toDateString(),
            'heure_debut' => substr($s->heure_debut, 0, 5),
            'heure_fin' => substr($s->heure_fin, 0, 5),
            'lecon' => $s->lecon?->titre,
            'en_cours' => $s->date->toDateString() === $jour && $s->heure_debut <= $heure,
        ];
    }

    // Devoirs ouverts du parcours que le bénéficiaire n'a pas encore faits
    private function devoirs(int $userId, int $parcoursId): array
    {
        $devoirs = Devoir::where('parcours_id', $parcoursId)
            ->whereIn('statut', ['programme', 'en_cours'])
            ->orderByRaw('date_limite IS NULL, date_limite')
            ->get(['id', 'titre', 'type', 'statut', 'date_debut', 'date_limite']);

        $quizFaits = ResultatQuiz::where('user_id', $userId)->where('statut', 'termine')->pluck('devoir_id')->all();
        $rendus = Soumission::where('user_id', $userId)->whereIn('statut', ['rendu', 'corrige'])->pluck('devoir_id')->all();

        $aFaire = $devoirs->reject(fn ($d) => in_array($d->id, $d->type === 'qcm' ? $quizFaits : $rendus, true))->values();

        return [
            'a_faire' => $aFaire->count(),
            'liste' => $aFaire->take(3)->map(fn ($d) => [
                'id' => $d->id,
                'titre' => $d->titre,
                'type' => $d->type,
                'ouvert' => $d->statut === 'en_cours',
                'date_limite' => $d->date_limite?->toIso8601String(),
            ])->values(),
        ];
    }

    // Même calcul que la liste des conversations (messages des autres, non supprimés, après la dernière lecture)
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

    private function activite(int $userId): Collection
    {
        $tz = self::FUSEAU;
        $statutsAbsence = [
            'non_justifiee' => 'Absence non justifiée',
            'a_valider' => 'Justificatif en cours de validation',
            'justifiee' => 'Absence justifiée',
            'refusee' => 'Justificatif refusé',
        ];

        $presences = Presence::where('user_id', $userId)->latest('date')->limit(5)->get()
            ->map(fn ($p) => [
                'type' => 'presence',
                'titre' => 'Présent au FabLab',
                'detail' => 'Arrivée '.substr($p->heure_arrivee, 0, 5).($p->heure_depart ? ' · départ '.substr($p->heure_depart, 0, 5) : ' · toujours sur place'),
                'date' => Carbon::parse($p->date->toDateString().' '.$p->heure_arrivee, $tz)->toIso8601String(),
                'ton' => 'succes',
            ]);

        $absences = Absence::where('user_id', $userId)->with('lecon:id,titre')->latest('date')->limit(5)->get()
            ->map(fn ($a) => [
                'type' => 'absence',
                'titre' => $statutsAbsence[$a->statut] ?? 'Absence',
                'detail' => $a->lecon?->titre ?? 'Séance du parcours',
                'date' => Carbon::parse($a->date->toDateString().' 12:00', $tz)->toIso8601String(),
                'ton' => in_array($a->statut, ['non_justifiee', 'refusee'], true) ? 'alerte' : 'neutre',
            ]);

        $quiz = ResultatQuiz::where('user_id', $userId)->where('statut', 'termine')->with('devoir:id,titre')
            ->latest('termine_le')->limit(5)->get()
            ->map(fn ($r) => [
                'type' => 'quiz',
                'titre' => 'Quiz terminé : '.($r->devoir?->titre ?? 'devoir'),
                'detail' => 'Score '.$r->score.' / '.$r->score_max.($r->pourcentage !== null ? ' ('.(int) round($r->pourcentage).' %)' : ''),
                'date' => ($r->termine_le ?? $r->updated_at)->toIso8601String(),
                'ton' => ($r->pourcentage ?? 0) >= 50 ? 'succes' : 'attention',
            ]);

        $rendus = Soumission::where('user_id', $userId)->whereIn('statut', ['rendu', 'corrige'])->with('devoir:id,titre')
            ->latest('updated_at')->limit(5)->get()
            ->map(fn ($s) => [
                'type' => 'devoir',
                'titre' => ($s->statut === 'corrige' ? 'Devoir corrigé : ' : 'Devoir rendu : ').($s->devoir?->titre ?? 'devoir'),
                'detail' => $s->statut === 'corrige' && $s->note !== null ? 'Note : '.rtrim(rtrim((string) $s->note, '0'), '.').' / 20' : 'En attente de correction',
                'date' => ($s->statut === 'corrige' ? $s->updated_at : ($s->date_soumission ?? $s->updated_at))->toIso8601String(),
                'ton' => $s->statut === 'corrige' ? 'succes' : 'neutre',
            ]);

        $chapitres = Progression::where('user_id', $userId)->with(['ressource:id,titre', 'lecon:id,titre'])
            ->latest('termine_le')->limit(5)->get()
            ->map(fn ($p) => [
                'type' => 'chapitre',
                'titre' => 'Chapitre terminé : '.($p->ressource?->titre ?? 'chapitre'),
                'detail' => $p->lecon?->titre ?? 'Formation',
                'date' => $p->termine_le->toIso8601String(),
                'ton' => 'succes',
            ]);

        return $presences->concat($absences)->concat($quiz)->concat($rendus)->concat($chapitres)
            ->sortByDesc('date')
            ->take(5)
            ->values();
    }
}
