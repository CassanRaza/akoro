<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            // Réponse à un message précis (citation, comme sur Messenger)
            $table->foreignId('reply_to_id')->nullable()->after('auteur_id')
                ->constrained('messages')->nullOnDelete();
            $table->timestamp('modifie_le')->nullable()->after('fichier');
            // Suppression « pour tout le monde » : la ligne reste pour garder le fil
            $table->timestamp('supprime_le')->nullable()->after('modifie_le');
        });

        Schema::create('message_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained('messages')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('emoji', 16);
            $table->timestamps();

            // Une réaction par personne et par message (en choisir une autre la remplace)
            $table->unique(['message_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_reactions');

        Schema::table('messages', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reply_to_id');
            $table->dropColumn(['modifie_le', 'supprime_le']);
        });
    }
};
