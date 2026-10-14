<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->foreignId('etablissement_id')->nullable()->after('id')->constrained()->nullOnDelete();
        $table->foreignId('parcours_id')->nullable()->after('etablissement_id')->constrained()->nullOnDelete();
        $table->enum('role', ['beneficiaire', 'fabmanager', 'admin_global'])->default('beneficiaire')->after('parcours_id');
    });
}

public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropForeign(['etablissement_id']);
        $table->dropForeign(['parcours_id']);
        $table->dropColumn(['etablissement_id', 'parcours_id', 'role']);
    });
}
};
