<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Avis « le quiz commence dans 5 minutes » / « le quiz commence » : envoyés une seule fois
    public function up(): void
    {
        Schema::table('devoirs', function (Blueprint $table) {
            $table->timestamp('rappel_envoye_le')->nullable()->after('statut');
            $table->timestamp('ouverture_notifiee_le')->nullable()->after('rappel_envoye_le');
        });
    }

    public function down(): void
    {
        Schema::table('devoirs', function (Blueprint $table) {
            $table->dropColumn(['rappel_envoye_le', 'ouverture_notifiee_le']);
        });
    }
};
