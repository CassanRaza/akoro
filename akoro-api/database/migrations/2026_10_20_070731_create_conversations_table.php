<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('etablissement_id')->constrained()->cascadeOnDelete();
            $table->foreignId('parcours_id')->nullable()->constrained()->nullOnDelete();
            $table->enum('type', ['privee', 'groupe_parcours', 'groupe_general']);
            $table->string('nom')->nullable(); // utile pour les groupes
            $table->timestamps();

            $table->index(['etablissement_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversations');
    }
};