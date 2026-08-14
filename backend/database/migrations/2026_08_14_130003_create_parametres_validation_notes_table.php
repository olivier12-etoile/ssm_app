<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('parametres_validation_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->unique()->constrained('ecoles')->onDelete('cascade');
            $table->boolean('validation_obligatoire')->default(true);
            // Pas de défaut SQL sur ce JSON (portabilité) : ParametreValidationNote
            // applique ['directeur', 'censeur'] côté modèle si la colonne est vide.
            $table->json('roles_autorises_validation')->nullable();
            $table->boolean('modification_apres_validation')->default(false);
            $table->boolean('verrouillage_auto_cloture_periode')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_validation_notes');
    }
};
