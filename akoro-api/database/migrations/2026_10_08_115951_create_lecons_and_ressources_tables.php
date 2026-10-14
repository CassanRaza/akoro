<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lecons', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parcours_id')->constrained('parcours')->cascadeOnDelete();
            $table->string('titre');
            $table->text('description')->nullable();
            $table->unsignedInteger('ordre')->default(1);
            $table->timestamps();
        });

        Schema::create('ressources', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lecon_id')->constrained('lecons')->cascadeOnDelete();
            $table->string('titre');
            $table->string('type')->default('pdf');
            $table->string('chemin');
            $table->string('nom_fichier');
            $table->unsignedBigInteger('taille')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ressources');
        Schema::dropIfExists('lecons');
    }
};