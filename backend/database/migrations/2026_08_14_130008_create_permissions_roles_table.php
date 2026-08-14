<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Matrice de droits par rôle et par module, propre au module Paramètres
     * de l'École. Distincte de permissions_modules (module existant), qui
     * accorde/retire un module à un utilisateur précis : permissions_roles
     * définit le droit par défaut de chaque rôle, permissions_modules reste
     * l'exception par utilisateur.
     */
    public function up(): void
    {
        Schema::create('permissions_roles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->enum('role', ['directeur', 'censeur', 'enseignant', 'secretaire', 'comptable']);
            $table->string('module', 50);
            $table->boolean('peut_consulter')->default(true);
            $table->boolean('peut_creer')->default(false);
            $table->boolean('peut_modifier')->default(false);
            $table->boolean('peut_supprimer')->default(false);
            $table->boolean('peut_valider')->default(false);
            $table->timestamps();

            $table->unique(['ecole_id', 'role', 'module'], 'permissions_roles_ecole_role_module_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('permissions_roles');
    }
};
