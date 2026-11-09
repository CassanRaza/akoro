<?php

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => [
        'http://localhost:5173', // admin web (Vite)
        'http://localhost:5555', // aperçu de l'appli mobile dans Chrome (flutter run -d chrome --web-port 5555)
    ],
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];