<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Crée automatiquement les absences des séances terminées
Schedule::command('absences:generer')->everyFiveMinutes();

// Quiz : rappel 5 min avant, ouverture, puis statut « Terminé » à la fin de la durée
Schedule::command('quiz:cycle')->everyMinute();
