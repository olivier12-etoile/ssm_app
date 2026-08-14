<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Permet au directeur d'activer/désactiver individuellement chaque
     * déclencheur automatique du module Notifications (une ligne par
     * école + clé de déclencheur ; absence de ligne = actif par défaut,
     * voir ParametreNotification::estActif()).
     */
    public function up(): void
    {
        Schema::create('parametres_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ecole_id')->constrained('ecoles')->onDelete('cascade');
            $table->string('cle', 50);
            $table->boolean('valeur')->default(true);
            $table->timestamps();

            $table->unique(['ecole_id', 'cle'], 'parametres_notifications_ecole_cle_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('parametres_notifications');
    }
};
