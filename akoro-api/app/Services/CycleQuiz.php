<?php

namespace App\Services;

use App\Http\Controllers\Api\QuizController;
use App\Models\Devoir;
use App\Models\ResultatQuiz;
use App\Models\User;
use App\Notifications\AvisBeneficiaire;

/**
 * Cycle de vie automatique des QCM programmés :
 *  - 5 minutes avant le début : avis « Le quiz commence dans 5 minutes ! » aux bénéficiaires ;
 *  - à l'heure de début : statut « En cours » + avis « Le quiz commence maintenant ! » ;
 *  - à la fin (début + durée) : statut « Terminé » et tentatives en cours clôturées (plus aucune réponse acceptée).
 *
 * Idempotent : appelé chaque minute par le planificateur ET à la lecture des listes
 * (si le planificateur ne tourne pas, les statuts restent justes).
 */
class CycleQuiz
{
    public const RAPPEL_MINUTES = 5;

    public function synchroniser(): void
    {
        $now = now();

        $base = fn () => Devoir::query()->where('type', 'qcm')->whereIn('statut', ['programme', 'en_cours']);

        // 1. Fin de la durée donnée par l'équipe → Terminé
        $base()->whereNotNull('date_limite')->where('date_limite', '<=', $now)->update(['statut' => 'termine', 'updated_at' => $now]);

        // 2. Heure de début atteinte → En cours
        $base()->where('statut', 'programme')->whereNotNull('date_debut')->where('date_debut', '<=', $now)
            ->update(['statut' => 'en_cours', 'updated_at' => $now]);

        // 3. Clôture des tentatives restées ouvertes après la fin du quiz
        ResultatQuiz::query()
            ->where('statut', 'en_cours')
            ->whereHas('devoir', fn ($q) => $q->where('type', 'qcm')->where(fn ($w) => $w
                ->where('statut', 'termine')
                ->orWhere('date_limite', '<=', $now)))
            ->get()
            ->each(fn (ResultatQuiz $r) => QuizController::finaliser($r));

        // 4. Rappel 5 minutes avant le début
        $base()->has('questions')->whereNull('rappel_envoye_le')
            ->where('date_debut', '>', $now)
            ->where('date_debut', '<=', $now->copy()->addMinutes(self::RAPPEL_MINUTES))
            ->get()
            ->each(function (Devoir $d) use ($now) {
                if (! $this->reserver($d, 'rappel_envoye_le', $now)) {
                    return;
                }
                $minutes = max(1, (int) ceil($now->diffInSeconds($d->date_debut) / 60));
                $this->notifier($d, 'quiz_rappel', 'Quiz dans '.$minutes.' minute'.($minutes > 1 ? 's' : ''),
                    "Le quiz « {$d->titre} » commence dans {$minutes} minute".($minutes > 1 ? 's' : '').' !');
            });

        // 5. Début du quiz
        $base()->has('questions')->whereNull('ouverture_notifiee_le')
            ->where('date_debut', '<=', $now)
            ->where(fn ($q) => $q->whereNull('date_limite')->orWhere('date_limite', '>', $now))
            ->get()
            ->each(function (Devoir $d) use ($now) {
                if (! $this->reserver($d, 'ouverture_notifiee_le', $now)) {
                    return;
                }
                $fin = $d->date_limite?->timezone(config('app.timezone'))->format('H:i');
                $this->notifier($d, 'quiz_ouvert', 'Le quiz commence !',
                    "Le quiz « {$d->titre} » commence maintenant !".($fin ? " Il se ferme à {$fin}." : ''));
            });
    }

    /** Marque l'avis comme envoyé ; false si un autre appel l'a déjà fait (pas de doublon). */
    private function reserver(Devoir $d, string $colonne, $now): bool
    {
        return Devoir::whereKey($d->id)->whereNull($colonne)->update([$colonne => $now]) === 1;
    }

    private function notifier(Devoir $d, string $type, string $titre, string $message): void
    {
        User::query()
            ->where('parcours_id', $d->parcours_id)
            ->where('role', 'beneficiaire')
            ->where('actif', true)
            ->get()
            ->each(fn (User $u) => $u->notify(new AvisBeneficiaire($type, $titre, $message, [
                'devoir_id' => $d->id,
                'devoir_type' => 'qcm',
            ])));
    }
}
