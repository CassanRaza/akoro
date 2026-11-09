<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Presence;
use App\Models\Seance;
use App\Models\User;
use App\Services\AbsenceGenerator;
use Carbon\Carbon;
use Illuminate\Http\Request;

/**
 * Pointage du bénéficiaire par QR code (application mobile).
 * Chaque séance a son QR, affiché par l'équipe sur le web : 1er scan du jour = arrivée, 2e scan = départ.
 */
class PresenceController extends Controller
{
    // Délai minimum entre l'arrivée et le départ
    private const DELAI_DEPART_MINUTES = 10;

    // ---------- Aujourd'hui : mon pointage + les séances du jour de mon parcours ----------
    public function aujourdhui(Request $request)
    {
        $user = $request->user();
        $maintenant = Seance::maintenant();

        $seances = $user->parcours_id
            ? Seance::where('parcours_id', $user->parcours_id)
                ->whereDate('date', $maintenant->toDateString())
                ->with('lecon:id,titre')
                ->orderBy('heure_debut')
                ->get()
            : collect();

        return response()->json([
            'presence' => $this->formatPresence(
                Presence::where('user_id', $user->id)->whereDate('date', $maintenant->toDateString())->with('seance.lecon:id,titre')->first()
            ),
            'seances' => $seances->map(fn (Seance $s) => $this->formatSeance($s, $maintenant))->values(),
            'marge_minutes' => (int) config('akoro.qr_marge_minutes', 30),
        ]);
    }

