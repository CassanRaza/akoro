<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Table principale des devoirs (QCM programmé OU rendu PDF)
        Schema::create('devoirs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('etablissement_id')->constrained('etablissements')->cascadeOnDelete();
            $table->foreignId('parcours_id')->constrained('parcours')->cascadeOnDelete();
            $table->foreignId('lecon_id')->nullable()->constrained('lecons')->nullOnDelete();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();

            $table->string('type');                     // 'qcm' | 'rendu'
            $table->string('titre');
            $table->text('description')->nullable();

            // Pour les sessions QCM
            $table->dateTime('date_debut')->nullable(); // ex: 2026-10-20 12:00:00
            $table->unsignedInteger('duree_minutes')->nullable(); // durée du QCM

            // Pour les devoirs PDF / rendu
            $table->dateTime('date_limite')->nullable();
            $table->string('fichier_consigne')->nullable(); // chemin du PDF

            $table->string('statut')->default('brouillon'); // brouillon | programme | en_cours | termine | archive
            $table->timestamps();
        });

        // Questions (pour type = qcm)
        Schema::create('questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('devoir_id')->constrained('devoirs')->cascadeOnDelete();
            $table->text('enonce');
            $table->unsignedInteger('ordre')->default(1);
            $table->unsignedInteger('points')->default(1);
            $table->timestamps();
        });

        // Choix de réponses (QCM)
        Schema::create('choix', function (Blueprint $table) {
            $table->id();
            $table->foreignId('question_id')->constrained('questions')->cascadeOnDelete();
            $table->string('texte');
            $table->boolean('est_correct')->default(false);
            $table->unsignedInteger('ordre')->default(1);
            $table->timestamps();
        });

        // Résultats des QCM (une ligne par bénéficiaire + devoir)
        Schema::create('resultats_quiz', function (Blueprint $table) {
            $table->id();
            $table->foreignId('devoir_id')->constrained('devoirs')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedInteger('score')->default(0);
            $table->unsignedInteger('score_max')->default(0);
            $table->decimal('pourcentage', 5, 2)->nullable();
            $table->timestamp('commence_le')->nullable();
            $table->timestamp('termine_le')->nullable();
            $table->string('statut')->default('non_commence'); // non_commence | en_cours | termine
            $table->timestamps();

            $table->unique(['devoir_id', 'user_id']);
        });

        // Réponses individuelles données par le bénéficiaire
        Schema::create('reponses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('resultat_quiz_id')->constrained('resultats_quiz')->cascadeOnDelete();
            $table->foreignId('question_id')->constrained('questions')->cascadeOnDelete();
            $table->foreignId('choix_id')->nullable()->constrained('choix')->nullOnDelete();
            $table->boolean('est_correcte')->default(false);
            $table->timestamps();
        });

        // Soumissions pour les devoirs de type "rendu" (PDF / Image)
        Schema::create('soumissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('devoir_id')->constrained('devoirs')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('fichier')->nullable();          // chemin du fichier rendu
            $table->string('nom_fichier')->nullable();
            $table->decimal('note', 5, 2)->nullable();
            $table->text('commentaire')->nullable();
            $table->string('statut')->default('en_attente'); // en_attente | rendu | corrige
            $table->timestamp('date_soumission')->nullable();
            $table->timestamps();

            $table->unique(['devoir_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('soumissions');
        Schema::dropIfExists('reponses');
        Schema::dropIfExists('resultats_quiz');
        Schema::dropIfExists('choix');
        Schema::dropIfExists('questions');
        Schema::dropIfExists('devoirs');
    }
};