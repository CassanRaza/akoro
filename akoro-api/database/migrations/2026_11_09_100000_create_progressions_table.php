<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Chapitres (documents d'une leçon) terminés par chaque bénéficiaire, depuis l'application mobile
    public function up(): void
    {
        Schema::create('progressions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('lecon_id')->constrained('lecons')->cascadeOnDelete();
            $table->foreignId('ressource_id')->constrained('ressources')->cascadeOnDelete();
            $table->timestamp('termine_le');
            $table->timestamps();

            $table->unique(['user_id', 'ressource_id']);
            $table->index(['user_id', 'lecon_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('progressions');
    }
};
