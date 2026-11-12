<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * Avis simple enregistré en base pour la cloche de l'application mobile
 * (devoir corrigé, justificatif d'absence traité…).
 */
class AvisBeneficiaire extends Notification
{
    use Queueable;

    /**
     * @param  string  $type  devoir_corrige | absence_traitee | …
     * @param  array<string, mixed>  $extra  identifiants utiles à l'application (devoir_id…)
     */
    public function __construct(
        public string $type,
        public string $titre,
        public string $message,
        public array $extra = [],
    ) {
    }

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        return [
            'type' => $this->type,
            'titre_avis' => $this->titre,
            'message' => $this->message,
            ...$this->extra,
        ];
    }
}
