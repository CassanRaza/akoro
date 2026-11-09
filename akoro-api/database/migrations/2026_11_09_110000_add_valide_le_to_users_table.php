<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // null = inscription en attente de validation par le Super Admin ; renseignée à la première activation
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('valide_le')->nullable()->after('actif');
        });

        // Comptes existants : déjà validés (actifs, ou bénéficiaires désactivés après coup)
        DB::table('users')
            ->where(fn ($q) => $q->where('actif', true)->orWhere('role', 'beneficiaire'))
            ->update(['valide_le' => DB::raw('created_at')]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('valide_le');
        });
    }
};