    // ---------- Scanner le QR (ou saisir le code) de la séance ----------
    public function scanner(Request $request)
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:120'],
        ], [
            'code.required' => 'Scannez le QR code de la séance ou saisissez son code.',
        ]);

        $user = $request->user();
        $maintenant = Seance::maintenant();
        $seance = $this->trouverSeance($data['code']);

        abort_unless($seance, 422, 'QR code inconnu. Scannez le QR affiché par votre formateur pour la séance.');
        abort_unless(
            $seance->parcours_id === $user->parcours_id,
            422,
            'Ce QR code correspond à une séance d’un autre parcours.'
        );
        abort_unless(
            $seance->date->toDateString() === $maintenant->toDateString(),
            422,
            'Ce QR code est celui de la séance du '.$seance->date->locale('fr')->translatedFormat('l j F').', pas d’aujourd’hui.'
        );

        [$ouverture, $fermeture] = $seance->fenetrePointage();
        abort_if($maintenant->lt($ouverture), 422, 'Le pointage de cette séance ouvre à '.$ouverture->format('H:i').'.');
        abort_if($maintenant->gt($fermeture), 422, 'Le pointage de cette séance est fermé depuis '.$fermeture->format('H:i').'.');

        $jour = $maintenant->toDateString();
        $presence = Presence::where('user_id', $user->id)->whereDate('date', $jour)->first();

        // 1er scan du jour : arrivée
        if (! $presence) {
            $presence = Presence::create([
                'user_id' => $user->id,
                'seance_id' => $seance->id,
                'date' => $jour,
                'heure_arrivee' => $maintenant->format('H:i:s'),
                'mode' => 'qr',
            ]);

            return response()->json([
                'action' => 'arrivee',
                'message' => 'Arrivée enregistrée à '.$maintenant->format('H:i').'. Bonne séance !',
                'presence' => $this->formatPresence($presence->load('seance.lecon:id,titre')),
            ], 201);
        }

        if ($presence->heure_depart) {
            abort(422, 'Votre présence du jour est déjà complète (arrivée '.substr($presence->heure_arrivee, 0, 5)
                .', départ '.substr($presence->heure_depart, 0, 5).').');
        }

        $arrivee = Carbon::parse($jour.' '.$presence->heure_arrivee, $maintenant->timezone);
        if ($maintenant->lt($arrivee->copy()->addMinutes(self::DELAI_DEPART_MINUTES))) {
            abort(422, 'Arrivée déjà enregistrée à '.$arrivee->format('H:i').'. Scannez à nouveau le QR en partant.');
        }

        // 2e scan : départ
        $presence->update(['heure_depart' => $maintenant->format('H:i:s'), 'seance_id' => $seance->id]);

        return response()->json([
            'action' => 'depart',
            'message' => 'Départ enregistré à '.$maintenant->format('H:i').'. À bientôt au FabLab !',
            'presence' => $this->formatPresence($presence->fresh()->load('seance.lecon:id,titre')),
        ]);
    }

    // ---------- Historique d'un mois : calendrier + statistiques ----------
    public function historique(Request $request, AbsenceGenerator $generator)
    {
        $request->validate(['mois' => ['nullable', 'date_format:Y-m']], ['mois.date_format' => 'Mois invalide.']);

        $user = $request->user();
        $generator->generer($user->etablissement_id);

        $maintenant = Seance::maintenant();
        $debut = Carbon::createFromFormat('Y-m-d', ($request->query('mois') ?? $maintenant->format('Y-m')).'-01')->startOfDay();
        $fin = $debut->copy()->endOfMonth();
        $aujourdhui = $maintenant->toDateString();

        $seances = $user->parcours_id
            ? Seance::where('parcours_id', $user->parcours_id)
                ->whereBetween('date', [$debut->toDateString(), $fin->toDateString()])
                ->orderBy('date')->orderBy('heure_debut')
                ->get()
            : collect();
        $joursSeance = $seances->groupBy(fn ($s) => $s->date->toDateString());

        $presences = Presence::where('user_id', $user->id)
            ->whereBetween('date', [$debut->toDateString(), $fin->toDateString()])
            ->get()->keyBy(fn ($p) => $p->date->toDateString());

        $absences = Absence::where('user_id', $user->id)
            ->whereBetween('date', [$debut->toDateString(), $fin->toDateString()])
            ->get()->groupBy(fn ($a) => $a->date->toDateString());

        $jours = [];
        for ($d = $debut->copy(); $d->lte($fin); $d->addDay()) {
            $date = $d->toDateString();
            $p = $presences->get($date);
            $abs = $absences->get($date);

            $statut = match (true) {
                (bool) $p => 'present',
                (bool) $abs => $this->statutAbsence($abs),
                $joursSeance->has($date) && $date >= $aujourdhui => 'a_venir',
                $joursSeance->has($date) => 'en_attente', // séance passée, absences pas encore calculées
                default => null,
            };

            if ($statut) {
                $jours[] = [
                    'date' => $date,
                    'statut' => $statut,
                    'arrivee' => $p ? substr($p->heure_arrivee, 0, 5) : null,
                    'depart' => $p?->heure_depart ? substr($p->heure_depart, 0, 5) : null,
                    'seances' => ($joursSeance->get($date) ?? collect())
                        ->map(fn ($s) => substr($s->heure_debut, 0, 5).' – '.substr($s->heure_fin, 0, 5))->values(),
                ];
            }
        }

        // Statistiques : jours de séance déjà passés
        $passes = $joursSeance->keys()->filter(fn ($d) => $d < $aujourdhui || ($d === $aujourdhui && $presences->has($d)));
        $presents = $passes->filter(fn ($d) => $presences->has($d))->count();

        return [
            'mois' => $debut->format('Y-m'),
            'jours' => $jours,
            'stats' => [
                'presents' => $presents,
                'jours_seance' => $passes->count(),
                'taux' => $passes->count() > 0 ? (int) round($presents / $passes->count() * 100) : null,
                'absences_a_justifier' => Absence::where('user_id', $user->id)->whereIn('statut', ['non_justifiee', 'refusee'])->count(),
            ],
        ];
    }

    // ---------- Outils ----------

    /** Accepte le contenu du QR (« AKORO-SEANCE:… ») ou le code court saisi à la main. */
    private function trouverSeance(string $saisie): ?Seance
    {
        $saisie = trim($saisie);
        if (str_starts_with($saisie, Seance::PREFIXE_QR)) {
            return Seance::where('qr_token', substr($saisie, strlen(Seance::PREFIXE_QR)))->first();
        }

        $code = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $saisie));

        return strlen($code) === 6 ? Seance::where('code', $code)->first() : null;
    }

    private function statutAbsence($absencesDuJour): string
    {
        $statuts = $absencesDuJour->pluck('statut');

        return match (true) {
            $statuts->contains('non_justifiee') || $statuts->contains('refusee') => 'absent',
            $statuts->contains('a_valider') => 'justificatif_envoye',
            default => 'justifie',
        };
    }

    private function formatSeance(Seance $s, Carbon $maintenant): array
    {
        [$ouverture, $fermeture] = $s->fenetrePointage();

        return [
            'id' => $s->id,
            'heure_debut' => substr($s->heure_debut, 0, 5),
            'heure_fin' => substr($s->heure_fin, 0, 5),
            'lecon' => $s->lecon?->titre,
            'etat' => $s->etatPointage($maintenant),
            'ouverture' => $ouverture->format('H:i'),
            'fermeture' => $fermeture->format('H:i'),
        ];
    }

    private function formatPresence(?Presence $p): ?array
    {
        if (! $p) {
            return null;
        }

        return [
            'date' => $p->date->toDateString(),
            'heure_arrivee' => substr($p->heure_arrivee, 0, 5),
            'heure_depart' => $p->heure_depart ? substr($p->heure_depart, 0, 5) : null,
            'mode' => $p->mode,
            'seance' => $p->seance ? [
                'heure_debut' => substr($p->seance->heure_debut, 0, 5),
                'heure_fin' => substr($p->seance->heure_fin, 0, 5),
                'lecon' => $p->seance->lecon?->titre,
            ] : null,
        ];
    }

    /** Pointages d'une séance, pour l'écran QR de l'équipe (web). */
    public static function pointagesSeance(Seance $seance): array
    {
        $jour = $seance->date->toDateString();
        $attendus = User::where('role', 'beneficiaire')
            ->where('actif', true)
            ->where('parcours_id', $seance->parcours_id)
            ->orderBy('name')
            ->get(['id', 'name', 'photo']);
        $presences = Presence::whereIn('user_id', $attendus->pluck('id'))->whereDate('date', $jour)->get()->keyBy('user_id');

        return $attendus->map(fn ($u) => [
            'id' => $u->id,
            'name' => $u->name,
            'photo_url' => $u->photo_url,
            'arrivee' => ($p = $presences->get($u->id)) ? substr($p->heure_arrivee, 0, 5) : null,
            'depart' => $p?->heure_depart ? substr($p->heure_depart, 0, 5) : null,
        ])->sortBy(fn ($l) => [$l['arrivee'] ? 0 : 1, $l['arrivee'] ?? '', $l['name']])->values()->all();
    }
}
