<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Le module Notifications cible "personnel_administratif" (directeur,
     * censeur, secrétaire, comptable) et restreint la catégorie "finances"
     * au rôle comptable, qui n'existait pas encore dans l'enum.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->enum('role', [
                'super_admin',
                'directeur',
                'censeur',
                'secretaire',
                'enseignant',
                'comptable',
            ])->default('enseignant')->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->enum('role', [
                'super_admin',
                'directeur',
                'censeur',
                'secretaire',
                'enseignant',
            ])->default('enseignant')->change();
        });
    }
};
