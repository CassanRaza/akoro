<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devoir_lecon', function (Blueprint $table) {
            $table->id();
            $table->foreignId('devoir_id')->constrained('devoirs')->cascadeOnDelete();
            $table->foreignId('lecon_id')->constrained('lecons')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['devoir_id', 'lecon_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devoir_lecon');
    }
};