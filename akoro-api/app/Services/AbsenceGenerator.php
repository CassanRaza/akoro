<?php

namespace App\Services;

use App\Models\Absence;
use App\Models\Presence;
use App\Models\Seance;
use App\Models\User;
use Carbon\Carbon;

class AbsenceGenerator
{
    /**
     * Traite les séances terminées (délai de grâce écoulé) et crée les absences.
     * Peut être appelée autant de fois qu'on veut : une séance n'est traitée qu'une seule fois.
     * Retourne le nombre d'absences créées.
     */
    public function generer(?int $etablissementId = null): int
    {
        $limite = now()->subMinutes((int) config('akoro.delai_absence', 15));
        $crees = 0;

        $seances = Seance::query()
            ->whereNull('absences_generees_le')
            ->whereDate('date', '<=', $limite->toDateString())
            ->when($etablissementId, function ($q) use ($etablissementId) {
                $q->whereHas('parcours', fn ($p) => $p->where('etablissement_id', $etablissementId));
            })
            ->get();

        foreach ($seances as $seance) {
            $fin = Carbon::parse($seance->date->format('Y-m-d') . ' ' . $seance->heure_fin);

            // Séance pas encore terminée (ou délai de grâce en cours)
            if ($fin->greaterThan($limite)) {
                continue;
            }

            $crees += $this->traiter($seance);
        }

        return $crees;
    }

    private function traiter(Seance $seance): int
    {
        $jour = $seance->date->format('Y-m-d');

        // Bénéficiaires attendus : actifs, dans le parcours, déjà inscrits ce jour-là
        $attendus = User::where('role', 'beneficiaire')
            ->where('actif', true)
            ->where('parcours_id', $seance->parcours_id)
            ->whereDate('created_at', '<=', $jour)
            ->pluck('id');

        // Présents : pointage du jour qui couvre la séance (arrivé avant la fin, pas parti avant le début)
        $presents = Presence::whereIn('user_id', $attendus)
            ->whereDate('date', $jour)
            ->where('heure_arrivee', '<=', $seance->heure_fin)
            ->where(function ($q) use ($seance) {
                $q->whereNull('heure_depart')->orWhere('heure_depart', '>=', $seance->heure_debut);
            })
            ->pluck('user_id');

        $crees = 0;

        foreach ($attendus->diff($presents) as $userId) {
            $absence = Absence::firstOrCreate(
                ['user_id' => $userId, 'seance_id' => $seance->id],
                ['lecon_id' => $seance->lecon_id, 'date' => $jour, 'statut' => 'non_justifiee']
            );

            if ($absence->wasRecentlyCreated) {
                $crees++;
            }
        }

        $seance->update([
            'attendus' => $attendus->count(),
            'absences_generees_le' => now(),
        ]);

        return $crees;
    }
}