<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Base de connaissances de l'assistant FAB'IA
        Schema::create('connaissances_assistant', function (Blueprint $table) {
            $table->id();
            // null = connaissance commune à tous les FabLabs
            $table->foreignId('etablissement_id')->nullable()->constrained('etablissements')->cascadeOnDelete();
            $table->string('categorie', 40);
            $table->string('titre');
            $table->text('contenu');
            $table->string('questions_types', 500)->nullable();
            $table->string('mots_cles', 500)->nullable();
            // Information à faire confirmer ou compléter par le FabManager
            $table->boolean('a_valider')->default(false);
            $table->boolean('actif')->default(true);
            $table->unsignedInteger('ordre')->default(1);
            $table->timestamps();

            $table->index(['etablissement_id', 'categorie']);
        });

        // Questions posées à FAB'IA (historique de chacun + statistiques)
        Schema::create('fabia_echanges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('etablissement_id')->nullable()->constrained('etablissements')->nullOnDelete();
            $table->text('question');
            $table->text('reponse');
            $table->string('categorie', 40)->nullable();
            $table->string('source', 20)->default('ia'); // ia | local
            $table->string('langue', 10)->nullable();
            // L'utilisateur a effacé sa conversation : on garde la ligne pour les statistiques
            $table->boolean('masque')->default(false);
            $table->timestamps();

            $table->index(['user_id', 'masque', 'created_at']);
            $table->index(['etablissement_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fabia_echanges');
        Schema::dropIfExists('connaissances_assistant');
    }
};
