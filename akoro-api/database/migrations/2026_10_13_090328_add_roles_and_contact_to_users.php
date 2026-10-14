<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "role" passe de ENUM (3 valeurs figées) à texte : formateur, gerant, fabmanager... sont acceptés
        DB::statement("ALTER TABLE users MODIFY role VARCHAR(20) NOT NULL DEFAULT 'beneficiaire'");

        Schema::table('users', function (Blueprint $table) {
            $table->string('telephone', 20)->nullable()->after('email');
            $table->string('adresse', 150)->nullable()->after('telephone');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['telephone', 'adresse']);
        });

        DB::table('users')->whereIn('role', ['formateur', 'gerant'])->update(['role' => 'fabmanager']);
        DB::statement("ALTER TABLE users MODIFY role ENUM('beneficiaire','fabmanager','admin_global') NOT NULL DEFAULT 'beneficiaire'");
    }
};