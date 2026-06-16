<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('ecole_id')
                  ->nullable()
                  ->constrained('ecoles')
                  ->onDelete('cascade');

            $table->enum('role', [
                'super_admin',
                'directeur',
                'censeur',
                'secretaire',
                'enseignant'
            ])->default('enseignant');

            $table->boolean('mot_de_passe_change')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['ecole_id']);
            $table->dropColumn(['ecole_id', 'role', 'mot_de_passe_change']);
        });
    }
};