<?php

use App\Http\Controllers\Api\AbsenceController;
use App\Http\Controllers\Api\AccueilBeneficiaireController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BeneficiaireController;
use App\Http\Controllers\Api\ConversationController;
use App\Http\Controllers\Api\DevoirController;
use App\Http\Controllers\Api\FileController;
use App\Http\Controllers\Api\FormationController;
use App\Http\Controllers\Api\LeconController;
use App\Http\Controllers\Api\ParcoursController;
use App\Http\Controllers\Api\QuizController;
use App\Http\Controllers\Api\PresenceController;
use App\Http\Controllers\Api\RessourceController;
use App\Http\Controllers\Api\SeanceController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\FabiaController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// ---------- Routes publiques ----------
Route::get('/inscription/options', [AuthController::class, 'optionsInscription'])->middleware('throttle:30,1');
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
Route::post('/admin/register', [AuthController::class, 'registerAdmin'])->middleware('throttle:5,1');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

// Application mobile : même fichier, signature relative (le téléphone n'utilise pas la même adresse que le serveur)
Route::get('/mobile/files/ressources/{ressource}', [FileController::class, 'ressource'])
    ->middleware('signed:relative')
    ->name('files.ressource.mobile');

// Fichiers : accessibles uniquement par lien signé temporaire
Route::middleware('signed')->group(function () {
    Route::get('/files/ressources/{ressource}', [FileController::class, 'ressource'])->name('files.ressource');
    Route::get('/files/lecons/{lecon}', [FileController::class, 'lecon'])->name('files.lecon');
    Route::get('/files/photos/{user}', [FileController::class, 'photo'])->name('files.photo');
});

