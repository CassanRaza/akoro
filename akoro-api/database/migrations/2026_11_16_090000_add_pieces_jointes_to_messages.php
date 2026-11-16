<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            // Pièce jointe (la colonne « fichier » contient le chemin sur le disque local)
            $table->string('nom_fichier')->nullable()->after('fichier');
            $table->unsignedBigInteger('taille_fichier')->nullable()->after('nom_fichier');
            $table->string('type_fichier', 120)->nullable()->after('taille_fichier');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['nom_fichier', 'taille_fichier', 'type_fichier']);
        });
    }
};
