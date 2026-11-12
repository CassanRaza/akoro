<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],
'openai' => [
    'key'   => env('OPENAI_API_KEY'),
    'model' => env('OPENAI_MODEL', 'gpt-4o-mini'),
],

// FAB'IA : fournisseurs essayés dans l'ordre (API compatible « chat completions »).
// Clé Gemini gratuite : https://aistudio.google.com/apikey
'ia' => [
    'fournisseurs' => [
        [
            'nom' => 'gemini',
            'url' => 'https://generativelanguage.googleapis.com/v1beta/openai',
            'cle' => env('GEMINI_API_KEY'),
            'modele' => env('GEMINI_MODEL', 'gemini-3.8-flash'),
            'reflexion' => env('GEMINI_REFLEXION', 'low'),
        ],
        [
            'nom' => 'gemini-secours',
            'url' => 'https://generativelanguage.googleapis.com/v1beta/openai',
            'cle' => env('GEMINI_API_KEY'),
            'modele' => env('GEMINI_MODEL_SECOURS', 'gemini-3.5-flash-lite'),
            'reflexion' => env('GEMINI_REFLEXION', 'low'),
        ],
        [
            'nom' => 'gemini-secours-2',
            'url' => 'https://generativelanguage.googleapis.com/v1beta/openai',
            'cle' => env('GEMINI_API_KEY'),
            'modele' => env('GEMINI_MODEL_SECOURS_2', 'gemini-3.6-flash'),
            'reflexion' => env('GEMINI_REFLEXION', 'low'),
        ],
        [
            'nom' => 'openai',
            'url' => 'https://api.openai.com/v1',
            'cle' => env('OPENAI_API_KEY'),
            'modele' => env('OPENAI_MODEL', 'gpt-4o-mini'),
        ],
    ],
],

'question_documents' => [
    'pdftotext_binary' => env('PDFTOTEXT_BINARY', 'pdftotext'),
],
];