// ---------- Routes protégées (token Sanctum) ----------
Route::middleware('auth:sanctum')->group(function () {

    // Profil
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::put('/user/password', [AuthController::class, 'changePassword']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Messagerie (tous les utilisateurs connectés)
    Route::get('/conversations', [ConversationController::class, 'index']);
    Route::get('/conversations/{conversation}/messages', [ConversationController::class, 'messages']);
    Route::post('/conversations/{conversation}/messages', [ConversationController::class, 'storeMessage']);
    Route::post('/conversations/privee', [ConversationController::class, 'ouvrirPrivee']);
    Route::get('/conversations/groupe-general', [ConversationController::class, 'groupeGeneral']);
    Route::get('/conversations/groupe-parcours/{parcoursId}', [ConversationController::class, 'groupeParcours']);
    Route::get('/conversations/contacts', [ConversationController::class, 'contacts']);
    Route::post('/conversations/{conversation}/resume', [ConversationController::class, 'resumer'])->middleware('throttle:10,1');
    Route::put('/messages/{message}', [ConversationController::class, 'updateMessage']);
    Route::delete('/messages/{message}', [ConversationController::class, 'destroyMessage']);
    Route::post('/messages/{message}/reactions', [ConversationController::class, 'reagir']);

    // Assistant FAB'IA (tous les utilisateurs connectés, application mobile comprise)
    Route::get('/fabia/historique', [FabiaController::class, 'historique']);
    Route::post('/fabia/questions', [FabiaController::class, 'poser'])->middleware('throttle:20,1');
    Route::delete('/fabia/historique', [FabiaController::class, 'effacer']);

    // Parcours, leçons, séances : lecture
    Route::get('/parcours', [ParcoursController::class, 'index']);
    Route::get('/parcours/{parcour}', [ParcoursController::class, 'show']);
    Route::get('/parcours/{parcour}/lecons', [LeconController::class, 'index']);
    Route::get('/parcours/{parcour}/seances', [SeanceController::class, 'index']);

    // ---------- Bénéficiaires (application mobile) ----------
    Route::middleware('role:beneficiaire')->group(function () {
        Route::get('/mon-accueil', [AccueilBeneficiaireController::class, 'index']);

        // Formations (leçons de mon parcours), chapitres (documents) et quiz (devoirs QCM)
        Route::get('/mes-formations', [FormationController::class, 'index']);
        Route::get('/mes-formations/{lecon}', [FormationController::class, 'show']);
        Route::post('/chapitres/{ressource}/terminer', [FormationController::class, 'terminerChapitre']);
        Route::get('/mes-quiz/{devoir}', [QuizController::class, 'afficher']);
        Route::post('/mes-quiz/{devoir}/reponses', [QuizController::class, 'repondre'])->middleware('throttle:60,1');
        Route::post('/mes-quiz/{devoir}/terminer', [QuizController::class, 'terminer']);
        Route::get('/presences/aujourdhui', [PresenceController::class, 'aujourdhui']);
        // Pointage par QR code de la séance (1er scan = arrivée, 2e = départ)
        Route::post('/presences/scanner', [PresenceController::class, 'scanner'])->middleware('throttle:20,1');
        Route::get('/mes-presences', [PresenceController::class, 'historique']);
        Route::get('/mes-absences', [AbsenceController::class, 'mesAbsences']);
        Route::post('/absences/{absence}/justifier', [AbsenceController::class, 'justifier']);
    });

    // ---------- Administrateurs (formateur, gérant, manager, super admin) ----------
    Route::middleware('role:admin')->group(function () {
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::put('/user/profile', [AuthController::class, 'updateProfile']);

        // Parcours : écriture
        Route::post('/parcours', [ParcoursController::class, 'store']);
        Route::put('/parcours/{parcour}', [ParcoursController::class, 'update']);
        Route::delete('/parcours/{parcour}', [ParcoursController::class, 'destroy']);

        // Leçons et ressources
        Route::post('/parcours/{parcour}/lecons', [LeconController::class, 'store']);
        Route::put('/lecons/{lecon}', [LeconController::class, 'update']);
        Route::delete('/lecons/{lecon}', [LeconController::class, 'destroy']);
        Route::post('/lecons/{lecon}/ressources', [RessourceController::class, 'store']);
        Route::delete('/ressources/{ressource}', [RessourceController::class, 'destroy']);

        // Séances
        Route::post('/parcours/{parcour}/seances', [SeanceController::class, 'store']);
        Route::delete('/seances/{seance}', [SeanceController::class, 'destroy']);
        Route::get('/seances/{seance}/qr', [SeanceController::class, 'qr']);
        Route::post('/seances/{seance}/qr/regenerer', [SeanceController::class, 'regenererQr']);

        // Bénéficiaires
        Route::get('/beneficiaires', [BeneficiaireController::class, 'index']);
        Route::put('/beneficiaires/{beneficiaire}', [BeneficiaireController::class, 'update']);

        // Absences
        Route::get('/absences', [AbsenceController::class, 'index']);
        Route::put('/absences/{absence}', [AbsenceController::class, 'update']);
        Route::delete('/absences/{absence}', [AbsenceController::class, 'destroy']);

        // Administrateurs (fiche + photo)
        Route::get('/administrateurs/{admin}', [AdminController::class, 'show']);
        Route::post('/administrateurs/{admin}/photo', [AdminController::class, 'uploadPhoto']);
        Route::delete('/administrateurs/{admin}/photo', [AdminController::class, 'deletePhoto']);

        // Devoirs
        Route::get('/devoirs', [DevoirController::class, 'index']);
        Route::post('/devoirs', [DevoirController::class, 'store']);
        Route::get('/devoirs/{devoir}', [DevoirController::class, 'show']);
        Route::put('/devoirs/{devoir}', [DevoirController::class, 'update']);
        Route::delete('/devoirs/{devoir}', [DevoirController::class, 'destroy']);
        Route::post('/devoirs/{devoir}/questions', [DevoirController::class, 'storeQuestions']);
        Route::post('/devoirs/{devoir}/generer-questions', [DevoirController::class, 'genererQuestions']);
        Route::put('/soumissions/{soumission}/corriger', [DevoirController::class, 'corrigerSoumission']);
        Route::get('/devoirs/{devoir}/resultats', [DevoirController::class, 'resultats']);
        Route::get('/devoirs/{devoir}/export-csv', [DevoirController::class, 'exportCsv']);
        Route::get('/devoirs/{devoir}/export-pdf', [DevoirController::class, 'exportPdf']);
    });

    // ---------- Manager + Super Admin ----------
    Route::middleware('role:fabmanager,admin_global')->group(function () {
        Route::get('/dashboard', [DashboardController::class, 'index']);

        // Base de connaissances de FAB'IA
        Route::get('/fabia/connaissances', [FabiaController::class, 'connaissances']);
        Route::post('/fabia/connaissances', [FabiaController::class, 'creerConnaissance']);
        Route::put('/fabia/connaissances/{connaissance}', [FabiaController::class, 'modifierConnaissance']);
        Route::delete('/fabia/connaissances/{connaissance}', [FabiaController::class, 'supprimerConnaissance']);
        Route::get('/beneficiaires/{beneficiaire}', [BeneficiaireController::class, 'show']);
        Route::post('/beneficiaires/{beneficiaire}/photo', [BeneficiaireController::class, 'uploadPhoto']);
        Route::delete('/beneficiaires/{beneficiaire}/photo', [BeneficiaireController::class, 'deletePhoto']);
    });

    // ---------- Super Admin uniquement ----------
    Route::middleware('role:admin_global')->group(function () {
        Route::get('/administrateurs', [AdminController::class, 'index']);
        Route::put('/administrateurs/{admin}', [AdminController::class, 'update']);
    });
});