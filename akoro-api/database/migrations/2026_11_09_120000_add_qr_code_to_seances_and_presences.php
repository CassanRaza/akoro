<?php

use App\Models\Seance;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // Pointage par QR code : un QR (et un code court de secours) par séance ; la présence garde la séance scannée
    public function up(): void
    {
        Schema::table('seances', function (Blueprint $table) {
            $table->string('qr_token', 64)->nullable()->unique()->after('heure_fin');
            $table->string('code', 8)->nullable()->unique()->after('qr_token');
        });

        // Séances déjà planifiées : on leur génère aussi leur QR
        DB::table('seances')->whereNull('qr_token')->orderBy('id')->each(function ($s) {
            DB::table('seances')->where('id', $s->id)->update([
                'qr_token' => Seance::nouveauToken(),
                'code' => Seance::nouveauCode(),
            ]);
        });

        Schema::table('presences', function (Blueprint $table) {
            $table->foreignId('seance_id')->nullable()->after('user_id')->constrained('seances')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('presences', function (Blueprint $table) {
            $table->dropConstrainedForeignId('seance_id');
        });

        Schema::table('seances', function (Blueprint $table) {
            $table->dropUnique(['qr_token']);
            $table->dropUnique(['code']);
            $table->dropColumn(['qr_token', 'code']);
        });
    }
};
