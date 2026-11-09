<?php

return [
    // Heure locale du FabLab : les séances sont saisies et les pointages enregistrés dans ce fuseau
    // (le serveur, lui, reste en UTC pour les dates techniques : created_at, etc.)
    'fuseau' => env('AKORO_FUSEAU', 'Indian/Antananarivo'),

    // QR code d'une séance accepté de N minutes avant le début à N minutes après la fin
    'qr_marge_minutes' => (int) env('AKORO_QR_MARGE_MINUTES', 30),

    // Délai après la fin d'une séance avant de compter les absents
    'delai_absence' => (int) env('AKORO_DELAI_ABSENCE', 15),
];
