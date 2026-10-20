<?php

namespace App\Notifications;

use App\Models\Devoir;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class DevoirProgrammeNotification extends Notification
{
    use Queueable;

    public function __construct(public Devoir $devoir)
    {
    }

    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function toArray(object $notifiable): array
    {
        $devoir = $this->devoir->loadMissing('parcours:id,nom');

        $quand = $devoir->type === 'qcm'
            ? optional($devoir->date_debut)->timezone(config('app.timezone'))->format('d/m/Y à H:i')
            : optional($devoir->date_limite)->timezone(config('app.timezone'))->format('d/m/Y à H:i');

        $typeLabel = $devoir->type === 'qcm' ? 'QCM' : 'devoir à rendre';

        $message = $devoir->type === 'qcm'
            ? "Un test ({$typeLabel}) est prévu le {$quand} : « {$devoir->titre} »."
            : "Un devoir à rendre est programmé. Date limite : {$quand}. Titre : « {$devoir->titre} ».";

        return [
            'type'           => 'devoir_programme',
            'devoir_id'      => $devoir->id,
            'titre'          => $devoir->titre,
            'devoir_type'    => $devoir->type,
            'parcours'       => $devoir->parcours?->nom,
            'date_affichage' => $quand,
            'message'        => $message,
        ];
    }
}