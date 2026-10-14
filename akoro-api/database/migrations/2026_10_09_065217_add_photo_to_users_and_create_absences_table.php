<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('photo')->nullable()->after('actif');
        });

        Schema::create('absences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('lecon_id')->nullable()->constrained('lecons')->nullOnDelete();
            $table->date('date');
            $table->string('motif')->nullable();
            $table->boolean('justifie')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('absences');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('photo');
        });
    }
};