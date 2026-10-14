<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Pointage quotidien : une ligne par bénéficiaire et par jour
        Schema::create('presences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->date('date');
            $table->time('heure_arrivee');
            $table->time('heure_depart')->nullable();
            $table->string('mode')->default('biometrique');
            $table->timestamps();

            $table->unique(['user_id', 'date']);
        });

        // Séances : suivi du traitement des absences
        Schema::table('seances', function (Blueprint $table) {
            $table->unsignedInteger('attendus')->nullable()->after('heure_fin');
            $table->timestamp('absences_generees_le')->nullable()->after('attendus');
        });

        // Absences : lien avec la séance et statut de justification
        Schema::table('absences', function (Blueprint $table) {
            $table->foreignId('seance_id')->nullable()->after('lecon_id')->constrained('seances')->nullOnDelete();
            $table->string('statut')->default('non_justifiee')->after('motif');
        });

        // Conversion des anciennes absences de test (colonne "justifie" vers "statut")
        DB::table('absences')->where('justifie', true)->update(['statut' => 'justifiee']);
        DB::table('absences')->where('justifie', false)->whereNotNull('motif')->update(['statut' => 'a_valider']);

        Schema::table('absences', function (Blueprint $table) {
            $table->dropColumn('justifie');
            $table->unique(['user_id', 'seance_id']);
        });
    }

    public function down(): void
    {
        Schema::table('absences', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'seance_id']);
            $table->boolean('justifie')->default(false)->after('motif');
        });

        DB::table('absences')->where('statut', 'justifiee')->update(['justifie' => true]);

        Schema::table('absences', function (Blueprint $table) {
            $table->dropForeign(['seance_id']);
            $table->dropColumn(['seance_id', 'statut']);
        });

        Schema::table('seances', function (Blueprint $table) {
            $table->dropColumn(['attendus', 'absences_generees_le']);
        });

        Schema::dropIfExists('presences');
    }
};